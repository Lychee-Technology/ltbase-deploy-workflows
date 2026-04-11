#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTION_PATH="${ROOT_DIR}/.github/actions/run-pulumi/action.yml"
SCRIPT_PATH="${ROOT_DIR}/.github/actions/run-pulumi/run.sh"

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
  if [[ ! -f "${path}" ]]; then
    fail "missing file: ${path}"
  fi
  if ! grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT
fake_bin="${temp_dir}/bin"
log_file="${temp_dir}/commands.log"
mkdir -p "${fake_bin}" "${temp_dir}/blueprint/infra/scripts"
touch "${log_file}"

cat >"${fake_bin}/pulumi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'pulumi %s\n' "$*" >>"${COMMAND_LOG}"
EOF
chmod +x "${fake_bin}/pulumi"

cat >"${temp_dir}/blueprint/infra/scripts/pulumi-wrapper.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'wrapper %s\n' "$*" >>"${COMMAND_LOG}"
EOF
chmod +x "${temp_dir}/blueprint/infra/scripts/pulumi-wrapper.sh"

PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/blueprint/infra" \
  --command preview \
  --stack devo \
  --prefer-wrapper true \
  --wrapper-path "${temp_dir}/blueprint/infra/scripts/pulumi-wrapper.sh"

assert_log_contains "${log_file}" "wrapper preview --stack devo --non-interactive --logtostderr --logflow -v=6"

: >"${log_file}"
PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/blueprint/infra" \
  --command up \
  --stack devo \
  --prefer-wrapper true \
  --wrapper-path "${temp_dir}/blueprint/infra/scripts/missing-wrapper.sh"

assert_log_contains "${log_file}" "pulumi up --stack devo --yes --non-interactive --logtostderr --logflow -v=6"

: >"${log_file}"
PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/blueprint/infra" \
  --command refresh \
  --stack prod \
  --prefer-wrapper false

assert_log_contains "${log_file}" "pulumi refresh --stack prod --yes --non-interactive"
assert_file_contains "${ACTION_PATH}" "prefer-wrapper"
assert_file_contains "${ACTION_PATH}" "wrapper-path"

printf 'PASS: run-pulumi tests\n'
