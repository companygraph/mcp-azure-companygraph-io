# Bootstrap

What GitHub Actions needs before it can authenticate and push: the resource group `mcp-azure-companygraph-io`, the storage account `mcpazurecompanygraphio` with the container `tfstate` that keeps `../`'s state, the registry of the same name, and the identities `terraform`, `terraform-plan` and `deploy`, each with a federated credential that trusts this repository's immutable subject. The resources are the module `companygraph/mcp-server` ships under `deploy/azure/bootstrap`, at the release `main.tf` names, and every value it takes is read from `../../deployment.json`.

The owner applies it, locally, under their own `az login`, when the module's release or the repository in `deployment.json` changes. Its state is local and stays on the owner's machine, never in the container it creates, so a second copy of `terraform.tfstate` kept somewhere safe is the only backup it has. The state file is ignored by git and never committed.

A re-apply restores that state first: copy `~/mcp-azure-companygraph-io-bootstrap.tfstate` to `infra/bootstrap/terraform.tfstate` before running anything. The plan that follows must not add the resource group, the storage account, the identities or the registry; a plan that does means the state is missing rather than the infrastructure, so stop and find the copy before applying anything. Once the apply finishes, copy the state back out to the same file, and to the second safe copy.

    az login
    cp ~/mcp-azure-companygraph-io-bootstrap.tfstate infra/bootstrap/terraform.tfstate
    terraform -chdir=infra/bootstrap init
    terraform -chdir=infra/bootstrap plan
    terraform -chdir=infra/bootstrap apply
    cp infra/bootstrap/terraform.tfstate ~/mcp-azure-companygraph-io-bootstrap.tfstate

The provider block here, and not the module, registers the resource providers the modules use, because registering one is a subscription's right that no identity the bootstrap makes holds. `terraform-plan` holds Reader on the resource group and nothing more; whether Reader alone can refresh every resource `../` makes is settled by the first pull-request plan, and if it cannot, the fix is a narrower custom role in the module's bootstrap, as the module's own README says, and never a wider role here.
