# LTBase Deploy Workflows

Public reusable GitHub Actions workflows for the LTBase private deployment channel.

## Contents

- reusable workflows:
  - `preview.yml`
  - `deploy-devo.yml`
  - `promote-prod.yml`
- composite actions:
  - `setup-pulumi`
  - `download-private-release`
  - `run-codedeploy-canary`
  - `reconcile-managed-dsql-endpoint`
- scripts:
  - `scripts/reconcile-managed-dsql-endpoint.sh` — local/manual equivalent of the action

## Pulumi Execution Hardening

Reusable workflows now route `pulumi preview`, `pulumi up`, and `pulumi refresh` through the internal `.github/actions/run-pulumi` action.

The action:

- prefers `scripts/pulumi-wrapper.sh` in the blueprint repo when that file exists and is executable
- falls back to the direct `pulumi` CLI when no wrapper is present
- standardizes verbose logging and Go memory tuning in one place

This keeps workflow callers stable while allowing blueprint repos to ship lighter compile paths for Pulumi programs that would otherwise OOM.

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
- `reconcile_managed_dsql_endpoint` _(optional, default `false`)_ — when `true`, fetches the authoritative DSQL cluster endpoint from AWS after `pulumi up` and writes it back to Pulumi config as `dsqlEndpoint` before output capture (and before CodeDeploy canaries in `promote-prod`). Required for stacks that use managed Aurora DSQL.

Reusable workflow secrets:

- `aws_role_arn`
- `ltbase_releases_token`
- `cloudflare_api_token`

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
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN_DEVO }}
      ltbase_releases_token: ${{ secrets.LTBASE_RELEASES_TOKEN }}
      cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```
