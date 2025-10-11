
resource "azurerm_user_assigned_identity" "github_identity" {
  name                = "microservices"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}


resource "azurerm_federated_identity_credential" "github_oidc" {
  name                = "github_actions"
  resource_group_name = azurerm_resource_group.rg.name
  parent_id           = azurerm_user_assigned_identity.github_identity.id
  issuer              = "https://token.actions.githubusercontent.com"
  audience            = ["api://AzureADTokenExchange"]
  subject             = "repo:Olamiwale/microservice:ref:refs/heads/main"
}


resource "azurerm_role_assignment" "sub_reader" {
  principal_id         = azurerm_user_assigned_identity.github_identity.principal_id
  role_definition_name = "Contributor"
  scope                = "/subscriptions/${var.subscription_id}"
}


resource "azurerm_role_assignment" "admin" {
  principal_id         = azurerm_user_assigned_identity.github_identity.principal_id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  scope                = azurerm_kubernetes_cluster.aks.id
} 