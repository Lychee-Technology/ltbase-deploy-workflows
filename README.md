# LTBase Deploy Workflows

Public reusable GitHub Actions workflows for the LTBase private deployment channel.

The upstream template repository can publish upstream-template-bound prebuilt `ltbase-infra` binaries into `Lychee-Technology/ltbase-private-deployment-binaries`. The reusable workflows inspect release manifests in that public repo, match them against checked-in blueprint provenance and runner architecture, and fall back to the blueprint repo's normal source-build wrapper path when no trusted match exists.

## Contents

- reusable workflows:
  - `preview.yml`
  - `deploy-devo.yml`
  - `promote-prod.yml`
- composite actions:
  - `setup-pulumi`
  - `download-private-release`
  - `deploy-controlplane-ui`
  - `run-codedeploy-canary`
  - `reconcile-managed-dsql-endpoint`
  - `reconcile-project-info`
- scripts:
  - `scripts/reconcile-managed-dsql-endpoint.sh` - local/manual equivalent of the action

## Pulumi Execution Hardening

Reusable workflows now route `pulumi preview`, `pulumi up`, and `pulumi refresh` through the internal `.github/actions/run-pulumi` action.

The action:

- installs a prebuilt `ltbase-infra` binary from `ltbase-private-deployment-binaries` when an exact source-repo, source-commit, and architecture match is available
- prefers `infra/scripts/pulumi-wrapper.sh` in the blueprint repo when that file exists and is executable
- falls back to the direct `pulumi` CLI when no wrapper is present
- standardizes verbose logging and Go memory tuning in one place

This keeps workflow callers stable while allowing blueprint repos to avoid repeated Go compilation for Pulumi programs that would otherwise OOM.

## Stable Interface

Reusable workflow inputs:

- `blueprint_ref`
- `pulumi_stack`
- `aws_region`
- `release_id`
- `pulumi_backend_url`
- `pulumi_secrets_provider`
- `releases_repo`
- `working_directory`
- `infra_binaries_repo` _(optional, default `Lychee-Technology/ltbase-private-deployment-binaries`)_
- `reconcile_managed_dsql_endpoint` _(optional, default `false`)_ - when `true`, fetches the authoritative DSQL cluster endpoint from AWS after `pulumi up` and writes it back to Pulumi config as `dsqlEndpoint` before output capture (and before CodeDeploy canaries in `promote-prod`). Required for stacks that use managed Aurora DSQL.
- `controlplane_ui_domain` _(optional)_ - shared Cloudflare Pages custom domain used to derive `redirectUri=https://<domain>/auth/callback` for every included stack.
- `controlplane_ui_pages_project` _(optional)_ - shared Cloudflare Pages project that should receive the official control plane UI release artifact.
- `controlplane_ui_stacks` _(optional)_ - comma-separated stack list to inspect after rollout. The deployed stack must be included. Stacks missing `controlplaneUiStackConfig` are skipped unless they are the current rollout target.

After every successful `pulumi up`, the rollout workflows also reconcile the authservice `project info` item in DynamoDB before output capture. The internal `reconcile-project-info` action reads `projectId`, `apiId`, `apiBaseUrl`, and `tableName` from stack outputs, resolves the current AWS account id with `sts get-caller-identity`, and writes the record with:

- `PK=project#<projectId>`
- `SK=info`
- `account_id=<current aws account id>`
- `api_id=<deployed data plane api id>`
- `api_base_url=https://<api domain>`

Prebuilt infra binary lookup now reads `blueprint/__ref__/template-provenance.json` from the checked-out deployment repo and matches releases by upstream template repository, upstream template commit, `build_fingerprint`, and runner architecture. If provenance is missing, malformed, delayed, or mismatched, the workflow falls back to source build.

Reusable workflow secrets:

- `aws_role_arn`
- `ltbase_releases_token`
- `cloudflare_api_token`

## Control Plane UI Rollout

`rollout-hop.yml` can now publish the official control plane UI artifact to Cloudflare Pages after the backend rollout, any CodeDeploy canaries, and any optional `pulumi refresh` succeed.

The rollout path stays opt-in. UI deployment only runs when all three optional inputs are supplied:

- `controlplane_ui_domain`
- `controlplane_ui_pages_project`
- `controlplane_ui_stacks`

Preview remains infra-only and never deploys the UI.

The runtime config is built by reading `pulumi stack output --json` for every stack in `controlplane_ui_stacks`, extracting `controlplaneUiStackConfig`, adding `redirectUri`, and deploying a final `ltbase-controlplane.config.json` with only the stacks that currently expose a complete output contract. If the current rollout target is missing `controlplaneUiStackConfig`, the workflow fails.

The deploy action currently expects a release artifact manifest entry named `controlplane-ui` that points to a `tar.gz` archive with a top-level `dist/` directory.

Important: that artifact is not yet part of the currently documented release contract in `ltbase.api` / `ltbase-releases`. This rollout path therefore depends on a separate release-contract change landing first.

## Version Policy

- first stable version: `v1.0.0`
- customer default reference: `@v1`
- `v1` is the floating major tag

## Example

```yaml
jobs:
  deploy:
    uses: Lychee-Technology/ltbase-deploy-workflows/.github/workflows/deploy-devo.yml@v1
    with:
      pulumi_stack: devo
      aws_region: ap-northeast-1
      release_id: v1.0.0
      pulumi_backend_url: ${{ vars.PULUMI_BACKEND_URL }}
      pulumi_secrets_provider: ${{ vars.PULUMI_SECRETS_PROVIDER_DEVO }}
      releases_repo: Lychee-Technology/ltbase-releases
      working_directory: infra
      reconcile_managed_dsql_endpoint: true
      controlplane_ui_domain: ${{ vars.CONTROLPLANE_UI_DOMAIN }}
      controlplane_ui_pages_project: ${{ vars.CONTROLPLANE_UI_PAGES_PROJECT }}
      controlplane_ui_stacks: ${{ vars.STACKS }}
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN_DEVO }}
      ltbase_releases_token: ${{ secrets.LTBASE_RELEASES_TOKEN }}
      cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```
