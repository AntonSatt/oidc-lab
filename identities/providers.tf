# Operatörskörd stack med LOKAL state: den här stacken skapar identiteterna
# som resten av riggen loggar in med, så den kan inte själv bero på riggen.
terraform {
  required_version = ">= 1.8"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# Autentiseras via GITHUB_TOKEN i miljön: export GITHUB_TOKEN=$(gh auth token)
# Båda sidor av federeringen i samma graf - client-id:n flödar som
# referenser in i GitHub-variablerna, ingen copy-paste.
provider "github" {
  owner = var.github_owner
}
