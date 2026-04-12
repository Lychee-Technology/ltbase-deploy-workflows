#!/usr/bin/env bash

set -euo pipefail

REPOSITORY=""
COMMIT=""
WORKING_DIRECTORY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository)
      REPOSITORY="$2"
      shift 2
      ;;
    --commit)
      COMMIT="$2"
      shift 2
      ;;
    --working-directory)
      WORKING_DIRECTORY="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for name in REPOSITORY COMMIT WORKING_DIRECTORY GH_TOKEN GITHUB_OUTPUT; do
  if [[ -z "${!name:-}" ]]; then
    echo "${name} is required" >&2
    exit 1
  fi
done

artifact_name="infra-binary-linux-arm64-${COMMIT}"
printf 'Looking for prebuilt infra binary artifact %s in %s\n' "${artifact_name}" "${REPOSITORY}"

artifact_json="$(gh api "repos/${REPOSITORY}/actions/artifacts?name=${artifact_name}")"
download_url="$(printf '%s' "${artifact_json}" | jq -r '.artifacts[0].archive_download_url // empty')"

if [[ -z "${download_url}" ]]; then
  printf 'No matching prebuilt infra binary found; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

curl -fsSL -H "Authorization: Bearer ${GH_TOKEN}" "${download_url}" -o "${tmp_dir}/artifact.zip"
unzip -q "${tmp_dir}/artifact.zip" -d "${tmp_dir}/artifact"

manifest_path="$(find "${tmp_dir}/artifact" -type f -name manifest.json | head -n 1)"
binary_path="$(find "${tmp_dir}/artifact" -type f -name ltbase-infra | head -n 1)"

if [[ ! -f "${manifest_path}" || ! -f "${binary_path}" ]]; then
  printf 'Artifact missing expected files; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

manifest_commit="$(jq -r '.source_commit // empty' "${manifest_path}")"
manifest_os="$(jq -r '.os // empty' "${manifest_path}")"
manifest_arch="$(jq -r '.arch // empty' "${manifest_path}")"
manifest_sha="$(jq -r '.sha256 // empty' "${manifest_path}")"
binary_sha="$(shasum -a 256 "${binary_path}" | awk '{print $1}')"

if [[ "${manifest_commit}" != "${COMMIT}" || "${manifest_os}" != "linux" || "${manifest_arch}" != "arm64" || "${manifest_sha}" != "${binary_sha}" ]]; then
  printf 'Artifact validation failed; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

mkdir -p "${WORKING_DIRECTORY}/.pulumi/bin"
install -m 0755 "${binary_path}" "${WORKING_DIRECTORY}/.pulumi/bin/ltbase-infra"

printf 'installed=true\n' >> "${GITHUB_OUTPUT}"
printf 'Installed prebuilt infra binary to %s/.pulumi/bin/ltbase-infra\n' "${WORKING_DIRECTORY}"
