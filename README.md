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

## Stable Interface

Reusable workflow inputs:

- `blueprint_ref`
- `pulumi_stack`
- `aws_region`
- `release_id`
- `pulumi_backend_url`
- `releases_repo`
- `working_directory`

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
      releases_repo: Lychee-Technology/ltbase-releases
      working_directory: infra
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN_DEVO }}
      ltbase_releases_token: ${{ secrets.LTBASE_RELEASES_TOKEN }}
      cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```
