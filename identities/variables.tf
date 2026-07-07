variable "tenant_id" {
  description = "Entra-tenant där subscriptionen bor (az account show --query tenantId)"
  type        = string
}

variable "subscription_id" {
  description = "Subscription som labbet får läsa/skriva (az account show --query id)"
  type        = string
}

variable "storage_account_name" {
  description = "State-kontot från bootstrap.sh"
  type        = string
}

variable "location" {
  description = "Azure-region, samma som bootstrap.sh"
  type        = string
  default     = "polandcentral"
}

variable "github_owner" {
  description = "GitHub-användare/org som äger labbrepot"
  type        = string
  default     = "antonsatt"
}

variable "github_repo_name" {
  description = "Labbrepots namn"
  type        = string
  default     = "oidc-lab"
}

variable "state_container_name" {
  description = "Blob-container för tfstate, samma som bootstrap.sh"
  type        = string
  default     = "tfstate"
}
