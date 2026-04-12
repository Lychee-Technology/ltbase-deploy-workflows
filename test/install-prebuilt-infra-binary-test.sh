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

assert_log_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq "${needle}" "${path}"; then
    fail "expected ${path} to contain: ${needle}"
  fi
}

assert_file_contains "${ACTION_PATH}" "repository"
assert_file_contains "${ACTION_PATH}" "commit"
assert_file_contains "${ACTION_PATH}" "working-directory"
assert_file_contains "${ACTION_PATH}" "token"

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT
fake_bin="${temp_dir}/bin"
log_file="${temp_dir}/commands.log"
mkdir -p "${fake_bin}" "${temp_dir}/artifact/infra/.pulumi/bin" "${temp_dir}/blueprint/infra"
touch "${log_file}"

printf '#!/usr/bin/env bash\nexit 0\n' >"${temp_dir}/artifact/infra/.pulumi/bin/ltbase-infra"
chmod +x "${temp_dir}/artifact/infra/.pulumi/bin/ltbase-infra"
sha256="$(shasum -a 256 "${temp_dir}/artifact/infra/.pulumi/bin/ltbase-infra" | awk '{print $1}')"
cat >"${temp_dir}/artifact/infra/manifest.json" <<EOF
{"source_repository":"example/repo","source_commit":"abc123","source_ref":"main","project":"ltbase-infra","binary_name":"ltbase-infra","os":"linux","arch":"arm64","sha256":"${sha256}","go_version":"go1.26.0","built_at":"2026-04-11T00:00:00Z"}
EOF

(cd "${temp_dir}/artifact" && zip -qr "${temp_dir}/artifact.zip" infra)

cat >"${fake_bin}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >>"${COMMAND_LOG}"
if [[ "$*" == *"name=infra-binary-linux-arm64-abc123"* ]]; then
  printf '%s\n' '{"artifacts":[{"archive_download_url":"https://example.test/artifact.zip"}]}'
else
  printf '%s\n' '{"artifacts":[]}'
fi
EOF
chmod +x "${fake_bin}/gh"

cat >"${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"${COMMAND_LOG}"
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
cp "${ARTIFACT_ZIP}" "${output}"
EOF
chmod +x "${fake_bin}/curl"

gout="${temp_dir}/github-output.txt"
PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" ARTIFACT_ZIP="${temp_dir}/artifact.zip" GH_TOKEN="test-token" GITHUB_OUTPUT="${gout}" \
  "${SCRIPT_PATH}" --repository example/repo --commit abc123 --working-directory "${temp_dir}/blueprint/infra"

assert_log_contains "${log_file}" "gh api repos/example/repo/actions/artifacts?name=infra-binary-linux-arm64-abc123"
assert_log_contains "${log_file}" "curl -fsSL -H Authorization: Bearer test-token"
assert_file_contains "${gout}" "installed=true"
if [[ ! -x "${temp_dir}/blueprint/infra/.pulumi/bin/ltbase-infra" ]]; then
  fail "expected installer to place the binary in the Pulumi binary directory"
fi

: >"${log_file}"
printf '%s\n' >"${gout}"
rm -rf "${temp_dir}/blueprint/infra/.pulumi"
PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" ARTIFACT_ZIP="${temp_dir}/artifact.zip" GH_TOKEN="test-token" GITHUB_OUTPUT="${gout}" \
  "${SCRIPT_PATH}" --repository example/repo --commit def456 --working-directory "${temp_dir}/blueprint/infra"

assert_file_contains "${gout}" "installed=false"
if [[ -e "${temp_dir}/blueprint/infra/.pulumi/bin/ltbase-infra" ]]; then
  fail "expected no binary install when no matching artifact exists"
fi

printf 'PASS: install prebuilt infra binary tests\n'
