# mcp.azure.companygraph.io

CompanyGraph's own model, `companygraph/mental-model`, served over MCP at `https://mcp.azure.companygraph.io/mcp` from Azure. It is the model `mcp.companygraph.io` serves, at the same commit, so a question asked of either host gets the same answer from the same facts; what differs is the cloud underneath. This repository pins that commit and one release of `companygraph/mcp-server`, builds an image that carries the model's snapshot, and runs it as a Container App in Switzerland North. Everything in the resource group is Terraform: the bootstrap's part applied once by the owner, the rest by GitHub Actions on every merge.

It is the first deployment of the server on Azure, and the proof of the design in `companygraph/chat-server`'s [The servers run on two clouds](https://github.com/companygraph/chat-server/blob/main/docs/superpowers/specs/2026-09-28-the-servers-run-on-two-clouds-design.md): the server's modules under `deploy/azure/` were written and validated before any subscription existed, and this deployment is where they first meet a real one. It is built entirely from the parts the server ships under `deploy/`: the Terraform modules, the build command, the shared tests and the workflow. What is this deployment's own is its values in `deployment.json`, its brand, its page styles and its instance tests.

## Using it

Add `https://mcp.azure.companygraph.io/mcp` as a custom connector in Claude, or as a remote MCP server in ChatGPT's developer mode or the Gemini CLI. No authentication. The page at `https://mcp.azure.companygraph.io` lists the tools with what each returns, from the server's own list. Every answer names the model commit it was read from.

## What pins what

`source.json` names the model commit and `package.json` the server release. Moving either is a pull request; the merge builds the image, applies the infrastructure with it and checks that the service reports the new commit. The server release is named again in the workflow's `uses:` line and in both Terraform roots' `?ref=`, and a shared test holds the three to one.

## Building it

    npm ci
    npm run snapshot      # writes dist/snapshot.json from the pinned commit
    npm run page-css      # writes dist/page.css from the design package's blocks and own.css
    npm run jsonld        # writes nothing here: the model's MCP surface is mcp.companygraph.io's
    npm test              # the server's shared deployment tests and this instance's own
    docker build -t mcp-azure-companygraph-io:local .

The page carries no structured data on purpose. The model names one MCP surface, built by `companygraph/mcp-companygraph-io`, and a host that claimed it would tell a crawler the sibling's address was its own; the instance test holds that this host claims none.

## Infrastructure

`infra/bootstrap/` is applied by the owner, with the state `infra/bootstrap/README.md` says how to restore, and holds what CI needs before it can authenticate: the resource group, the storage account and container that keep the state, the image registry, and three user-assigned identities whose federated credentials trust this repository's immutable subject. A pull request plans as `terraform-plan`, which holds Reader on the resource group and reads the state, and can change neither; only a run on `main` may apply as `terraform` or push an image as `deploy`. `infra/` is applied by CI on every merge: its state in the container the bootstrap made, read as the identity the workflow signs in as, and one call into the module `companygraph/mcp-server` ships under `deploy/azure/terraform`, with this deployment's own values read from `deployment.json`. The workflow in `.github/workflows/deploy.yml` only calls the package's own `deploy-azure.yml`, by the release `package.json` pins.

The module gives the app a generated host name that is not knowable before it exists, and the service refuses a POST on a host it was not told. So a deployment goes live in three merges: the first makes the app and names its host in the apply log, the second writes that host into `deployment.json` as `app_host`, and the third says `dns_ready` once the domain's two records are set, which adds the domain with a free managed certificate. The budget is a monthly figure on the resource group, in the billing account's currency, that warns the owners at three thresholds and stops nothing.

## The owner's steps

The record of how the deployment was stood up: the owner's steps, done once, in this order, kept here so the commands stay correct as a record rather than as work still to do. Every command ran in a shell that had first run `export PATH=/opt/homebrew/bin:$PATH`, with the Azure CLI signed in as the subscription's owner.

1. Create the repository, public, with merge commits as its only merge method, and read GitHub's immutable subject for it, which a repository created after 2026-07-15 carries by default. Its numeric id goes into `deployment.json` as `repository_id`, and the organization's as `owner_id`:

        gh api repos/companygraph/mcp-azure-companygraph-io --jq '.id'
        gh api repos/companygraph/mcp-azure-companygraph-io/actions/oidc/customization/sub

2. Apply the bootstrap before the merge, because the merge's deploy signs in with what it creates. Until then `infra/bootstrap/` exists only on the pull request's branch, so it was applied from the worktree that had the branch checked out. Its state is a local file git ignores, and `git worktree remove` deletes ignored files without a word, so the state was copied out of the worktree the moment the apply finished and kept outside the repository, because it is the bootstrap's only state. The three client ids from its outputs go into `deployment.json`. The provider block registers the resource providers the modules use; after the first apply one of them, `Microsoft.Insights`, still read `NotRegistered` and was registered by hand:

        az login
        terraform -chdir=infra/bootstrap init && terraform -chdir=infra/bootstrap apply
        cp infra/bootstrap/terraform.tfstate ~/mcp-azure-companygraph-io-bootstrap.tfstate
        terraform -chdir=infra/bootstrap output
        az provider register -n Microsoft.Insights --wait

3. Merge the pull request. The first deploy fails at the live check, and its `app_host` warning names the host; write it into `deployment.json` as `app_host` and merge that.

4. At Hostpoint, add the two records the deployment names for `mcp.azure.companygraph.io`: the CNAME to the app's host, and the `asuid` TXT with the verification id, read from the app rather than from the state, because an owner's login carries no right on the state's blobs:

        az containerapp show -g mcp-azure-companygraph-io -n mcp --query properties.configuration.ingress.fqdn -o tsv
        az containerapp show -g mcp-azure-companygraph-io -n mcp --query properties.customDomainVerificationId -o tsv

    Once both resolve, set `"dns_ready": true` in `deployment.json` and merge that; the apply adds the domain and its certificate.

## The chat

`chat.azure.companygraph.io` is the next pull request in this repository: `companygraph/chat-server` deployed beside the host in the same Container Apps environment, as `chat.companygraph.io` sits beside `mcp.companygraph.io`. It asks four steps of the owner that the host does not, once per tenant or once per deployment: an app registration in the tenant that stands for the Claude API, a federation issuer for the tenant and a rule for the chat's identity in the Anthropic Console, and the domain's records. The chat server's README, under *Deploying it on Azure*, says what each is and why the chat holds no key.
