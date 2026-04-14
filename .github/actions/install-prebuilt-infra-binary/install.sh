#!/usr/bin/env bash

set -euo pipefail

BINARIES_REPO=""
PROVENANCE_PATH=""
WORKING_DIRECTORY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --binaries-repo)
      BINARIES_REPO="$2"
      shift 2
      ;;
    --provenance-path)
      PROVENANCE_PATH="$2"
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

for name in BINARIES_REPO PROVENANCE_PATH WORKING_DIRECTORY GH_TOKEN GITHUB_OUTPUT; do
  if [[ -z "${!name:-}" ]]; then
    echo "${name} is required" >&2
    exit 1
  fi
done

if [[ ! -f "${PROVENANCE_PATH}" ]]; then
  printf 'Template provenance file missing; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

TEMPLATE_REPOSITORY="$(jq -r '.template_repository // empty' "${PROVENANCE_PATH}")"
TEMPLATE_COMMIT="$(jq -r '.template_commit // empty' "${PROVENANCE_PATH}")"
BUILD_FINGERPRINT="$(jq -r '.build_fingerprint // empty' "${PROVENANCE_PATH}")"

if [[ -z "${TEMPLATE_REPOSITORY}" || -z "${TEMPLATE_COMMIT}" || -z "${BUILD_FINGERPRINT}" ]]; then
  printf 'Template provenance file malformed; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

case "$(uname -m)" in
  x86_64|amd64)
    TARGET_ARCH="linux-amd64"
    ;;
  arm64|aarch64)
    TARGET_ARCH="linux-arm64"
    ;;
  *)
    printf 'Unsupported runner architecture; falling back to source build\n'
    printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
    exit 0
    ;;
esac

printf 'Looking for prebuilt infra binary releases in %s for template %s@%s (%s, %s)\n' "${BINARIES_REPO}" "${TEMPLATE_REPOSITORY}" "${TEMPLATE_COMMIT}" "${BUILD_FINGERPRINT}" "${TARGET_ARCH}"

release_json="$(gh api "repos/${BINARIES_REPO}/releases?per_page=20")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

matching_asset=""
matching_sha=""
matching_manifest=""
matching_url=""
release_count="$(printf '%s' "${release_json}" | jq 'length')"

for ((idx=0; idx<release_count; idx++)); do
  manifest_url="$(printf '%s' "${release_json}" | jq -r ".[$idx].assets[]? | select(.name == \"manifest.json\") | .browser_download_url" | head -n 1)"
  if [[ -z "${manifest_url}" ]]; then
    continue
  fi

  curl -fsSL -H "Authorization: Bearer ${GH_TOKEN}" "${manifest_url}" -o "${tmp_dir}/manifest-${idx}.json"

  manifest_repo="$(jq -r '.source_repository // empty' "${tmp_dir}/manifest-${idx}.json")"
  manifest_commit="$(jq -r '.source_commit // empty' "${tmp_dir}/manifest-${idx}.json")"
  manifest_fingerprint="$(jq -r '.build_fingerprint // empty' "${tmp_dir}/manifest-${idx}.json")"
  if [[ "${manifest_repo}" != "${TEMPLATE_REPOSITORY}" || "${manifest_commit}" != "${TEMPLATE_COMMIT}" || "${manifest_fingerprint}" != "${BUILD_FINGERPRINT}" ]]; then
    continue
  fi

  matching_asset="$(jq -r --arg arch "${TARGET_ARCH}" '.artifacts[]? | select(.arch == $arch) | .file' "${tmp_dir}/manifest-${idx}.json" | head -n 1)"
  matching_sha="$(jq -r --arg arch "${TARGET_ARCH}" '.artifacts[]? | select(.arch == $arch) | .sha256' "${tmp_dir}/manifest-${idx}.json" | head -n 1)"
  if [[ -z "${matching_asset}" || -z "${matching_sha}" ]]; then
    continue
  fi

  matching_url="$(printf '%s' "${release_json}" | jq -r --arg asset "${matching_asset}" ".[$idx].assets[]? | select(.name == \$asset) | .browser_download_url" | head -n 1)"
  if [[ -z "${matching_url}" ]]; then
    continue
  fi

  matching_manifest="${tmp_dir}/manifest-${idx}.json"
  break
done

if [[ -z "${matching_url}" || -z "${matching_manifest}" ]]; then
  printf 'No matching prebuilt infra binary found; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

curl -fsSL -H "Authorization: Bearer ${GH_TOKEN}" "${matching_url}" -o "${tmp_dir}/binary.tar.gz"
binary_sha="$(shasum -a 256 "${tmp_dir}/binary.tar.gz" | awk '{print $1}')"

if [[ "${matching_sha}" != "${binary_sha}" ]]; then
  printf 'Artifact validation failed; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

mkdir -p "${tmp_dir}/artifact"
tar -xzf "${tmp_dir}/binary.tar.gz" -C "${tmp_dir}/artifact"

binary_path="$(find "${tmp_dir}/artifact" -type f -name ltbase-infra | head -n 1)"

if [[ ! -f "${binary_path}" ]]; then
  printf 'Artifact missing expected files; falling back to source build\n'
  printf 'installed=false\n' >> "${GITHUB_OUTPUT}"
  exit 0
fi

mkdir -p "${WORKING_DIRECTORY}/.pulumi/bin"
install -m 0755 "${binary_path}" "${WORKING_DIRECTORY}/.pulumi/bin/ltbase-infra"

printf 'installed=true\n' >> "${GITHUB_OUTPUT}"
printf 'Installed prebuilt infra binary to %s/.pulumi/bin/ltbase-infra\n' "${WORKING_DIRECTORY}"
