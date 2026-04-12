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
assert_file_contains "${ACTION_PATH}" "binaries-repo"
assert_file_contains "${ACTION_PATH}" "commit"
assert_file_contains "${ACTION_PATH}" "working-directory"
assert_file_contains "${ACTION_PATH}" "token"

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT
fake_bin="${temp_dir}/bin"
log_file="${temp_dir}/commands.log"
mkdir -p "${fake_bin}" "${temp_dir}/release-assets" "${temp_dir}/blueprint/infra"
touch "${log_file}"

mkdir -p "${temp_dir}/tarball-amd64"
printf '#!/usr/bin/env bash\nexit 0\n' >"${temp_dir}/tarball-amd64/ltbase-infra"
chmod +x "${temp_dir}/tarball-amd64/ltbase-infra"
(cd "${temp_dir}/tarball-amd64" && tar -czf "${temp_dir}/release-assets/ltbase-blueprint-binaries-linux-amd64.tar.gz" ltbase-infra)
amd64_sha="$(shasum -a 256 "${temp_dir}/release-assets/ltbase-blueprint-binaries-linux-amd64.tar.gz" | awk '{print $1}')"
cat >"${temp_dir}/release-assets/manifest.json" <<EOF
{"source_repository":"example/repo","source_commit":"abc123","source_ref":"main","release_tag":"r20260411T000000Z","artifacts":[{"file":"ltbase-blueprint-binaries-linux-amd64.tar.gz","arch":"linux-amd64","sha256":"${amd64_sha}","go_version":"go1.26.0","built_at":"2026-04-11T00:00:00Z"},{"file":"ltbase-blueprint-binaries-linux-arm64.tar.gz","arch":"linux-arm64","sha256":"mismatch","go_version":"go1.26.0","built_at":"2026-04-11T00:00:00Z"}]}
EOF

cat >"${fake_bin}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >>"${COMMAND_LOG}"
if [[ "$*" == *"repos/example/binaries/releases?per_page=20"* ]]; then
  printf '%s\n' '[{"tag_name":"r20260411T000000Z","assets":[{"name":"manifest.json","browser_download_url":"https://example.test/manifest.json"},{"name":"ltbase-blueprint-binaries-linux-amd64.tar.gz","browser_download_url":"https://example.test/ltbase-blueprint-binaries-linux-amd64.tar.gz"},{"name":"ltbase-blueprint-binaries-linux-arm64.tar.gz","browser_download_url":"https://example.test/ltbase-blueprint-binaries-linux-arm64.tar.gz"}]}]'
else
  printf '%s\n' '[]'
fi
EOF
chmod +x "${fake_bin}/gh"

cat >"${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >>"${COMMAND_LOG}"
output=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done
case "${url}" in
  *manifest.json)
    cp "${ASSET_ROOT}/manifest.json" "${output}"
    ;;
  *ltbase-blueprint-binaries-linux-amd64.tar.gz)
    cp "${ASSET_ROOT}/ltbase-blueprint-binaries-linux-amd64.tar.gz" "${output}"
    ;;
  *ltbase-blueprint-binaries-linux-arm64.tar.gz)
    cp "${ASSET_ROOT}/ltbase-blueprint-binaries-linux-arm64.tar.gz" "${output}"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x "${fake_bin}/curl"

cat >"${fake_bin}/uname" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "-m" ]]; then
  printf 'x86_64\n'
else
  /usr/bin/uname "$@"
fi
EOF
chmod +x "${fake_bin}/uname"

gout="${temp_dir}/github-output.txt"
PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" ASSET_ROOT="${temp_dir}/release-assets" GH_TOKEN="test-token" GITHUB_OUTPUT="${gout}" \
  "${SCRIPT_PATH}" --repository example/repo --binaries-repo example/binaries --commit abc123 --working-directory "${temp_dir}/blueprint/infra"

assert_log_contains "${log_file}" "gh api repos/example/binaries/releases?per_page=20"
assert_log_contains "${log_file}" "curl -fsSL -H Authorization: Bearer test-token"
assert_file_contains "${gout}" "installed=true"
if [[ ! -x "${temp_dir}/blueprint/infra/.pulumi/bin/ltbase-infra" ]]; then
  fail "expected installer to place the binary in the Pulumi binary directory"
fi

: >"${log_file}"
printf '%s\n' >"${gout}"
rm -rf "${temp_dir}/blueprint/infra/.pulumi"
PATH="${fake_bin}:$PATH" COMMAND_LOG="${log_file}" ASSET_ROOT="${temp_dir}/release-assets" GH_TOKEN="test-token" GITHUB_OUTPUT="${gout}" \
  "${SCRIPT_PATH}" --repository example/repo --binaries-repo example/binaries --commit def456 --working-directory "${temp_dir}/blueprint/infra"

assert_file_contains "${gout}" "installed=false"
if [[ -e "${temp_dir}/blueprint/infra/.pulumi/bin/ltbase-infra" ]]; then
  fail "expected no binary install when no matching artifact exists"
fi

printf 'PASS: install prebuilt infra binary tests\n'
