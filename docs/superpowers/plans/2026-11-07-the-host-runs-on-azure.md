# The host runs on Azure — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The first real deployment of `companygraph/mcp-server` on Azure: `companygraph/mcp-azure-companygraph-io`, serving CompanyGraph's own model at `https://mcp.azure.companygraph.io/mcp` from a Container App in Switzerland North, applied by GitHub Actions from the modules the server ships under `deploy/azure/`, and kept running at scale to zero as the standing proof.

**Architecture:** The repository is shaped like `companygraph/mcp-companygraph-io` with the Google parts swapped for the Azure ones: `deployment.json` names `"platform": "azure"` and the subscription's values, `infra/bootstrap/main.tf` calls `deploy/azure/bootstrap` once under the owner's login, `infra/main.tf` calls `deploy/azure/terraform` from CI with an `azurerm` backend on the bootstrap's state account, and `.github/workflows/deploy.yml` calls `deploy-azure.yml`, all at `v0.74.0`. The deployment goes live in three merges, as the module is built for: the first makes the app and names its host, the second writes `app_host`, the third says `dns_ready` once the two records are at Hostpoint. The chat is not part of this plan; it follows as its own pull request in this repository once the host is live.

**Tech Stack:** Node >= 22 ESM, `node:test`, Playwright for the page tests, Docker, Terraform 1.9.8 in CI with `hashicorp/azurerm` `~> 5.7` and `Azure/azapi` `~> 2.13`, Azure CLI 2.92 for the owner's steps, `gh` for the repository.

**Spec:** `docs/superpowers/specs/2026-09-28-the-servers-run-on-two-clouds-design.md` in `companygraph/chat-server`, §7 piece 3. Three things decided on 2026-11-07 with the owner differ from the spec and bind this plan:

1. **The name.** The repository is `companygraph/mcp-azure-companygraph-io`, not `mcp-azure-example`, because the family names a deployment after its domain. The domain stays `mcp.azure.companygraph.io`.
2. **The model served.** The host serves `companygraph/mental-model` at the commit `companygraph/mcp-companygraph-io` pins, not the meta-model's worked example. The example has no `.companygraph/manifest.json` and takes three packs that only mcp-server's test helpers name, so `companygraph-mcp-deploy snapshot` cannot read it from GitHub without a change to mcp-server; that change is not this plan's. The Google and Azure hosts serving one commit of one model is also the plainer proof.
3. **Host first.** The chat, its app registration and the Anthropic federation issuer wait for a later pull request. What the spec measures for the chat alone, the hop count and the 240-second limit, waits with it.

The subscription was upgraded from a free trial to pay-as-you-go on 2026-11-07 before this plan, so no spending limit stops the app.

## Global Constraints

- The values that are this deployment's own, copied verbatim into `deployment.json`: `tenant_id` `abf3b666-232b-4117-ae44-557e6b1a3341`, `subscription_id` `fde0a7c3-6f5a-4fe3-a7d5-2b33b67aea80`, `resource_group` `mcp-azure-companygraph-io`, `location` `switzerlandnorth`, `container_registry` `mcpazurecompanygraphio`, `state_account` `mcpazurecompanygraphio`, `domain` `mcp.azure.companygraph.io`, `budget_chf` `40`, `repository` `companygraph/mcp-azure-companygraph-io`, `owner_id` `"320206107"`. Both global names were checked free on 2026-11-07.
- `budget_start` is the first of the month the first apply lands in, `2026-11-01` if that is November; Azure refuses a month already past.
- The server pin is `v0.74.0` in `package.json`, in `deploy.yml`'s `uses:` and in both roots' `?ref=`; the shared pin test holds the three to one. `@robertblust/design` is `v0.159.0`, `@modelcontextprotocol/client` `^2.4.0`, `playwright` `^1.64.1`, as the sibling has them.
- `source.json` is the sibling's: `{"repo": "companygraph/mental-model", "commit": "<the commit companygraph/mcp-companygraph-io pins on the day of Task 2>"}`.
- `registry_name`, `registry_domain` and `publish.yml` stay out: this deployment publishes no MCP Registry entry. `kpi.yml`, `chat.yml` and `report.yml` stay out: the KPI is the organization's and sits beside mcp.companygraph.io, and the chat is later.
- Every secret-looking value here is an id, not a secret: the tenant, the subscription, the three client ids and the verification id are safe in a public repository, as the bootstrap README says.
- The branch lives in a sibling worktree `~/git/companygraph/mcp-azure-companygraph-io-the-host-runs-on-azure`; the clone stays on `main`.
- Commits are in the family's git register: a plain-sentence subject under seventy characters, a prose body, a `Verified:` line naming what ran, then the trailers `Process: Delivery`, `Phase: Implement`, `Track: Code` and `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`, authored `--author "Implementer <implementer@companygraph.io>"`. Pull request bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Open each pull request and stop. Merging, the DNS records and the Hostpoint login are the owner's.
- Before running anything: `export PATH=/opt/homebrew/bin:$PATH`; `az account show` must name the subscription above.

## Review Focus

1. **`terraform-plan` cannot refresh a resource as Reader.** The first pull-request plan is the test the bootstrap README defers to; if it fails on an action such as a container app's `listSecrets`, the fix is a custom role in mcp-server's bootstrap, not a wider role here. Pinned in Task 6, which reads the plan comment for exactly that.
2. **The first apply fails its live check.** By design: the service refuses a POST on a host `MCP_ALLOWED_HOSTS` does not name until `app_host` is written. The `check "app_host"` warning in the apply log names the host. Pinned in Task 7, which reads it from there and from `az containerapp show`.
3. **The domain added before both records resolve.** Azure checks the CNAME and the `asuid` TXT when the domain is added, and refuses otherwise. Task 8 runs `dig` on both before `dns_ready` is set.
4. **The certificate not yet issued when the bind runs.** A managed certificate takes minutes to validate, and the apply may fail at the bind on the first run. Task 8 re-runs the workflow on `main` rather than changing anything.
5. **A lock file hashed for the wrong platform.** `terraform init` on this Mac writes `darwin_arm64` hashes and CI runs `linux_amd64`; a lock file without the second fails `init` in CI. Task 3 writes both.

---

## Part A: the repository

### Task 1: The repository exists

**Files:**

- Create: `LICENSE`, `.gitignore`, `conventions.json`, `conventions/` and the root files `conventions-sync` writes, `CLAUDE.md`, `AGENTS.md` (the block only), `.claude/agents/{writer,translator,editor,backreader}.md`, this plan.

**Interfaces:**

- Produces: `repository_id`, the numeric id of the new repository, which Task 2 writes into `deployment.json`; the clone at `~/git/companygraph/mcp-azure-companygraph-io` on `main`; the worktree and branch `the-host-runs-on-azure`.

- [ ] **Step 1: Make the local repository and vendor the conventions**

In `~/git/companygraph/mcp-azure-companygraph-io`: `git init -b main`, copy `LICENSE`, `.gitignore` and `.claude/agents/*.md` from `../mcp-companygraph-io`, then take the conventions as its README says, at `v1.52.0`:

```sh
printf '{ "repo": "robertblust/conventions", "tag": "v1.52.0", "exclude": ["docs/superpowers", "node_modules"], "format-exclude": ["node_modules"] }\n' > conventions.json
curl -fsSL https://raw.githubusercontent.com/robertblust/conventions/v1.52.0/conventions/conventions-sync -o /tmp/conventions-sync
sh /tmp/conventions-sync sync
```

Expected: `conventions/`, `CLAUDE.md`, `.markdownlint-cli2.jsonc` and an `AGENTS.md` holding the block exist, and `sh conventions/conventions-sync check` prints `✓`.

- [ ] **Step 2: Create the GitHub repository and set it like its sibling**

```sh
gh repo create companygraph/mcp-azure-companygraph-io --public --description "mcp.azure.companygraph.io: CompanyGraph's own model served over MCP from Azure" --source . --remote origin
gh api -X PATCH repos/companygraph/mcp-azure-companygraph-io -F allow_squash_merge=false -F allow_rebase_merge=false -F allow_merge_commit=true -F has_wiki=false -F has_projects=false
gh api repos/companygraph/mcp-azure-companygraph-io --jq '.id'
gh api repos/companygraph/mcp-azure-companygraph-io/actions/oidc/customization/sub
```

Expected: the id is printed, and the last line reads `"use_immutable_subject":true` with `sub_claim_prefix` of the form `repo:companygraph@320206107/mcp-azure-companygraph-io@<id>`. A repository created today has that by default; if it does not, set it once: `gh api -X PUT repos/companygraph/mcp-azure-companygraph-io/actions/oidc/customization/sub -F use_default=true -F use_immutable_subject=true`.

- [ ] **Step 3: Commit on main and push**

The one commit this plan makes on `main`, because the branch ruleset does not exist yet and a worktree needs a commit to branch from. Subject `The repository takes the family's conventions`, body saying the deployment itself comes in a pull request. `git config user.email` must answer `robert@blust.ch` before it. Then `git push -u origin main`.

- [ ] **Step 4: Protect main**

The sibling's `protect-main` ruleset with this repository's three checks:

```sh
gh api -X POST repos/companygraph/mcp-azure-companygraph-io/rulesets --input - <<'JSON'
{"name":"protect-main","target":"branch","enforcement":"active",
 "bypass_actors":[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}],
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"},
  {"type":"pull_request","parameters":{"allowed_merge_methods":["merge"],"dismiss_stale_reviews_on_push":true,"require_code_owner_review":false,"require_extra_approval_for_unattributed_changes":true,"require_last_push_approval":false,"required_approving_review_count":0,"required_review_thread_resolution":false}},
  {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"conventions / conventions"},{"context":"deploy / build"},{"context":"deploy / terraform"}]}}]}
JSON
```

Expected: `gh api repos/companygraph/mcp-azure-companygraph-io/rulesets --jq '.[].name'` prints `protect-main`.

- [ ] **Step 5: Make the worktree**

`git worktree add ../mcp-azure-companygraph-io-the-host-runs-on-azure -b the-host-runs-on-azure`, then `sh conventions/conventions-sync sync` there once so `core.hooksPath` is set. Every later task works in that worktree.

### Task 2: The deployment's own files

**Files:**

- Create: `package.json`, `source.json`, `deployment.json`, `Dockerfile`, `.dockerignore`, `brand.html`, `favicon.svg`, `own.css`, `robots.txt`, `test/shared.test.mjs`, `test/instance.test.mjs`, `.github/dependabot.yml`, `.github/workflows/conventions.yml`, `.github/workflows/deploy.yml`.

**Interfaces:**

- Consumes: `repository_id` from Task 1.
- Produces: `deployment.json` with every Azure field but the three client ids, which Task 4 adds; `npm test` as the suite Tasks 4 and 6 run.

- [ ] **Step 1: Copy what is the same as the sibling's**

From `../mcp-companygraph-io`: `Dockerfile`, `.dockerignore`, `brand.html`, `favicon.svg`, `own.css`, `test/shared.test.mjs`, `.github/workflows/conventions.yml`, `.github/dependabot.yml`. In `dependabot.yml` drop the `*companygraph/chat-server*` ignore line, since no workflow here calls it; keep the rest, comments included. In `robots.txt` the header line reads `# mcp.azure.companygraph.io` and the rest is the sibling's.

- [ ] **Step 2: Write the files that differ**

`package.json`: name `mcp-azure-companygraph-io`, version `0.1.0`, private, description `mcp.azure.companygraph.io: CompanyGraph's own model served over MCP from Azure`, the sibling's `engines`, `type`, `dependencies` and `devDependencies`, and the scripts `snapshot`, `page-css`, `jsonld` and `test` only.

`source.json`: the sibling's, read from `../mcp-companygraph-io/source.json` on the day.

`deployment.json`, the Global Constraints' values plus `"platform": "azure"` and `"repository_id": "<Task 1's id>"`, as a string like the sibling's.

`.github/workflows/deploy.yml`: the sibling's with `uses: companygraph/mcp-server/.github/workflows/deploy-azure.yml@v0.74.0` and a comment saying the modules are Azure's.

- [ ] **Step 3: Write the instance test**

`test/instance.test.mjs`, three tests over `dist/snapshot.json` and `deployment.json`:

```js
test("the root is CompanyGraph", () => assert.equal(s.root, "CompanyGraph"));
test("the product the company makes resolves by its type and name", /* the sibling's, verbatim */);
test("no surface names this repository, so the page carries no structured data", () => {
  const d = JSON.parse(fs.readFileSync(path.join(process.cwd(), "deployment.json"), "utf8"));
  assert.equal(jsonld(s, { repository: d.repository }), null);
});
```

with `jsonld` imported from `companygraph-mcp-server/deploy`. The third holds what the shared crawler test only implies: the model's MCP surface is built by the sibling, so this host says nothing to a crawler rather than claiming the sibling's surface.

- [ ] **Step 4: Run the suite and read that only the config test fails**

```sh
npm install && GITHUB_TOKEN=$(gh auth token) npm run snapshot && npm run page-css && npm run jsonld && npx playwright install --with-deps chromium && npm test
```

Expected: one failure, the config test, naming `deployment.json has no terraform_client_id`, `plan_client_id` and `deploy_client_id`; every other test passes. `npm install` rather than `npm ci`, once, to write `package-lock.json`; `ls dist/jsonld.json` must say no such file.

- [ ] **Step 5: Build the image**

`docker build -t mcp-azure-companygraph-io:local .` Expected: exit 0.

- [ ] **Step 6: Commit**

Subject `The deployment names its values and runs the server's tests`. `Verified:` names the suite's counts and the one expected failure.

### Task 3: The two Terraform roots

**Files:**

- Create: `infra/bootstrap/main.tf`, `infra/bootstrap/.terraform.lock.hcl`, `infra/main.tf`, `infra/.terraform.lock.hcl`.

**Interfaces:**

- Produces: `terraform -chdir=infra/bootstrap apply` for Task 4 with the outputs `tenant_id`, `terraform_client_id`, `plan_client_id`, `deploy_client_id`, `registry`, `state_account`; `terraform -chdir=infra` for CI with the outputs `service_url`, `app_host`, `dns_records`, `environment_name`, `logs_workspace_name`.

- [ ] **Step 1: Write the bootstrap root**

`infra/bootstrap/main.tf`: the block mcp-server's `deploy/azure/bootstrap/README.md` gives, verbatim, with `required_providers` azurerm `~> 5.7`, `required_version = ">= 1.9"`, `local.d = jsondecode(file("${path.module}/../../deployment.json"))`, the provider block with its seven resource providers, the module at `?ref=v0.74.0` with `registry_name = local.d.container_registry`, and the six outputs. The head comment says what the sibling's says, for Azure: applied once by the owner with local state.

- [ ] **Step 2: Write the CI root**

`infra/main.tf`:

```hcl
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
provider "azapi" { subscription_id = local.d.subscription_id }
module "mcp" {
  source              = "git::https://github.com/companygraph/mcp-server.git//deploy/azure/terraform?ref=v0.74.0"
  resource_group_name = local.d.resource_group
  registry_name       = local.d.container_registry
  domain              = local.d.domain
  budget_chf          = local.d.budget_chf
  budget_start        = local.d.budget_start
  image               = var.image
  app_host            = lookup(local.d, "app_host", "")
  dns_ready           = lookup(local.d, "dns_ready", false)
}
```

plus the five outputs passed through from the module. The backend names literals because a backend block takes no expression; the head comment says so and says the identity comes from `ARM_*` in the workflow. `lookup` with a default is what lets the first apply run before `app_host` and `dns_ready` exist in the file.

- [ ] **Step 3: Validate both and write the lock files for both platforms**

```sh
terraform -chdir=infra/bootstrap init -backend=false -input=false && terraform -chdir=infra/bootstrap validate
terraform -chdir=infra init -backend=false -input=false && terraform -chdir=infra validate
terraform -chdir=infra providers lock -platform=linux_amd64 -platform=darwin_arm64
terraform -chdir=infra/bootstrap providers lock -platform=linux_amd64 -platform=darwin_arm64
terraform fmt -check -recursive infra
```

Expected: `Success! The configuration is valid.` twice, both lock files carry `h1:` hashes for both platforms, `fmt` prints nothing.

- [ ] **Step 4: Run the pin test**

`npm test`. Expected: the test `the server's release is named once, in package.json, the workflows and the module` passes; the config test still fails on the three ids.

- [ ] **Step 5: Commit**

Subject `Two Terraform roots call the server's Azure modules`.

### Task 4: The bootstrap is applied

The owner's step, run from the worktree under the owner's `az login`, as the sibling's was from its branch. It changes the subscription, so the owner says go before Step 2 runs.

**Files:**

- Modify: `deployment.json` (the three client ids), `.gitignore` already ignores `*.tfstate*`.

- [ ] **Step 1: Plan**

`terraform -chdir=infra/bootstrap init && terraform -chdir=infra/bootstrap plan`. Expected: a plan adding the resource group, the storage account and container, the registry, three identities, three federated credentials and the role assignments, and nothing to change or destroy. Read the three `subject` values: each begins `repo:companygraph@320206107/mcp-azure-companygraph-io@<id>`.

- [ ] **Step 2: Apply and keep the state**

```sh
terraform -chdir=infra/bootstrap apply
cp infra/bootstrap/terraform.tfstate ~/mcp-azure-companygraph-io-bootstrap.tfstate
terraform -chdir=infra/bootstrap output
```

Expected: `Apply complete!`; the six outputs printed. The state copy outside the worktree is the bootstrap's only state, and the README of Task 5 says where it is. The seven providers read `Registered` in `az provider list -o table` afterwards.

- [ ] **Step 3: Write the ids and read the suite green**

Write `terraform_client_id`, `plan_client_id` and `deploy_client_id` from the outputs into `deployment.json`, then `npm test`. Expected: every test passes, the config test included.

- [ ] **Step 4: Commit**

Subject `The bootstrap is applied and CI knows its identities`. The body says the state is at `~/mcp-azure-companygraph-io-bootstrap.tfstate` and nowhere in git.

### Task 5: What a reader is told

**Files:**

- Create: `README.md`, `infra/bootstrap/README.md`.
- Modify: `AGENTS.md` (the `## This repository` section below the block).

- [ ] **Step 1: Write README.md**

Title `# mcp.azure.companygraph.io`, the exact string the family's `REPOSITORIES.md` row will carry. Prose register, modelled on the sibling's sections: what it is, in one paragraph saying it is the first deployment of the server on Azure and the proof of chat-server's two-clouds design, and that it serves the same model and commit as mcp.companygraph.io; `## Using it`; `## What pins what`; `## Building it`; `## Infrastructure`, naming the two roots, the `azurerm` backend on the bootstrap's state account, the three identities and what each may do, and that a pull request plans as `terraform-plan`; `## The owner's steps`, the record in the sibling's form, numbered, with the commands of Tasks 1, 4, 7 and 8 as they ran; and `## The chat`, one paragraph saying `chat.azure.companygraph.io` is the next pull request and what it will ask of the owner, pointing at chat-server's README. No number that still moves.

- [ ] **Step 2: Write infra/bootstrap/README.md**

The sibling's, for Azure: what the bootstrap makes, that the owner applies it under `az login` with local state kept at `~/mcp-azure-companygraph-io-bootstrap.tfstate`, the restore-before-re-apply rule with the plan that must add nothing, the six commands, and the Reader note the module's README defers to the first pull-request plan.

- [ ] **Step 3: Write the AGENTS.md section**

`## This repository` in the sibling's shape: what is this deployment's own, the three required checks `conventions / conventions`, `deploy / build` and `deploy / terraform`, the three-place pin, that `infra/bootstrap/` is the owner's and `infra/` CI's, and that the page carries no JSON-LD because the model's MCP surface is the sibling's.

- [ ] **Step 4: Check the prose and its form**

`sh conventions/conventions-check && sh conventions/conventions-format`. Expected: both exit 0 with no `✗` line; the title check reports the repository is not yet in `REPOSITORIES.md`, which Task 10 settles.

- [ ] **Step 5: Commit**

Subject `The README says what the host is and how it was stood up`.

### Task 6: The pull request, and the subject GitHub signs

**Files:**

- Create then delete: `.github/workflows/oidc-subject.yml`.

- [ ] **Step 1: Add a throwaway workflow that prints the token's subject**

One job on `pull_request` with `id-token: write`, one step that requests the token with `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN`, decodes its payload with `base64 -d | jq .sub` and prints it. A subject is not a secret. Commit it with the subject `A throwaway job prints the subject GitHub signs`.

- [ ] **Step 2: Push and open the pull request**

`git push -u origin the-host-runs-on-azure`, then `gh pr create` titled `The host runs on Azure`. The body is the prose register for a reviewer who has not seen the diff: why, in one paragraph; what the repository holds and what the owner applied; the three merges to come and what each needs from the owner; `Verified:` naming what ran; the 🤖 line.

- [ ] **Step 3: Read the checks**

`gh pr checks --watch`. Expected: `conventions / conventions`, `deploy / build` and `deploy / terraform` green, and the throwaway job's log showing `repo:companygraph@320206107/mcp-azure-companygraph-io@<id>:pull_request`, the subject the bootstrap's `plan` credential trusts. The plan comment on the pull request must say `Plan:` with the workspace, the environment, the identity, the role assignment, the app, the diagnostic setting and the budget to add, and nothing to change or destroy. If `terraform plan` fails to refresh for want of an action, write the action's name into the pull request as a comment and stop: the fix is a custom role in mcp-server's bootstrap, which is a separate pull request there and a re-pin here.

- [ ] **Step 4: Remove the throwaway and stop**

Delete `.github/workflows/oidc-subject.yml`, commit `The throwaway job is gone` with the subject it printed in the body, push, confirm the three checks green again, report the link and stop. Merging is the owner's word.

## Part B: going live

Each task here starts after the owner merged the previous pull request.

### Task 7: The app's host is written

- [ ] **Step 1: Read the first deploy on main**

`gh run list --workflow deploy --branch main --limit 1` then `gh run view <id> --log`. Expected: `terraform apply` finished with `Apply complete!`, the `check "app_host"` warning names the app's host, and the live-check step failed by design.

- [ ] **Step 2: Confirm the host and the app**

`az containerapp show -g mcp-azure-companygraph-io -n mcp --query properties.configuration.ingress.fqdn -o tsv`. Expected: the host the warning named, of the form `mcp.<something>.switzerlandnorth.azurecontainerapps.io`. `curl -s https://<host>/health` answers; `curl -s -X POST https://<host>/mcp ...` is refused, as the allowlist says.

- [ ] **Step 3: Write it and open the pull request**

In a worktree `../mcp-azure-companygraph-io-the-app-has-a-host`, branch `the-app-has-a-host`: add `"app_host": "<host>"` to `deployment.json`, `npm test`, commit `The app's host is in the allowlist`, push, open the pull request, watch its plan say one container app changes in place and nothing else, report and stop.

- [ ] **Step 4: After the merge, read the live check pass**

The deploy on `main` ends with `serving <commit>, pinned <commit>` and the step green. The two records the `dns_records` output names are then read without the state, because Owner on the subscription carries no blob data role and the state container is read by identities alone: the CNAME is the host of Step 2, and the TXT is `az containerapp show -g mcp-azure-companygraph-io -n mcp --query properties.customDomainVerificationId -o tsv`. Give both to the owner; the apply log on `main` prints the same output.

### Task 8: The domain and its certificate

- [ ] **Step 1: The owner sets the two records at Hostpoint**

The CNAME `mcp.azure` to the app's host and the TXT `asuid.mcp.azure` to the verification id, at `companygraph.io`. Then, until both answer:

```sh
dig +short CNAME mcp.azure.companygraph.io
dig +short TXT asuid.mcp.azure.companygraph.io
```

Expected: the app's host and the id, from a public resolver.

- [ ] **Step 2: Say dns_ready and open the pull request**

Worktree `../mcp-azure-companygraph-io-the-domain-is-ready`, branch `the-domain-is-ready`: `"dns_ready": true` in `deployment.json`, `npm test`, commit `The domain's records are set and the certificate may be issued`, push, open the pull request. Its plan adds the custom domain, the managed certificate and the bind action, and changes nothing else. Report and stop.

- [ ] **Step 3: After the merge, prove the domain**

If the apply fails at the bind because the certificate is still validating, `gh run rerun <id>` once the certificate reads `Succeeded` in `az containerapp env certificate list -g mcp-azure-companygraph-io -n apps -o table`. Then:

```sh
curl -sI https://mcp.azure.companygraph.io/ | head -1
curl -s -X POST https://mcp.azure.companygraph.io/mcp -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_types","arguments":{}}}' | jq -r .result.structuredContent.model.commit
```

Expected: `HTTP/2 200` and the pinned commit. Add `https://mcp.azure.companygraph.io/mcp` as a connector in Claude and ask one question; the answer names the commit.

### Task 9: What the live run taught

- [ ] **Step 1: List what differed from the modules' expectations**

Every place a task above deviated: a plan that needed an action Reader lacks, a bind that had to be re-run, an output that was wrong or missing, a README sentence in mcp-server's `deploy/azure/` that the run showed to be untrue. Write the list into the README's owner's steps where it is this deployment's, and into a pull request in `companygraph/mcp-server` where it is the module's, as a patch release the spec promises; each such pull request opens and stops. An empty list is written as one sentence in the README: that the first live apply changed nothing in the modules.

## Part C: the family

### Task 10: The family lists the member

**Files:**

- Modify in `~/git/robertblust/conventions`: `conventions/REPOSITORIES.md` (the table row, the drawing, the pins paragraph).
- Create here: `pins.json`.
- Modify in `~/git/companygraph/chat-server`: `docs/superpowers/specs/2026-09-28-the-servers-run-on-two-clouds-design.md`.

- [ ] **Step 1: The row, the node and the arrows**

In a worktree of robertblust/conventions, branch `the-azure-host-joins`: a row after `companygraph/chat-server`'s, `| companygraph/mcp-azure-companygraph-io | mcp.azure.companygraph.io | mcp.azure.companygraph.io, CompanyGraph's own instance served over MCP from a pinned commit of the model, on Azure, the first deployment of the server there | main | ~/git/companygraph/mcp-azure-companygraph-io |`; the node `mcpaz[mcp-azure-companygraph-io]` under `companygraph` in the drawing with arrows `mcpaz -->|tag| design`, `mcpaz -->|tag| mcpsrv` and `mcpaz -->|commit| cgmm`; and the pins paragraph naming it beside the three deployments, the chat left out until it has one. Run that repository's suite; the drawing test must pass. Commit, open the pull request, stop; the release and the resync are the owner's.

- [ ] **Step 2: pins.json**

The sibling's `pins.json` without the two chat lines and with this repository's name in the `docker build` lines; `verify` ends at the image. Commit `The member declares its pins`, in the pull request of whichever task is open or a pull request of its own.

- [ ] **Step 3: The spec keeps the decision**

In chat-server, a worktree on branch `piece-3-is-named`: in §7 of the spec, piece 3's paragraph names `companygraph/mcp-azure-companygraph-io`, says it serves CompanyGraph's own model at the sibling's commit and why the example waits, and that the host went live first with the chat to follow. One pull request, titled `The spec names the Azure deployment as it was built`, and stop.
