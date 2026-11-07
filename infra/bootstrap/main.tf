# What has to exist before GitHub Actions can authenticate and push, on Azure: applied once by
# the owner under their own az login, with local state, and changed only when the module's
# release or the repository in deployment.json changes. Everything in the resource group that CI
# can create lives in ../ and is applied by CI. The resources are the shared module's, and this
# deployment's own values come from deployment.json.
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 5.7" }
  }
}

locals { d = jsondecode(file("${path.module}/../../deployment.json")) }

# A module cannot configure its own provider and still serve more than one deployment, so the
# provider block lives here. It also registers the resource providers the modules use, since
# registering one is a subscription's right that no identity the bootstrap makes holds; the root
# CI applies keeps resource_provider_registrations = "none" and names no list.
provider "azurerm" {
  features {}
  subscription_id                 = local.d.subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.App", "Microsoft.OperationalInsights", "Microsoft.ContainerRegistry", "Microsoft.Storage",
    "Microsoft.ManagedIdentity", "Microsoft.Insights", "Microsoft.Consumption",
  ]
}

module "bootstrap" {
  source              = "git::https://github.com/companygraph/mcp-server.git//deploy/azure/bootstrap?ref=v0.75.0"
  resource_group_name = local.d.resource_group
  location            = local.d.location
  state_account       = local.d.state_account
  registry_name       = local.d.container_registry
  repository          = local.d.repository
  repository_id       = local.d.repository_id
  owner_id            = local.d.owner_id
}

output "tenant_id" { value = module.bootstrap.tenant_id }
output "terraform_client_id" { value = module.bootstrap.terraform_client_id }
output "plan_client_id" { value = module.bootstrap.plan_client_id }
output "deploy_client_id" { value = module.bootstrap.deploy_client_id }
output "registry" { value = module.bootstrap.registry }
output "state_account" { value = module.bootstrap.state_account }
