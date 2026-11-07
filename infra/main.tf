# Everything in the resource group that CI may create, applied on merge to main with the image
# the same run pushed. State lives in the container the bootstrap made, read and written as the
# identity the workflow signs in as, which reaches the backend and both providers through the
# ARM_* variables the workflow sets; a backend block takes no expression, so the account is
# named here as deployment.json names it. The resources themselves are the shared module's,
# and this deployment's own values come from deployment.json.
terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 5.7" }
    azapi   = { source = "Azure/azapi", version = "~> 2.13" }
  }
  backend "azurerm" {
    resource_group_name  = "mcp-azure-companygraph-io"
    storage_account_name = "mcpazurecompanygraphio"
    container_name       = "tfstate"
    key                  = "infra.tfstate"
    use_azuread_auth     = true
  }
}

locals { d = jsondecode(file("${path.module}/../deployment.json")) }
variable "image" { type = string }

provider "azurerm" {
  features {}
  subscription_id                 = local.d.subscription_id
  storage_use_azuread             = true
  resource_provider_registrations = "none"
}
provider "azapi" {
  subscription_id = local.d.subscription_id
}

# app_host and dns_ready are absent until the first apply has named the host and the owner has
# set the domain's records, so each is read with the default the module gives it.
module "mcp" {
  source              = "git::https://github.com/companygraph/mcp-server.git//deploy/azure/terraform?ref=v0.74.1"
  resource_group_name = local.d.resource_group
  registry_name       = local.d.container_registry
  domain              = local.d.domain
  budget_chf          = local.d.budget_chf
  budget_start        = local.d.budget_start
  image               = var.image
  app_host            = lookup(local.d, "app_host", "")
  dns_ready           = lookup(local.d, "dns_ready", false)
}

output "service_url" { value = module.mcp.service_url }
output "app_host" { value = module.mcp.app_host }
# The verification id in the TXT record is a value azurerm marks sensitive, and Terraform refuses
# a root output carrying one unless it says so; the records are read with az containerapp show,
# as the README says, so the output stays for the apply log and nothing reads it as plain text.
output "dns_records" {
  value     = module.mcp.dns_records
  sensitive = true
}
output "environment_name" { value = module.mcp.environment_name }
output "logs_workspace_name" { value = module.mcp.logs_workspace_name }
