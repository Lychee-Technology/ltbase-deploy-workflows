#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

line_number_for() {
  local path="$1"
  local needle="$2"
  local line
  line="$(grep -n -F -- "${needle}" "${path}" | head -n 1 | cut -d: -f1)"
  if [[ -z "${line}" ]]; then
    fail "expected ${path} to contain line: ${needle}"
  fi
  printf '%s\n' "${line}"
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
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "uname -a"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "go env GOMOD GOCACHE GOMODCACHE GOARCH GOOS"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "actions: read"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" ".github/actions/install-prebuilt-infra-binary"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "infra_binaries_repo"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "provenance-path: blueprint/__ref__/template-provenance.json"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" ".github/actions/run-pulumi"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview-stack.yml" "command: preview"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "name: Rollout Hop"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "run_canary"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "workflow_actions_ref"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "runs-on: ubuntu-24.04-arm"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "repository: Lychee-Technology/ltbase-deploy-workflows"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "go-version-file: \${{ format('blueprint/{0}/go.mod', inputs.working_directory) }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "cache-dependency-path: \${{ format('blueprint/{0}/go.sum', inputs.working_directory) }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" 'pulumi config set releaseAssetDir "$(pwd)/../.ltbase/releases" --stack "${{ inputs.pulumi_stack }}"'
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "name: Show Pulumi build environment"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "uname -a"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "go env GOMOD GOCACHE GOMODCACHE GOARCH GOOS"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "actions: read"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" ".github/actions/install-prebuilt-infra-binary"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "infra_binaries_repo"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "provenance-path: blueprint/__ref__/template-provenance.json"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" ".github/actions/run-pulumi"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" ".github/actions/reconcile-project-info"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "reconcile_managed_dsql_endpoint"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "name: Re-apply stack after managed DSQL reconcile"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "if: \${{ inputs.reconcile_managed_dsql_endpoint }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "command: up"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "command: refresh"

reconcile_line="$(line_number_for "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "- name: Reconcile managed DSQL endpoint")"
reapply_line="$(line_number_for "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "- name: Re-apply stack after managed DSQL reconcile")"
project_info_line="$(line_number_for "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "- name: Reconcile project info")"
outputs_line="$(line_number_for "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "- name: Capture deployment outputs")"
canary_line="$(line_number_for "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "- name: Run data plane canary")"

if (( reconcile_line >= reapply_line )); then
  fail "expected managed DSQL reconcile to happen before second apply"
fi
if (( reapply_line >= project_info_line )); then
  fail "expected second apply to happen before project info reconcile"
fi
if (( project_info_line >= outputs_line )); then
  fail "expected project info reconcile to happen before output capture"
fi
if (( outputs_line >= canary_line )); then
  fail "expected output capture to happen before canary steps"
fi
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" "strategy:"
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" "ubuntu-24.04-arm"
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" "ubuntu-24.04"
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" "command: preview"
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" "blueprint_repository"
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" "repository: \${{ inputs.blueprint_repository }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" ".github/actions/download-private-release"
assert_file_contains "${ROOT_DIR}/.github/workflows/diagnose-go-compile.yml" "token: \${{ secrets.LTBASE_RELEASES_TOKEN }}"
assert_file_contains "${ROOT_DIR}/.github/workflows/deploy-devo.yml" ".github/workflows/rollout-hop.yml@"
assert_file_contains "${ROOT_DIR}/.github/workflows/promote-prod.yml" ".github/workflows/rollout-hop.yml@"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview.yml" ".github/workflows/preview-stack.yml@"

printf 'PASS: generic workflow tests\n'
