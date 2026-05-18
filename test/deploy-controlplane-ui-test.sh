#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTION_PATH="${ROOT_DIR}/.github/actions/deploy-controlplane-ui/action.yml"
SCRIPT_PATH="${ROOT_DIR}/.github/actions/deploy-controlplane-ui/deploy.sh"

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
  if ! grep -Fq -- "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

assert_log_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq -- "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

assert_file_equals() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(<"${path}")"
  if [[ "${actual}" != "${expected}" ]]; then
    fail "expected ${path} to equal ${expected}, got ${actual}"
  fi
}

run_expect_fail() {
  local expected="$1"
  shift
  local log_file="$1"
  shift

  if "$@" >"${log_file}" 2>&1; then
    fail "expected command to fail: $*"
  fi

  assert_log_contains "${log_file}" "${expected}"
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT

fake_bin="${temp_dir}/bin"
log_file="${temp_dir}/commands.log"
mkdir -p "${fake_bin}"
touch "${log_file}"

manifest_path="${temp_dir}/manifest.json"

create_tarball() {
  local tarball_path="$1"
  local content_root="${temp_dir}/artifact-content"
  rm -rf "${content_root}"
  mkdir -p "${content_root}/dist"
  printf '<html>ok</html>\n' >"${content_root}/dist/index.html"
  tar -czf "${tarball_path}" -C "${content_root}" .
}

cat >"${fake_bin}/wrangler" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'wrangler %s\n' "$*" >>"${COMMAND_LOG}"
EOF
chmod +x "${fake_bin}/wrangler"

create_manifest() {
  local artifact_file="$1"
  cat >"${manifest_path}" <<EOF
{
  "release_id": "v1.2.3",
  "artifacts": [
    {
      "name": "controlplane-ui",
      "file": "${artifact_file}",
      "sha256": "unused"
    }
  ]
}
EOF
}

runtime_config='{"stacks":[{"key":"devo","redirectUri":"https://ui.example.com/auth/callback"}]}'

run_expect_fail "manifest.json not found" "${temp_dir}/missing-manifest.log" \
  env PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
    --manifest-path "${temp_dir}/does-not-exist.json" \
    --runtime-config-json "${runtime_config}" \
    --cloudflare-pages-project "cp-ui"

cat >"${manifest_path}" <<'EOF'
{"release_id":"v1.2.3","artifacts":[]}
EOF
run_expect_fail "control plane UI artifact entry not found in manifest" "${temp_dir}/missing-artifact.log" \
  env PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
    --manifest-path "${manifest_path}" \
    --runtime-config-json "${runtime_config}" \
    --cloudflare-pages-project "cp-ui"

create_manifest "controlplane-ui.tar.gz"
run_expect_fail "control plane UI artifact file not found" "${temp_dir}/missing-file.log" \
  env PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
    --manifest-path "${manifest_path}" \
    --runtime-config-json "${runtime_config}" \
    --cloudflare-pages-project "cp-ui"

create_tarball "${temp_dir}/controlplane-ui.tar.gz"
run_expect_fail "runtime config JSON must be an object with a stacks array" "${temp_dir}/invalid-json.log" \
  env PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
    --manifest-path "${manifest_path}" \
    --runtime-config-json '{"stacks":"bad"}' \
    --cloudflare-pages-project "cp-ui"

create_tarball "${temp_dir}/controlplane-ui.tar.gz"

: >"${log_file}"
deploy_root="${temp_dir}/deploy-root"
env PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
  --manifest-path "${manifest_path}" \
  --runtime-config-json "${runtime_config}" \
  --cloudflare-pages-project "cp-ui" \
  --pages-branch "main" \
  --deploy-root "${deploy_root}"

assert_log_contains "${log_file}" "wrangler pages deploy ${deploy_root} --project-name cp-ui --branch main"
assert_file_equals "${deploy_root}/ltbase-controlplane.config.json" "${runtime_config}"
assert_file_contains "${ACTION_PATH}" "runtime-config-json"
assert_file_contains "${ACTION_PATH}" "cloudflare-pages-project"
assert_file_contains "${ACTION_PATH}" "pages-branch"

printf 'PASS: deploy-controlplane-ui tests\n'
