# CI-identiteter enligt pop-infras modell (bootstrap/2-backend/identity.tf):
# user-assigned managed identities med federated credentials - inga
# Entra-appobjekt, inga secrets. Två identiteter så att kod på en PR-branch
# aldrig kör med skrivåtkomst:
#   plan:  läs-only, mintbar från varje pull_request i repot
#   apply: skriv, bara mintbar från GitHub-environmentet "prod" som är
#          branch-policat till main (github.tf)
#
# Nedskalat mot referensen: roller på SUBSCRIPTION i stället för tenant
# root MG, och Contributor i stället för Owner - labbets infra-stack
# skapar bara resursgrupper, inte MG:er/policyer/rollgrants.

data "azurerm_resource_group" "mgmt" {
  name = "rg-oidclab-mgmt-${var.location}-001"
}

data "azurerm_storage_account" "tfstate" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.mgmt.name
}

locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"

  # ARM-id för containern - rolltilldelningar kan skopas ända ner hit.
  state_container_scope = "${data.azurerm_storage_account.tfstate.id}/blobServices/default/containers/${var.state_container_name}"
}

resource "azurerm_user_assigned_identity" "plan" {
  name                = "id-oidclab-plan-${var.location}-001"
  resource_group_name = data.azurerm_resource_group.mgmt.name
  location            = data.azurerm_resource_group.mgmt.location
}

resource "azurerm_user_assigned_identity" "apply" {
  name                = "id-oidclab-apply-${var.location}-001"
  resource_group_name = data.azurerm_resource_group.mgmt.name
  location            = data.azurerm_resource_group.mgmt.location
}

# Federated credentials: regeln Azure matchar GitHubs OIDC-intyg mot.
# Subject är hela skillnaden mellan identiteterna - issuer och audience
# är alltid desamma för GitHub Actions.

resource "azurerm_federated_identity_credential" "plan_pr" {
  name                      = "gha-${var.github_repo_name}-pr"
  resource_group_name       = data.azurerm_resource_group.mgmt.name
  parent_id                 = azurerm_user_assigned_identity.plan.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${var.github_repo_name}:pull_request"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_federated_identity_credential" "apply_prod" {
  name                      = "gha-${var.github_repo_name}-prod"
  resource_group_name       = data.azurerm_resource_group.mgmt.name
  parent_id                 = azurerm_user_assigned_identity.apply.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_owner}/${var.github_repo_name}:environment:prod"
  audience                  = ["api://AzureADTokenExchange"]
}

# RBAC. plan-identiteten är mintbar från ogranskad PR-kod: Reader på
# subscriptionen är accepterat i labbet (samma resonemang som pop-infra
# ADR 0002, fast på lägre scope).
#
# skip_service_principal_aad_check: identiteterna skapas i samma apply,
# Entra->ARM-replikering kan annars ge PrincipalNotFound. Flaggan är
# create-time-only - utan ignore_changes fastnar planen i evig diff
# efter en import/state-återställning (pop-infra 2026-07-05).

resource "azurerm_role_assignment" "plan_subscription_reader" {
  scope                            = local.subscription_scope
  role_definition_name             = "Reader"
  principal_id                     = azurerm_user_assigned_identity.plan.principal_id
  skip_service_principal_aad_check = true

  lifecycle {
    ignore_changes = [skip_service_principal_aad_check]
  }
}

resource "azurerm_role_assignment" "plan_state_reader" {
  scope                            = local.state_container_scope
  role_definition_name             = "Storage Blob Data Reader"
  principal_id                     = azurerm_user_assigned_identity.plan.principal_id
  skip_service_principal_aad_check = true

  lifecycle {
    ignore_changes = [skip_service_principal_aad_check]
  }
}

resource "azurerm_role_assignment" "apply_subscription_contributor" {
  scope                            = local.subscription_scope
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_user_assigned_identity.apply.principal_id
  skip_service_principal_aad_check = true

  lifecycle {
    ignore_changes = [skip_service_principal_aad_check]
  }
}

resource "azurerm_role_assignment" "apply_state_contributor" {
  scope                            = local.state_container_scope
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.apply.principal_id
  skip_service_principal_aad_check = true

  lifecycle {
    ignore_changes = [skip_service_principal_aad_check]
  }
}
