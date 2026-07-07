# Demo-resursen CI:t förvaltar: en tom resursgrupp (gratis). Poängen är
# inte resursen utan vägen dit - plan från PR med läsidentiteten, apply
# från main via environmentet prod med skrividentiteten.
resource "azurerm_resource_group" "demo" {
  name     = "rg-oidclab-demo-swedencentral-001"
  location = "swedencentral"

  tags = {
    managed_by = "opentofu"
    lab        = "oidc"
  }
}
