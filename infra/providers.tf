terraform {
  required_version = ">= 1.8"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Ingen subscription_id i koden: den kommer från ARM_SUBSCRIPTION_ID i
# miljön (workflows sätter den från repo-variabeln; lokalt: export
# ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)).
# Autentisering: az CLI-sessionen, i CI skapad av azure/login via OIDC.
provider "azurerm" {
  features {}
}
