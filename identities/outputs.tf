output "plan_client_id" {
  description = "Loggar in i plan-workflowen (flödar även till repo-variabeln AZURE_CLIENT_ID_PLAN)"
  value       = azurerm_user_assigned_identity.plan.client_id
}

output "apply_client_id" {
  description = "Loggar in i apply-workflowen (flödar även till environment-variabeln AZURE_CLIENT_ID_APPLY)"
  value       = azurerm_user_assigned_identity.apply.client_id
}
