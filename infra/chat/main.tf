# The chat beside the host: a second root in the same resource group, with its own state key in
# the container the bootstrap made, and one call into the module companygraph/chat-server ships.
# The chat's values are chat/chat.json's; the subscription's are deployment.json's, stated once.
# The identity comes from the ARM_* variables the workflow sets, as the host's root says.
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
    key                  = "chat.tfstate"
    use_azuread_auth     = true
  }
}

locals {
  d = jsondecode(file("${path.module}/../../deployment.json"))
  c = jsondecode(file("${path.module}/../../chat/chat.json"))
}
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
# set the domain's records, so each is read with the default the module gives it; sign_in and
# user_month_tokens are absent until the reader secret is in the vault, and read as null.
module "chat" {
  source               = "git::https://github.com/companygraph/chat-server.git//deploy/azure/terraform?ref=v0.45.0"
  resource_group_name  = local.d.resource_group
  registry_name        = local.d.container_registry
  domain               = local.c.domain
  mcp_url              = local.c.mcp_url
  origins              = local.c.origins
  month_tokens         = local.c.month_tokens
  storage_account      = local.c.storage_account
  anthropic_federation = local.c.anthropic_federation
  inference_geo        = lookup(local.c, "inference_geo", null)
  repository           = local.d.repository
  repository_id        = local.d.repository_id
  owner_id             = local.d.owner_id
  image                = var.image
  app_host             = lookup(local.c, "app_host", "")
  dns_ready            = lookup(local.c, "dns_ready", false)
  sign_in              = try(local.c.sign_in, null)
  user_month_tokens    = try(local.c.user_month_tokens, null)
}

output "service_url" { value = module.chat.service_url }
output "app_host" { value = module.chat.app_host }
# The verification id in the TXT record is a value azurerm marks sensitive at this release of the
# module, as the host's root says; the records are read with az containerapp show.
output "dns_records" {
  value     = module.chat.dns_records
  sensitive = true
}
output "run_principal_id" { value = module.chat.run_principal_id }
output "analyst_client_id" { value = module.chat.analyst_client_id }
output "questions_workspace_id" { value = module.chat.questions_workspace_id }
output "reports_url" { value = module.chat.reports_url }
