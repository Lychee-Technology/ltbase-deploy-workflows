#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local path="$1"
  local needle="$2"
  if [[ ! -f "${path}" ]]; then
    fail "missing file: ${path}"
  fi
  if ! grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "name: Preview Stack"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "pulumi_secrets_provider"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "workflow_actions_ref"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "runs-on: ubuntu-24.04-arm"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "repository: Lychee-Technology/ltbase-deploy-workflows"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "go-version-file: \${{ format('blueprint/{0}/go.mod', inputs.working_directory) }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "cache-dependency-path: \${{ format('blueprint/{0}/go.sum', inputs.working_directory) }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" 'pulumi config set releaseAssetDir "$(pwd)/../.ltbase/releases" --stack "${{ inputs.pulumi_stack }}"'
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "name: Show Pulumi build environment"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "go env GOMOD GOCACHE GOMODCACHE"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" 'pulumi preview --stack "${{ inputs.pulumi_stack }}" --non-interactive --logtostderr --logflow -v=6'
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "name: Rollout Hop"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "run_canary"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "workflow_actions_ref"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "runs-on: ubuntu-24.04-arm"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "repository: Lychee-Technology/ltbase-deploy-workflows"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "go-version-file: \${{ format('blueprint/{0}/go.mod', inputs.working_directory) }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "cache-dependency-path: \${{ format('blueprint/{0}/go.sum', inputs.working_directory) }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" 'pulumi config set releaseAssetDir "$(pwd)/../.ltbase/releases" --stack "${{ inputs.pulumi_stack }}"'
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "name: Show Pulumi build environment"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "go env GOMOD GOCACHE GOMODCACHE"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" 'pulumi up --stack "${{ inputs.pulumi_stack }}" --yes --non-interactive --logtostderr --logflow -v=6'
assert_file_contains "${ROOT_DIR}/.github/workflows/deploy-devo.yml" ".github/workflows/rollout-hop.yml@"
assert_file_contains "${ROOT_DIR}/.github/workflows/promote-prod.yml" ".github/workflows/rollout-hop.yml@"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview.yml" ".github/workflows/preview-stack.yml@"

printf 'PASS: generic workflow tests\n'
