# GitHub-sidan av federeringen, i samma graf som identiteterna
# (pop-infras bootstrap/2-backend/github.tf). Det här är NYCKELN i hela
# mönstret: environmentets branch-policy är det som gör apply-subjectet
# säkert. Subjectet ensamt skyddar ingenting - en PR kan ändra workflows,
# men den kan aldrig få GitHub att utfärda environment:prod-intyget från
# sin branch så länge policyn nedan finns.
resource "github_repository_environment" "prod" {
  repository  = var.github_repo_name
  environment = "prod"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

# Bara main får deploya = bara main kan minta apply-identitetens
# OIDC-subject (repo:...:environment:prod).
resource "github_repository_environment_deployment_policy" "main_only" {
  repository     = var.github_repo_name
  environment    = github_repository_environment.prod.environment
  branch_pattern = "main"
}

resource "github_actions_variable" "tenant_id" {
  repository    = var.github_repo_name
  variable_name = "AZURE_TENANT_ID"
  value         = var.tenant_id
}

resource "github_actions_variable" "subscription_id" {
  repository    = var.github_repo_name
  variable_name = "AZURE_SUBSCRIPTION_ID"
  value         = var.subscription_id
}

# Plan-id:t som vanlig repo-variabel: alla jobb får läsa det.
resource "github_actions_variable" "client_id_plan" {
  repository    = var.github_repo_name
  variable_name = "AZURE_CLIENT_ID_PLAN"
  value         = azurerm_user_assigned_identity.plan.client_id
}

# Apply-id:t som ENVIRONMENT-variabel: bara jobb i environmentet prod ser
# det. Hör ihop med subjectet - id och intyg följs åt.
resource "github_actions_environment_variable" "client_id_apply" {
  repository    = var.github_repo_name
  environment   = github_repository_environment.prod.environment
  variable_name = "AZURE_CLIENT_ID_APPLY"
  value         = azurerm_user_assigned_identity.apply.client_id
}
