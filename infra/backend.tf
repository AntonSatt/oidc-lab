terraform {
  # Backend-block kan inte läsa variabler - fyll i ditt kontonamn från
  # bootstrap.sh här. use_azuread_auth: gå via Entra-rollerna (Blob Data
  # Reader/Contributor), ALDRIG kontonycklar - plan-identiteten har inte
  # ens rätt att lista nycklarna, och det är poängen.
  backend "azurerm" {
    resource_group_name  = "rg-oidclab-mgmt-polandcentral-001"
    storage_account_name = "stoidclabantonsatt001" # samma namn du gav bootstrap.sh
    container_name       = "tfstate"
    key                  = "infra.tfstate"
    use_azuread_auth     = true
  }
}
