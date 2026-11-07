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

3. Write the empty state before the first pull request plans. The azurerm backend writes an empty state blob when it finds none for the workspace, and `terraform-plan` holds Storage Blob Data Reader on the container, which cannot create one, so a pull request on Azure cannot plan until the state exists. An owner on the subscription holds no right on the container's blobs either, so the owner takes Storage Blob Data Contributor on that container once, which also lets them read the state later, and runs the init that writes the blob; the role took a few minutes to reach the data plane:

        az role assignment create --assignee "$(az ad signed-in-user show --query id -o tsv)" --role "Storage Blob Data Contributor" --scope "/subscriptions/fde0a7c3-6f5a-4fe3-a7d5-2b33b67aea80/resourceGroups/mcp-azure-companygraph-io/providers/Microsoft.Storage/storageAccounts/mcpazurecompanygraphio/blobServices/default/containers/tfstate"
        terraform -chdir=infra init -input=false

4. Merge the pull request. The first deploy fails at the live check, and its `app_host` warning names the host; write it into `deployment.json` as `app_host` and open the pull request for it. That pull request's plan was the first to refresh the container app as `terraform-plan`, and it failed on `Microsoft.App/containerApps/listSecrets/action`, which Reader lacks; the server released 0.74.1 with a custom role of Reader plus that action, this deployment re-pinned it in its three places on the same branch, and the bootstrap was re-applied, after restoring its state from the copy, replacing the one role assignment. Then the plan passed and the merge's live check read the pinned commit:

        cp ~/mcp-azure-companygraph-io-bootstrap.tfstate infra/bootstrap/terraform.tfstate
        terraform -chdir=infra/bootstrap init -upgrade && terraform -chdir=infra/bootstrap apply
        cp infra/bootstrap/terraform.tfstate ~/mcp-azure-companygraph-io-bootstrap.tfstate

5. At Hostpoint, add the two records the deployment names for `mcp.azure.companygraph.io`: the CNAME to the app's host, and the `asuid` TXT with the verification id, read from the app rather than from the state, because an owner's login carries no right on the state's blobs:

        az containerapp show -g mcp-azure-companygraph-io -n mcp --query properties.configuration.ingress.fqdn -o tsv
        az containerapp show -g mcp-azure-companygraph-io -n mcp --query properties.customDomainVerificationId -o tsv

    Once both resolved at Cloudflare, Google and Hostpoint's own name server, `deployment.json` said `"dns_ready": true` and the merge's apply added the domain, issued the certificate and bound it on its first run; `https://mcp.azure.companygraph.io/mcp` answered the pinned commit from then on.

## The chat

`chat.azure.companygraph.io` is the chat over this host: a visitor's question goes to it, it asks `mcp.azure.companygraph.io` through the tools, and Claude on the Anthropic API writes the answer from what the tools said. It is `companygraph/chat-server`, deployed from this repository beside the host as `chat.companygraph.io` sits beside `mcp.companygraph.io`: `chat/` holds what is this deployment's own for it, `chat/package.json` pinning the release, `chat/chat.json` naming the domain, the host it reads, the page origins it answers, the month's ceiling in input-equivalent tokens, the storage account and the federation it reaches Anthropic by, the Dockerfile, the brand, the stylesheet and the tests; `infra/chat/` is its Terraform root, applied by CI with its own key in the same state container; `.github/workflows/chat.yml` calls the chat server's own `deploy-azure.yml`, and `report.yml` its `report-azure.yml`, on Monday at six UTC and by hand. The release is named in those four places and the chat server's pin test holds them to one. The budget in `deployment.json` covers both services; what the model costs is Anthropic's bill, under the ceiling.

The chat holds no key. Its identity on Azure asks the managed-identity endpoint for a token for the tenant's app registration standing for the Claude API and trades it at Anthropic, where a federation issuer for the tenant and a rule for this identity accept it. Four steps of that are the owner's, done once, and they ran in this order on 2026-11-07. The app registration in the tenant, whose `appId` is `anthropic_federation.audience`; `az ad app update --set api.requestedAccessTokenVersion=2` refuses an app whose `api` object is empty, so the version was set through Microsoft Graph:

        APP=$(az ad app create --display-name "Claude API" --sign-in-audience AzureADMyOrg --query appId -o tsv)
        az ad app update --id "$APP" --identifier-uris "api://$APP"
        az rest --method PATCH --url "https://graph.microsoft.com/v1.0/applications/$(az ad app show --id "$APP" --query id -o tsv)" --headers Content-Type=application/json --body '{"api":{"requestedAccessTokenVersion":2}}'
        az ad sp create --id "$APP"

The chat's identity, made by hand before the first apply and adopted by the `import` block in `infra/chat/main.tf`, because the rule at Anthropic names its object id and `chat.json` names that rule before the first apply; the block goes with the pull request that writes `app_host`, once the module owns the identity. Then the chat's empty state, written by the owner as the host's was:

        az identity create -g mcp-azure-companygraph-io -n chat-run -l switzerlandnorth --query '[id, principalId]' -o tsv
        terraform -chdir=infra/chat init -input=false

In the Anthropic Console, under Settings and Workload identity, an issuer for the tenant, `https://login.microsoftonline.com/<tenant>/v2.0` in discovery mode with `max_jwt_lifetime_seconds` raised to 86400 after the wizard, since Azure caches a managed identity's token for up to a day; and a rule for the same service account `chat.companygraph.io` runs as, with the `appId` as its audience and two claims, the identity's object id in `oid` and the tenant in `tid`. Its id is `anthropic_federation.rule_id`. After the first merge, `chat.json` gains `app_host`, `questions_workspace_id` and `analyst_client_id` from the apply, the two records go to Hostpoint as the host's did, and `dns_ready` brings the domain and its certificate.

Nothing the chat spends escapes its ceiling. The service refuses before it asks the model, an address gets twenty requests an hour, and a meter in the table `chat` of the storage account `chatazurecompanygraphio` counts every model call against a day's share and a month's ceiling. The chat is stopped by hand where the meter keeps it: the entity with partition `chat` and row `meter`, field `closed` set to `true`, which refuses the next message and spends nothing, and back to `false` to open it.

Once a message the shape accepted has its answer or its refusal, the chat keeps one line of it, the question, the language and what the loop saw, no address and no word of the answer, in the workspace `chat-questions` for ninety days, which holds nothing else; the owner's own reading is granted once by hand, `az role assignment create --assignee <login> --role "Log Analytics Data Reader" --scope <workspace id>`. On Monday morning the report workflow, running as the identity `chat-analyst`, writes the week that ended to the private container `reports` of the same storage account as `reports/<week>.md`. A report is deleted at eighty-three days, so no question it quotes outlives the ninety. Container Apps ends a request after 240 seconds where Cloud Run allows 300, so an answer that needs the full five rounds can be cut short here; how often is read from the questions' lines over a week, not from one question.

## License

CC BY 4.0 for the text here; the model's own license is its own.
