#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTION_PATH="${ROOT_DIR}/.github/actions/reconcile-project-info/action.yml"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  if [[ ! -f "${path}" ]]; then
    fail "missing file: ${path}"
  fi
  if ! grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

assert_contains "${ACTION_PATH}" "name: Reconcile Project Info"
assert_contains "${ACTION_PATH}" "stack:"
assert_contains "${ACTION_PATH}" "aws-region:"
assert_contains "${ACTION_PATH}" "working-directory:"
assert_contains "${ACTION_PATH}" "pulumi stack output projectId"
assert_contains "${ACTION_PATH}" "pulumi stack output apiId"
assert_contains "${ACTION_PATH}" "pulumi stack output apiBaseUrl"
assert_contains "${ACTION_PATH}" "pulumi stack output tableName"
assert_contains "${ACTION_PATH}" "aws sts get-caller-identity --query Account --output text"
assert_contains "${ACTION_PATH}" "aws dynamodb put-item"
assert_contains "${ACTION_PATH}" '"PK":{"S":"project#${project_id}"}'
assert_contains "${ACTION_PATH}" '"SK":{"S":"info"}'
assert_contains "${ACTION_PATH}" '"api_id":{"S":"${api_id}"}'
assert_contains "${ACTION_PATH}" '"api_base_url":{"S":"${api_base_url}"}'

printf 'PASS: reconcile-project-info action tests\n'
