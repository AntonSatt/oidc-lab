# Roadmap: från OIDC-labb till mini-plattform

Labbet har hittills bevisat federeringen (plan/apply-identiteter, environment
branch policy, attackövningarna). Nästa nivå är att bygga kedjan som en
riktig plattformsmiljö har — self-hosted runners, build-once/promote,
privat nätverk — fast nedskalat till studentkonto-budget.

## Funkar det på Azure for Students?

Ja, nästan allt. Studentkontot ($100 kredit/12 mån, inget kort) klarar hela
runner-kedjan. Det som INTE går eller inte är värt det:

| Del | Studentkonto? | Kommentar |
|---|---|---|
| UAMI + federated credentials | ✅ gratis | redan gjort |
| Container Apps Jobs + KEDA | ✅ ~gratis | consumption-plan har fri månadskvot (180k vCPU-s); ephemeral runners skalar till 0 |
| ACR Basic | ✅ ~5 USD/mån | största fasta kostnaden — städa när du inte labbar |
| Log Analytics | ✅ ören | runner-loggar är små volymer |
| Key Vault | ✅ ören | per-operation-prissättning |
| VNet + delegerat subnät | ✅ gratis | själva nätverket kostar inget |
| Private endpoints (KV/ACR) | ⚠️ ~7–8 USD/mån **styck** | gör som valfri sluetapp, riv efteråt |
| Azure Firewall / hub-spoke | ❌ ~900 USD/mån | hela org-nätverksförsteget simuleras INTE — läs bara koden |
| NAT Gateway | ❌ ~35 USD/mån | behövs inte; CAE:s default-egress duger i labb |
| Org-runner-group `visibility=all` | ⚠️ | kräver org; skapa en gratis GitHub-org (default-gruppen räcker — egna runner groups kräver Team-plan) |
| Environments på privat repo | ✅ | GitHub Student Developer Pack ger Pro gratis; publikt repo funkar utan |

Priser är cirka — kolla aktuell prislista. Tumregel: allt utom ACR och
private endpoints är i praktiken gratis på den här skalan.

## Etapp 1 — self-hosted runners på Container Apps Jobs

Målet: `runs-on: self-hosted` i det här repot kör på en ephemeral runner i
din egen subscription. Samma arkitektur som en produktionssetup, minus hubben.

- Ny katalog `runners/` med egen tofu-rot (samma separation som `infra/`).
- GitHub App på ditt konto (webhook av; permissions: repo Actions Read +
  Administration RW för repo-scope-runners). App-nyckeln i Key Vault.
- ACR Basic + runner-image: official `actions-runner` + az/tofu,
  ephemeral registrerings-entrypoint. Bygg med `az acr build` från
  `ubuntu-latest` (hönan-och-ägget: första bygget kan inte köra på
  runnersen själva).
- Container App Environment (utan VNet först — det är etapp 3) +
  Container App Job med KEDA `github-runner`-scaler, `runnerScope: repo`,
  0 → N.
- Verifiering: testworkflow med `runs-on: self-hosted` blir grön; kolla i
  Azure att jobbet skalade från 0 och dog efter körningen.

Läs/följ:
- [Tutorial: GitHub Actions runners med ACA Jobs](https://learn.microsoft.com/en-us/azure/container-apps/tutorial-ci-cd-runners-jobs) — officiella tutorialen, CLI-varianten av det du sen kodar i tofu
- [Jobs in Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/jobs) — konceptdok för event-drivna jobb
- [ACA runners med KEDA-autoscaling](https://techcommunity.microsoft.com/blog/azureinfrastructureblog/running-github-actions-runners-on-azure-container-apps-with-keda-autoscaling/4512980) — felsökningstips

## Etapp 2 — build once, promote (test → prod)

Målet: 12-factor-mönstret build once, deploy many. EN image byggs vid merge, samma
digest deployas först till `test` (automatiskt), sen till `prod` (manuell
gate med required reviewers).

- `infra/` får en liten demo-app som Container App i två RG:er
  (`test`/`prod`) — eller enklare: två revisioner/taggar av samma app.
- Två nya environments i `identities/github.tf`: `test` (ingen gate) och
  behåll `prod` (branch policy + required reviewer = du). Två nya
  apply-subjects — utöka identitetsmodellen i README-tabellen.
- Workflow-kedja: bygg + pusha image (tag = git-SHA, ALDRIG latest) →
  deploy test → vänta på approval → deploy prod med SAMMA tag.
- Svar på frågan "vad kör i prod just nu?": GitHubs deployment-historik per
  environment + taggen i Container App-resursen.

Läs/följ:
- [Environments — GitHub Docs](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Skills](https://github.com/skills) — deploy-to-Azure-kursen
- [Azure-Samples: Terraform OIDC CI/CD](https://learn.microsoft.com/en-us/samples/azure-samples/github-terraform-oidc-ci-cd/github-terraform-oidc-ci-cd/) — facit-repo för OIDC + environments + Terraform ihop

## Etapp 3 — privat nätverk (valfri, kostar lite)

Målet: förstå varför en VNet-integrerad CAE tar 10+ minuter att
provisionera och varför subnätet måste vara rätt från början.

- VNet + subnät delegerat till `Microsoft.App/environments`; flytta CAE:n
  in i VNet:et (`infrastructure_subnet_id` är immutable — detta ÄR
  riv-och-bygg-nytt, det är poängen med övningen).
- `internal_load_balancer_enabled = true` — runnersen behöver ingen ingress.
- Valfri påbyggnad: private endpoint på Key Vault + tvåstegs-apply
  (öppna publikt → skriv secret → stäng igen). Riv endpointen när du
  testat klart (~8 USD/mån).
- Hubben/brandväggen: rita hub/spoke-flödet (peering, UDR mot FW, privat
  DNS) på papper i stället — den delen köper man inte för studentkredit.

Läs/följ:
- [Privat nätverkssetup för ACA-runners](https://ilovedevops.substack.com/p/github-actions-self-hosted-runners)
- [Networking in Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/networking)

## Etapp 4 — gratis GitHub-org + repo-vending (valfri)

Målet: härma org-nivån. Skapa en gratis org (t.ex. `<dittnamn>-lab-org`),
flytta eller peka om labbet dit.

- Org-runners: registrera runnersen på org-nivå (`runnerScope: org`,
  default runner group — egna grupper kräver Team-plan).
- Repo-vending: en `repos/`-stack med GitHub-providern som skapar repos
  med rätt namn, branch protection och CODEOWNERS — repos som self-
  service-infrastruktur i miniatyr. Nya repos = PR mot en tfvars-lista.

Läs/följ:
- [GitHub provider — Terraform Registry](https://registry.terraform.io/providers/integrations/github/latest/docs)

## Etapp 5 — supply chain-godis (valfri)

- SBOM vid merge (`anchore/sbom-action` eller `syft`), ladda upp som
  artifact — "skicka till SOC" simuleras med ett GitHub-issue.
- Blockera `latest`-taggar och opinnade versioner i PR-check.
- Kika på ACR:s inbyggda skanning (Defender) — bara läsning, kostar annars.

## Ordning och tidsåtgång

1 → 2 är kärnan (en helg vardera, ungefär). 3–5 är fristående påbyggnader
i valfri ordning. Efter etapp 2 kan du dessutom göra om attackövningen i
README steg 5 mot test/prod-uppdelningen — kan en PR nå prod-identiteten?

## Städa

ACR:n och ev. private endpoints är de enda löpande kostnaderna. `tofu
destroy` i `runners/` mellan labbpassen; identiteterna och state-kontot
kostar inget att låta stå.
