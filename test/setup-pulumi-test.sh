#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HELPER_PATH="${ROOT_DIR}/.github/actions/setup-pulumi/setup.sh"
ACTION_PATH="${ROOT_DIR}/.github/actions/setup-pulumi/action.yml"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_log_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

assert_file_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

assert_file_not_contains() {
  local path="$1"
  local needle="$2"
  if grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to not contain: ${needle}"
  fi
}

temp_dir="$(mktemp -d)"
fake_bin="${temp_dir}/bin"
log_file="${temp_dir}/commands.log"
mkdir -p "${fake_bin}" "${temp_dir}/workdir"
touch "${log_file}"

cat >"${fake_bin}/pulumi" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'pulumi %s\n' "\$*" >>"${log_file}"
scenario="\${PULUMI_TEST_SCENARIO:-missing}"
if [[ "\$1 \$2" == "stack select" ]]; then
  if [[ "\${scenario}" == "missing" ]]; then
    exit 255
  fi
  exit 0
fi
if [[ "\$1 \$2" == "stack export" ]]; then
  if [[ "\${scenario}" == "match" ]]; then
    printf '%s\n' '{"deployment":{"secrets_providers":{"state":{"url":"awskms://alias/test-secrets?region=ap-northeast-1"}}}}'
    exit 0
  fi
  if [[ "\${scenario}" == "mismatch" ]]; then
    printf '%s\n' '{"deployment":{"secrets_providers":{"state":{"url":"awskms://alias/other?region=us-west-2"}}}}'
    exit 0
  fi
fi
exit 0
EOF
chmod +x "${fake_bin}/pulumi"

if PATH="${fake_bin}:$PATH" PULUMI_TEST_SCENARIO=missing "${HELPER_PATH}" \
  --pulumi-backend-url "s3://test-state" \
  --pulumi-stack "devo" \
  --pulumi-secrets-provider "awskms://alias/test-secrets?region=ap-northeast-1" \
  --working-directory "${temp_dir}/workdir" >"${temp_dir}/missing.out" 2>&1; then
  :
else
  rm -rf "${temp_dir}"
  fail "expected helper to initialize a missing stack"
fi

assert_log_contains "${log_file}" "pulumi login s3://test-state"
assert_log_contains "${log_file}" "pulumi stack select devo"
assert_log_contains "${log_file}" "pulumi stack init devo --secrets-provider awskms://alias/test-secrets?region=ap-northeast-1"

: >"${log_file}"
if PATH="${fake_bin}:$PATH" PULUMI_TEST_SCENARIO=match "${HELPER_PATH}" \
  --pulumi-backend-url "s3://test-state" \
  --pulumi-stack "devo" \
  --pulumi-secrets-provider "awskms://alias/test-secrets?region=ap-northeast-1" \
  --working-directory "${temp_dir}/workdir" >"${temp_dir}/match.out" 2>&1; then
  :
else
  rm -rf "${temp_dir}"
  fail "expected helper to accept an existing stack with a matching secrets provider"
fi

assert_log_contains "${log_file}" "pulumi stack export --stack devo"

: >"${log_file}"
if PATH="${fake_bin}:$PATH" PULUMI_TEST_SCENARIO=mismatch "${HELPER_PATH}" \
  --pulumi-backend-url "s3://test-state" \
  --pulumi-stack "devo" \
  --pulumi-secrets-provider "awskms://alias/test-secrets?region=ap-northeast-1" \
  --working-directory "${temp_dir}/workdir" >"${temp_dir}/mismatch.out" 2>&1; then
  rm -rf "${temp_dir}"
  fail "expected helper to reject an existing stack with a mismatched secrets provider"
fi

assert_file_contains "${temp_dir}/mismatch.out" "secrets provider mismatch"
assert_file_contains "${ACTION_PATH}" "pulumi-secrets-provider"
assert_file_not_contains "${ACTION_PATH}" "command: version"
assert_file_not_contains "${ACTION_PATH}" 'working-directory: ${{ inputs.working-directory }}'
assert_file_contains "${ROOT_DIR}/.github/workflows/preview.yml" "pulumi_secrets_provider"
assert_file_contains "${ROOT_DIR}/.github/workflows/deploy-devo.yml" "pulumi_secrets_provider"
assert_file_contains "${ROOT_DIR}/.github/workflows/promote-prod.yml" "pulumi_secrets_provider"

rm -rf "${temp_dir}"
printf 'PASS: setup-pulumi tests\n'
