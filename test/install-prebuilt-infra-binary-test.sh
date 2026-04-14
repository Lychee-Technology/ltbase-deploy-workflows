#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTION_PATH="${ROOT_DIR}/.github/actions/install-prebuilt-infra-binary/action.yml"
SCRIPT_PATH="${ROOT_DIR}/.github/actions/install-prebuilt-infra-binary/install.sh"

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

assert_file_not_contains() {
  local path="$1"
  local needle="$2"
  if [[ ! -f "${path}" ]]; then
    fail "missing file: ${path}"
  fi
  if grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to not contain: ${needle}"
  fi
}

assert_file_contains "${ACTION_PATH}" "binaries-repo"
assert_file_contains "${ACTION_PATH}" "provenance-path"
assert_file_contains "${ACTION_PATH}" "working-directory"
assert_file_contains "${ACTION_PATH}" "token"
assert_file_not_contains "${ACTION_PATH}" "repository:"
assert_file_not_contains "${ACTION_PATH}" "commit:"

assert_file_contains "${SCRIPT_PATH}" "PROVENANCE_PATH"
assert_file_contains "${SCRIPT_PATH}" "template_repository"
assert_file_contains "${SCRIPT_PATH}" "template_commit"
assert_file_contains "${SCRIPT_PATH}" "build_fingerprint"
assert_file_contains "${SCRIPT_PATH}" "Template provenance file missing; falling back to source build"
assert_file_contains "${SCRIPT_PATH}" "Template provenance file malformed; falling back to source build"
assert_file_contains "${SCRIPT_PATH}" "for template %s@%s (%s, %s)"
assert_file_not_contains "${SCRIPT_PATH}" "REPOSITORY=\"\""
assert_file_not_contains "${SCRIPT_PATH}" "COMMIT=\"\""

printf 'PASS: install prebuilt infra binary tests\n'
