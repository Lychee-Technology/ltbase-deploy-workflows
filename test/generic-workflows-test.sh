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
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "name: Rollout Hop"
assert_file_contains "${ROOT_DIR}/.github/workflows/rollout-hop.yml" "run_canary"
assert_file_contains "${ROOT_DIR}/.github/workflows/deploy-devo.yml" ".github/workflows/rollout-hop.yml@"
assert_file_contains "${ROOT_DIR}/.github/workflows/promote-prod.yml" ".github/workflows/rollout-hop.yml@"
assert_file_contains "${ROOT_DIR}/.github/workflows/preview.yml" ".github/workflows/preview-stack.yml@"

printf 'PASS: generic workflow tests\n'
