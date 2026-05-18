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

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT
fake_bin="${temp_dir}/bin"
log_file="${temp_dir}/commands.log"
release_dir="${temp_dir}/release"
mkdir -p "${fake_bin}" "${release_dir}"
touch "${log_file}"

assert_file_contains "${ACTION_PATH}" "release-dir"
assert_file_contains "${ACTION_PATH}" "manifest-path"
assert_file_contains "${ACTION_PATH}" "pages-project"
assert_file_contains "${ACTION_PATH}" "cloudflare-account-id"
assert_file_contains "${ACTION_PATH}" "runtime-config-path"
assert_file_contains "${ACTION_PATH}" "artifact-name"
assert_file_contains "${SCRIPT_PATH}" "wrangler pages deploy"
assert_file_contains "${SCRIPT_PATH}" "ltbase-controlplane.config.json"
assert_file_contains "${SCRIPT_PATH}" "UI artifact manifest entry not found"

cat >"${release_dir}/manifest.json" <<'EOF'
{
  "release_id": "v1.2.3",
  "artifacts": [
    {
      "name": "controlplane-ui",
      "file": "ltbase-controlplane-ui.tar.gz",
      "sha256": "dummy"
    }
  ]
}
EOF

printf '{"stacks":[]}' >"${temp_dir}/ltbase-controlplane.config.json"
printf 'placeholder' >"${release_dir}/ltbase-controlplane-ui.tar.gz"

cat >"${fake_bin}/tar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'tar %s\n' "$*" >>"${COMMAND_LOG}"
dest=""
args=("$@")
for i in "${!args[@]}"; do
  if [[ "${args[$i]}" == "-C" && -n "${args[$((i + 1))]:-}" ]]; then
    dest="${args[$((i + 1))]}"
  fi
done
mkdir -p "${dest}"
printf '<html>ok</html>' >"${dest}/index.html"
EOF
chmod +x "${fake_bin}/tar"

cat >"${fake_bin}/wrangler" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'wrangler %s\n' "$*" >>"${COMMAND_LOG}"
EOF
chmod +x "${fake_bin}/wrangler"

PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
  --release-dir "${release_dir}" \
  --manifest-path "${release_dir}/manifest.json" \
  --pages-project customer-ltbase-controlplane-ui \
  --cloudflare-account-id cf-account-123 \
  --runtime-config-path "${temp_dir}/ltbase-controlplane.config.json" \
  --artifact-name controlplane-ui

assert_log_contains "${log_file}" "tar -xzf ${release_dir}/ltbase-controlplane-ui.tar.gz"
assert_log_contains "${log_file}" "wrangler pages deploy"
assert_log_contains "${log_file}" "--project-name customer-ltbase-controlplane-ui"
assert_file_contains "${temp_dir}/site/ltbase-controlplane.config.json" '{"stacks":[]}'

if PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" "${SCRIPT_PATH}" \
  --release-dir "${release_dir}" \
  --manifest-path "${release_dir}/manifest.json" \
  --pages-project customer-ltbase-controlplane-ui \
  --cloudflare-account-id cf-account-123 \
  --runtime-config-path "${temp_dir}/ltbase-controlplane.config.json" \
  --artifact-name missing-ui >"${temp_dir}/missing.log" 2>&1; then
  fail "expected missing UI artifact lookup to fail"
fi

assert_log_contains "${temp_dir}/missing.log" "UI artifact manifest entry not found"

printf 'PASS: deploy controlplane ui tests\n'
