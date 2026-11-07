# The chat runs on Azure — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `chat.azure.companygraph.io`, the chat over `mcp.azure.companygraph.io`: `companygraph/chat-server` deployed beside the host in this repository, reaching the Anthropic API by federation alone, with its kept questions in a workspace of their own and the weekly report, as `chat.companygraph.io` sits beside `mcp.companygraph.io`.

**Architecture:** `chat/` holds what is this deployment's own for the chat, shaped as the sibling's `chat/` with the Google fields swapped for the Azure ones; `infra/chat/main.tf` is a second CI root in the same resource group with its own state key, calling the module chat-server ships under `deploy/azure/terraform`; `.github/workflows/chat.yml` and `report.yml` call the chat server's `deploy-azure.yml` and `report-azure.yml`. The chat goes live in the host's three merges: the first makes the app, the second writes `app_host` and the two ids the first apply names, the third says `dns_ready`. The chat's identity is made by hand before the first apply and adopted by an `import` block, because the Anthropic rule that lets the chat federate names that identity's object id, and `chat.json` names the rule before the first apply.

**Tech Stack:** `companygraph/chat-server` `v0.40.0`, `@robertblust/design` `v0.159.0`, `playwright` `^1.63.0`, Terraform with `hashicorp/azurerm` `~> 5.7` and `Azure/azapi` `~> 2.13`, Azure CLI for the owner's steps, the Anthropic Console for the issuer and the rule.

**Spec:** `docs/superpowers/specs/2026-09-28-the-servers-run-on-two-clouds-design.md` in `companygraph/chat-server`, §2 the ports and §4 the chat module, read with chat-server's README under *Deploying it on Azure* and this repository's `docs/superpowers/plans/2026-11-07-the-host-runs-on-azure.md`, whose Tasks 7 and 8 this repeats for the chat. Two things the host taught bind this plan: a pull request cannot plan before its state blob exists, so the owner writes `chat`'s empty state once; and the plan identity's custom role already covers `listSecrets` for every container app in the resource group.

## Global Constraints

- `chat/chat.json` names `domain` `chat.azure.companygraph.io`, `mcp_url` `https://mcp.azure.companygraph.io/mcp`, `origins` `["https://companygraph.io"]`, `month_tokens` as the owner sets it, `provider` `anthropic`, `inference_geo` `global`, `storage_account` `chatazurecompanygraphio` (checked free on 2026-11-07), and `anthropic_federation` with `rule_id`, `organization_id`, `service_account_id`, `workspace_id` and `audience`; after the first apply `app_host`, `questions_workspace_id` and `analyst_client_id`, and after the records `dns_ready`. No Google field: `site_id`, `run_host`, `verdict`, `verdict_threshold`, `sign_in` and `user_month_tokens` are refused by the shared config test.
- The chat server pin is `v0.40.0` in `chat/package.json`, in `chat.yml`'s and `report.yml`'s `uses:` and in `infra/chat/main.tf`'s `?ref=`; the chat server's shared pin test holds them to one.
- The required checks on `main` gain `chat / build` and `chat / terraform`.
- Every id in `chat.json` is an id, not a secret: the rule, the organization, the service account, the workspace, the audience, the two client ids.
- Worktree `~/git/companygraph/mcp-azure-companygraph-io-the-chat-runs-on-azure`; commits in the family's git register, authored by the Implementer, trailers `Process: Delivery`, `Phase: Implement`, `Track: Code`, `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`; pull request bodies end with the 🤖 line. Open each pull request and stop; merges, the Console and Hostpoint are the owner's.
- Before running anything: `export PATH=/opt/homebrew/bin:$PATH`; `az account show` names the subscription.

## Review Focus

1. **The import block adopting an identity that differs from what the module declares.** The by-hand identity has the module's name, location and resource group and no tags; a plan that shows more than an import and the rest to add means a field differs, and the fix is the `az identity create` arguments, not the module. Pinned in Task 4's plan reading.
2. **The Anthropic token exchange failing silently.** A rule whose `oid` is wrong lets the service start and the live GET pass while every question is refused with a credential error. Task 6 sends one question and reads the answer, not only the GET.
3. **A question reaching the general `logs` workspace.** The transformation on `logs` keeps everything but question lines; Task 6 queries both workspaces for the question and expects it in one.
4. **The `chat` state blob absent at the first pull-request plan.** Task 3 has the owner write it before the push, as the host's README step 3 says.
5. **The report workflow before any week has ended.** A run started by hand rebuilds the week that ended; on the first Monday it may find no question and write an empty report, which is correct. Task 7 runs it by hand once and reads the blob.

---

## Part A: the owner's once-only steps in the tenant and at Anthropic

### Task 1: The tenant has an app registration standing for the Claude API

Owner's step, run under the owner's `az login`; it needs the right to register applications, which a tenant gives its members unless an administrator turned it off. Once per tenant.

- [ ] **Step 1: Create it**

```sh
APP=$(az ad app create --display-name "Claude API" --sign-in-audience AzureADMyOrg --query appId -o tsv)
az ad app update --id "$APP" --identifier-uris "api://$APP" --set api.requestedAccessTokenVersion=2
az ad sp create --id "$APP" --query id -o tsv
echo "$APP"
```

Expected: a GUID, the `appId`, which `chat.json` names as `anthropic_federation.audience`. `az ad app show --id "$APP" --query '[identifierUris[0], api.requestedAccessTokenVersion]' -o tsv` reads `api://<appId>` and `2`.

### Task 2: Anthropic trusts the tenant, and the chat's identity

Owner's steps in the Anthropic Console, under Settings, Workload identity, after the identity of Task 3 exists.

- [ ] **Step 1: The issuer**

An issuer `https://login.microsoftonline.com/abf3b666-232b-4117-ae44-557e6b1a3341/v2.0` in discovery mode, then `max_jwt_lifetime_seconds` raised to 86400 after the wizard, because Azure caches a managed identity's token for up to a day and the default rejects it. Once per tenant.

- [ ] **Step 2: The rule**

A rule for the service account the chat runs as, with audience the `appId` of Task 1 and two claims: `oid` the object id of the identity Task 3 makes, and `tid` the tenant id above. Its `fdrl_` id goes into `chat.json`, with the organization, service account and workspace ids the Console shows for it.

## Part B: the repository

### Task 3: The chat's identity, its state and its files

**Files:**

- Create: `chat/chat.json`, `chat/package.json`, `chat/Dockerfile`, `chat/brand.html`, `chat/favicon.svg`, `chat/own.css`, `chat/test/chat.test.mjs`, `infra/chat/main.tf`, `infra/chat/.terraform.lock.hcl`, `.github/workflows/chat.yml`, `.github/workflows/report.yml`.
- Modify: `pins.json` (the two chat lines and the three verify lines, as the sibling has them with this repository's image name), `README.md` (`## The chat`), `AGENTS.md`.

**Interfaces:**

- Consumes: the `appId` from Task 1, the rule from Task 2.
- Produces: the identity `chat-run`'s resource id and object id; `npm test --prefix chat` as the suite; `terraform -chdir=infra/chat` for CI with the module's outputs passed through.

- [ ] **Step 1: The owner makes the identity and writes the empty state**

```sh
az identity create -g mcp-azure-companygraph-io -n chat-run -l switzerlandnorth --query '[id, principalId]' -o tsv
```

Expected: the resource id and the object id; the object id is what Task 2's rule names in `oid`. The identity is created outside Terraform once and adopted by the import block of Step 3; after the first apply the module owns it. Then, from the worktree once `infra/chat/main.tf` exists, `terraform -chdir=infra/chat init -input=false`, which writes the empty `chat.tfstate` as the owner, who holds Storage Blob Data Contributor on the container since the host's step 3.

- [ ] **Step 2: Copy and write the chat's files**

From `../mcp-companygraph-io/chat/`: `Dockerfile`, `brand.html`, `favicon.svg`, `own.css`, `test/chat.test.mjs` unchanged. `chat/package.json`: name `chat-azure-companygraph-io`, description `chat.azure.companygraph.io: the chat over mcp.azure.companygraph.io`, the sibling's scripts, engines, dependencies and devDependencies. `chat/chat.json` with the Global Constraints' values and the ids of Tasks 1 and 2. `.github/workflows/chat.yml` and `report.yml`: the sibling's, with `uses: companygraph/chat-server/.github/workflows/deploy-azure.yml@v0.40.0` and `report-azure.yml@v0.40.0`, and a comment that the modules are Azure's.

- [ ] **Step 3: Write the chat's root**

`infra/chat/main.tf`: the host's `infra/main.tf` shape with the backend `key = "chat.tfstate"`, `local.c = jsondecode(file("${path.module}/../../chat/chat.json"))`, the module `git::https://github.com/companygraph/chat-server.git//deploy/azure/terraform?ref=v0.40.0` taking `resource_group_name`, `registry_name = local.d.container_registry`, `domain`, `mcp_url`, `origins`, `month_tokens`, `storage_account`, `anthropic_federation = local.c.anthropic_federation`, `inference_geo = lookup(local.c, "inference_geo", null)`, `repository`, `repository_id`, `owner_id` from `local.d`, `image = var.image`, `app_host = lookup(local.c, "app_host", "")`, `dns_ready = lookup(local.c, "dns_ready", false)`; the outputs `service_url`, `app_host`, `dns_records` with `sensitive = true` as the host's has, `run_principal_id`, `analyst_client_id`, `questions_workspace_id`, `reports_url`; and the import block:

```hcl
# The chat's identity is made by hand before the first apply, because the rule at Anthropic that
# lets the chat federate names its object id and chat.json names that rule before the first
# apply. This adopts it; the block goes with the pull request that writes app_host, once the
# module owns the identity.
import {
  to = module.chat.azurerm_user_assigned_identity.run
  id = "<the resource id Step 1 printed>"
}
```

Then `terraform -chdir=infra/chat init -backend=false -input=false && terraform -chdir=infra/chat validate`, `terraform -chdir=infra/chat providers lock -platform=linux_amd64 -platform=darwin_arm64`, `terraform fmt -check -recursive infra`. Expected: valid, both platforms in the lock file, nothing to format.

- [ ] **Step 4: Run the chat's suite and build its image**

```sh
npm install --prefix chat --no-audit --no-fund && npm run page-css --prefix chat && npx playwright install --with-deps chromium && npm test --prefix chat && docker build -t mcp-azure-companygraph-io-chat:local chat
```

Expected: every test passes, the config test included, since `chat.json` is complete before the first apply; the image builds.

- [ ] **Step 5: The prose and the pins**

`README.md`'s `## The chat` rewritten for what is now true: what the chat is, where its values live, the four owner steps as they ran with their commands, the import block and why, the meter and how the chat is stopped by hand (the table `chat` in the storage account, partition `chat`, row `meter`, field `closed`), the questions' workspace and the owner's own reading, and the weekly report's container. `AGENTS.md` gains the chat paragraph the sibling's has, with the two new required checks. `pins.json` gains the sibling's two chat lines and three verify lines. `sh conventions/conventions-check && sh conventions/conventions-format` pass.

- [ ] **Step 6: Commit, the ruleset, and the pull request**

Commits per step as the host's plan did. Then the ruleset gains the two checks:

```sh
gh api repos/companygraph/mcp-azure-companygraph-io/rulesets --jq '.[] | select(.name=="protect-main") | .id'
```

and a `PUT` of the same ruleset with `required_status_checks` listing `conventions / conventions`, `deploy / build`, `deploy / terraform`, `chat / build`, `chat / terraform`. Push, open the pull request titled `The chat runs on Azure`, watch `chat / terraform`'s plan comment: the identity imported, the storage account, the table, the two containers' policy, the questions workspace with its two data collection rules and two azapi links, the diagnostic setting, the analyst with its credential and two role assignments, the app, and nothing to change or destroy. Report and stop.

## Part C: going live

### Task 4: After the first merge, the app's host and the two ids

- [ ] **Step 1: Read the apply**

The chat deploy on `main` applies, warns on `check "app_host"`, and fails its live check by design. From the log: `app_host`, `questions_workspace_id`, `analyst_client_id`. Confirm with `az containerapp show -g mcp-azure-companygraph-io -n chat --query properties.configuration.ingress.fqdn -o tsv`.

- [ ] **Step 2: The pull request**

Worktree `the-chat-has-a-host`: `chat.json` gains the three values, `infra/chat/main.tf` loses the import block, `npm test --prefix chat`, commit `The chat's host is in the allowlist and the import is done`, push, open, watch the plan say one container app changes in place. Stop.

### Task 5: The chat's domain

- [ ] **Step 1: The records**

After the merge's live check passes, the owner sets at Hostpoint the CNAME `chat.azure` to the app's host and the TXT `asuid.chat.azure` to `az containerapp show -g mcp-azure-companygraph-io -n chat --query properties.customDomainVerificationId -o tsv`; `dig +short` at `1.1.1.1` and `ns2.hostpoint.ch` answers both.

- [ ] **Step 2: The pull request**

Worktree `the-chat-domain-is-ready`: `"dns_ready": true`, `npm test --prefix chat`, commit, push, open; the plan adds the domain, the certificate and the bind. Stop. After the merge, `curl -sI https://chat.azure.companygraph.io/chat | head -1` reads `HTTP/2 200`.

### Task 6: The proof the spec asks for

- [ ] **Step 1: One question, answered**

```sh
curl -sS -X POST https://chat.azure.companygraph.io/chat -H 'content-type: application/json' -H 'origin: https://companygraph.io' -d '{"message":"What is CompanyGraph?"}'
```

Expected: an answer event stream naming the model commit, not a refusal; the request shape is `docs/INTERFACE.md`'s in chat-server. A credential error here means the rule or the audience, Review Focus 2.

- [ ] **Step 2: The question is kept once**

The owner grants their own reading once, `az role assignment create --assignee "$(az ad signed-in-user show --query id -o tsv)" --role "Log Analytics Data Reader" --scope <chat-questions workspace id>`, then, after the minutes ingestion takes:

```sh
az monitor log-analytics query -w <questions_workspace_id> --analytics-query "ContainerAppConsoleLogs | where Log has 'question' | project TimeGenerated, Log" -t P1D
az monitor log-analytics query -w <logs workspace id> --analytics-query "ContainerAppConsoleLogs | where ContainerAppName == 'chat' and Log has '\"kind\":\"question\"'" -t P1D
```

Expected: the question's line in the first and none in the second.

- [ ] **Step 3: What is measured later**

The hop count and the 240-second limit are read from a week's lines, not from one question; the README's chat section says where they are read and the ledger notes them as owed, not done.

### Task 7: The first report by hand

- [ ] **Step 1: Run and read**

`gh workflow run report` then `gh run watch`; the run signs in as the analyst and writes `reports/<week>.md` to the `reports` container of `chatazurecompanygraphio`. `az storage blob list --account-name chatazurecompanygraphio -c reports --auth-mode login -o table` lists it, read with the owner's data role if one is granted or left as the analyst's alone.

### Task 8: What the live run taught

- [ ] **Step 1: The list, and where each goes**

As the host's Task 9: every deviation goes into this README where it is this deployment's and into a `companygraph/chat-server` pull request where it is the module's. Two are known already and are the module's: the README's order, which names the rule after the first apply while `chat.json` needs it before, which the import block answers and the README should say; and the `dns_records` output's sensitive verification id, as mcp-server fixed in 0.74.1. Open and stop.
