#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/.github/actions/deploy-controlplane-ui/aggregate-runtime-config.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  if [[ "${expected}" != "${actual}" ]]; then
    fail "expected ${expected}, got ${actual}"
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

assert_log_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT

fake_bin="${temp_dir}/bin"
mkdir -p "${fake_bin}" "${temp_dir}/infra"

cat >"${fake_bin}/pulumi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" != "stack" || "$2" != "output" || "$3" != "--json" || "$4" != "--stack" ]]; then
  printf 'unexpected pulumi args: %s\n' "$*" >&2
  exit 1
fi

stack="$5"
output_path="${PULUMI_OUTPUT_DIR}/${stack}.json"
if [[ ! -f "${output_path}" ]]; then
  printf 'missing fake pulumi output for %s\n' "${stack}" >&2
  exit 1
fi

cat "${output_path}"
EOF
chmod +x "${fake_bin}/pulumi"

cat >"${temp_dir}/infra/devo.json" <<'EOF'
{}
EOF

if PATH="${fake_bin}:$PATH" PULUMI_OUTPUT_DIR="${temp_dir}/infra" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/infra" \
  --target-stack devo \
  --candidate-stacks devo,prod \
  --controlplane-ui-domain ui.example.com >"${temp_dir}/missing-target.log" 2>&1; then
  fail "expected aggregation to fail when target stack config is missing"
fi

assert_log_contains "${temp_dir}/missing-target.log" "missing controlplaneUiStackConfig for target stack devo"

if PATH="${fake_bin}:$PATH" PULUMI_OUTPUT_DIR="${temp_dir}/infra" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/infra" \
  --target-stack devo \
  --candidate-stacks prod \
  --controlplane-ui-domain ui.example.com >"${temp_dir}/omitted-target.log" 2>&1; then
  fail "expected aggregation to fail when candidate stacks omit the target stack"
fi

assert_log_contains "${temp_dir}/omitted-target.log" "candidate stacks must include target stack devo"

cat >"${temp_dir}/infra/devo.json" <<'EOF'
{
  "controlplaneUiStackConfig": "{\"key\":\"devo\",\"label\":\"Devo\",\"projectId\":\"p1\",\"authBaseUrl\":\"https://auth.devo\",\"controlPlaneBaseUrl\":\"https://cp.devo\",\"apiBaseUrl\":\"https://api.devo\",\"oidcClientId\":\"oidc-devo\",\"authProviders\":[{\"type\":\"firebase\",\"name\":\"firebase\",\"label\":\"Firebase\",\"firebaseProjectId\":\"fb-devo\",\"firebaseApiKey\":\"key-devo\"}]}"
}
EOF

cat >"${temp_dir}/infra/prod.json" <<'EOF'
{}
EOF

actual_json="$(PATH="${fake_bin}:$PATH" PULUMI_OUTPUT_DIR="${temp_dir}/infra" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/infra" \
  --target-stack devo \
  --candidate-stacks devo,prod \
  --controlplane-ui-domain ui.example.com 2>"${temp_dir}/skip.log")"

assert_log_contains "${temp_dir}/skip.log" "skipping stack prod because controlplaneUiStackConfig is missing"
expected_skip_json='{"stacks":[{"key":"devo","label":"Devo","projectId":"p1","authBaseUrl":"https://auth.devo","controlPlaneBaseUrl":"https://cp.devo","apiBaseUrl":"https://api.devo","oidcClientId":"oidc-devo","authProviders":[{"type":"firebase","name":"firebase","label":"Firebase","firebaseProjectId":"fb-devo","firebaseApiKey":"key-devo"}],"redirectUri":"https://ui.example.com/auth/callback"}]}'
assert_equals "${expected_skip_json}" "${actual_json}"

cat >"${temp_dir}/infra/prod.json" <<'EOF'
{
  "controlplaneUiStackConfig": "{\"key\":\"prod\",\"label\":\"Prod\",\"projectId\":\"p2\",\"authBaseUrl\":\"https://auth.prod\",\"controlPlaneBaseUrl\":\"https://cp.prod\",\"apiBaseUrl\":\"https://api.prod\",\"oidcClientId\":\"oidc-prod\",\"authProviders\":[{\"type\":\"supabase\",\"name\":\"supabase\",\"label\":\"Supabase\",\"supabaseUrl\":\"https://supabase.prod\",\"supabaseAnonKey\":\"anon-prod\"}]}"
}
EOF

actual_json="$(PATH="${fake_bin}:$PATH" PULUMI_OUTPUT_DIR="${temp_dir}/infra" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/infra" \
  --target-stack devo \
  --candidate-stacks devo,prod \
  --controlplane-ui-domain ui.example.com)"

expected_json='{"stacks":[{"key":"devo","label":"Devo","projectId":"p1","authBaseUrl":"https://auth.devo","controlPlaneBaseUrl":"https://cp.devo","apiBaseUrl":"https://api.devo","oidcClientId":"oidc-devo","authProviders":[{"type":"firebase","name":"firebase","label":"Firebase","firebaseProjectId":"fb-devo","firebaseApiKey":"key-devo"}],"redirectUri":"https://ui.example.com/auth/callback"},{"key":"prod","label":"Prod","projectId":"p2","authBaseUrl":"https://auth.prod","controlPlaneBaseUrl":"https://cp.prod","apiBaseUrl":"https://api.prod","oidcClientId":"oidc-prod","authProviders":[{"type":"supabase","name":"supabase","label":"Supabase","supabaseUrl":"https://supabase.prod","supabaseAnonKey":"anon-prod"}],"redirectUri":"https://ui.example.com/auth/callback"}]}'
assert_equals "${expected_json}" "${actual_json}"

cat >"${temp_dir}/infra/prod.json" <<'EOF'
{
  "controlplaneUiStackConfig": "{\"key\":\"prod\"}"
}
EOF

actual_json="$(PATH="${fake_bin}:$PATH" PULUMI_OUTPUT_DIR="${temp_dir}/infra" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/infra" \
  --target-stack devo \
  --candidate-stacks devo,prod \
  --controlplane-ui-domain ui.example.com 2>"${temp_dir}/invalid-nontarget.log")"

assert_log_contains "${temp_dir}/invalid-nontarget.log" "skipping stack prod because controlplaneUiStackConfig is invalid"
assert_equals "${expected_skip_json}" "${actual_json}"

cat >"${temp_dir}/infra/devo.json" <<'EOF'
{
  "controlplaneUiStackConfig": "{\"key\":\"devo\"}"
}
EOF

if PATH="${fake_bin}:$PATH" PULUMI_OUTPUT_DIR="${temp_dir}/infra" "${SCRIPT_PATH}" \
  --working-directory "${temp_dir}/infra" \
  --target-stack devo \
  --candidate-stacks devo,prod \
  --controlplane-ui-domain ui.example.com >"${temp_dir}/invalid-target.log" 2>&1; then
  fail "expected aggregation to fail when target stack config is invalid"
fi

assert_log_contains "${temp_dir}/invalid-target.log" "invalid controlplaneUiStackConfig for target stack devo"
assert_file_contains "${SCRIPT_PATH}" "controlplaneUiStackConfig"
assert_file_contains "${SCRIPT_PATH}" "redirectUri"

printf 'PASS: aggregate-controlplane-ui-config tests\n'
