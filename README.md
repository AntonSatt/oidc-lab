# oidc-lab

[![plan](https://github.com/AntonSatt/oidc-lab/actions/workflows/plan.yml/badge.svg)](https://github.com/AntonSatt/oidc-lab/actions/workflows/plan.yml)
[![apply](https://github.com/AntonSatt/oidc-lab/actions/workflows/apply.yml/badge.svg)](https://github.com/AntonSatt/oidc-lab/actions/workflows/apply.yml)

Hemmalabb för OIDC/Workload Identity Federation mellan GitHub Actions och
Entra ID, nedskalad från pop-infras mönster. Inga secrets någonstans:
GitHub utfärdar ett signerat intyg per jobb, Azure matchar intygets
subject mot en federated credential på en user-assigned managed identity.

```
bootstrap/    engångsskript (az cli): resursgrupp + state-konto + container
identities/   operatörskörd stack, LOKAL state: UAMI:er, federated
              credentials, roller + GitHub-sidan (environment, variabler)
infra/        demo-stacken CI:t förvaltar, remote state i containern
.github/      plan på PR (läsidentitet), apply på main (skrividentitet)
```

## Identitetsmodellen

| Identitet | Subject (vem får låna den) | Roller |
|---|---|---|
| `id-oidclab-plan-*` | `repo:AntonSatt/oidc-lab:pull_request` — varje PR | Reader på subscriptionen, Blob Data Reader på state-containern |
| `id-oidclab-apply-*` | `repo:AntonSatt/oidc-lab:environment:prod` — bara main, via branch-policyn | Contributor på subscriptionen, Blob Data Contributor på containern |

Skyddet sitter INTE i workflow-filerna (en PR kan ändra dem fritt) utan i
environmentets deployment branch policy: bara main får deploya till prod,
alltså kan bara main minta apply-subjectet. Policyn är själv Terraform-kod
i `identities/github.tf` — federeringens båda sidor i samma graf.

Nedskalat mot pop-infra: roller på subscription i stället för tenant root
management group, Contributor i stället för Owner (labbet skapar inga
MG:er/policyer), och ingen central vending (`ci-identities/`) — ett repo,
ett identitetspar.

## Körordning

Förutsättningar: `az`, `tofu`, `gh` installerade och inloggade mot ditt
PRIVATA konto (`az login`, `gh auth login`). Repot måste vara publikt
(eller GitHub Pro) — annars vägrar GitHub environment-branch-policyn.

```bash
# 0. Första commit:en, skapa GitHub-repot och pusha
git add -A && git commit -m "OIDC-labb: UAMI + federated credentials"
gh repo create AntonSatt/oidc-lab --public --source . --push

# 1. Hönan-och-ägget: state-backendens infra, för hand, en gång
cd bootstrap && ./bootstrap.sh stoidclab<dittnamn>001

# 2. Fyll i dina id:n
cd ../identities
cp terraform.tfvars.example terraform.tfvars   # redigera: tenant, sub, kontonamn
# skriv även in kontonamnet i infra/backend.tf (CHANGE_ME)

# 3. Skapa identiteterna + GitHub-sidan (operatörskörning, lokal state)
export GITHUB_TOKEN=$(gh auth token)
tofu init && tofu apply

# 4. Commit:a backend.tf-ändringen, öppna en PR och se plan-workflowen
#    logga in i Azure UTAN någon secret. Merga och se apply skapa
#    rg-oidclab-demo-polandcentral-001.
```

## Steg 5: attackera din egen grind

Det viktigaste steget — känn efter varför policyn är nyckeln:

1. Skapa en branch och ändra `apply.yml` så den triggar på din branch
   (`branches: [main, attack]`). Pusha. **Förväntat:** jobbet stoppas
   redan innan azure/login — GitHub vägrar starta ett environment-jobb
   från en ref som inte matchar branch-policyn.
2. Ta bort `environment: prod` ur jobbet och låt det logga in med
   `AZURE_CLIENT_ID_APPLY`:s värde hårdkodat. **Förväntat:** azure/login
   får `AADSTS70021` (subject-mismatch) — intyget säger inte
   `environment:prod`, och client-id:t i sig bevisar ingenting.
3. Ta (tillfälligt!) bort branch-policyn i `identities/github.tf`, kör
   apply, och upprepa attack 1. **Förväntat:** nu FUNKAR attacken.
   Subjectet ensamt skyddar ingenting — återställ policyn och notera
   varför pop-infra hanterar den som kod.

## Städa

```bash
tofu destroy   # i identities/ och infra/ (eller ta bort demo-RG:n med az)
az group delete --name rg-oidclab-mgmt-polandcentral-001
```

Kostnad under labbets livstid: några ören (state-blobarna). Allt annat —
UAMI:er, federated credentials, rolltilldelningar, Actions-minuter på
publikt repo — är gratis.
