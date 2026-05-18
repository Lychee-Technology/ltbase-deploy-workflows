#!/usr/bin/env bash

set -euo pipefail

RELEASE_DIR=""
MANIFEST_PATH=""
PAGES_PROJECT=""
CLOUDFLARE_ACCOUNT_ID_INPUT=""
RUNTIME_CONFIG_PATH=""
ARTIFACT_NAME="controlplane-ui"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-dir)
      RELEASE_DIR="$2"
      shift 2
      ;;
    --manifest-path)
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --pages-project)
      PAGES_PROJECT="$2"
      shift 2
      ;;
    --cloudflare-account-id)
      CLOUDFLARE_ACCOUNT_ID_INPUT="$2"
      shift 2
      ;;
    --runtime-config-path)
      RUNTIME_CONFIG_PATH="$2"
      shift 2
      ;;
    --artifact-name)
      ARTIFACT_NAME="$2"
      shift 2
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

for name in RELEASE_DIR MANIFEST_PATH PAGES_PROJECT CLOUDFLARE_ACCOUNT_ID_INPUT RUNTIME_CONFIG_PATH ARTIFACT_NAME; do
  if [[ -z "${!name}" ]]; then
    printf '%s is required\n' "${name}" >&2
    exit 1
  fi
done

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  printf 'manifest not found: %s\n' "${MANIFEST_PATH}" >&2
  exit 1
fi

if [[ ! -f "${RUNTIME_CONFIG_PATH}" ]]; then
  printf 'runtime config not found: %s\n' "${RUNTIME_CONFIG_PATH}" >&2
  exit 1
fi

artifact_file="$(jq -r --arg name "${ARTIFACT_NAME}" '.artifacts[]? | select(.name == $name) | .file' "${MANIFEST_PATH}")"
if [[ -z "${artifact_file}" || "${artifact_file}" == "null" ]]; then
  printf 'UI artifact manifest entry not found for name: %s\n' "${ARTIFACT_NAME}" >&2
  exit 1
fi

artifact_path="${RELEASE_DIR}/${artifact_file}"
if [[ ! -f "${artifact_path}" ]]; then
  printf 'UI artifact file not found: %s\n' "${artifact_path}" >&2
  exit 1
fi

site_dir="$(dirname "${RELEASE_DIR}")/site"
rm -rf "${site_dir}"
mkdir -p "${site_dir}"

tar -xzf "${artifact_path}" -C "${site_dir}"
cp "${RUNTIME_CONFIG_PATH}" "${site_dir}/ltbase-controlplane.config.json"

wrangler pages deploy "${site_dir}" --project-name "${PAGES_PROJECT}"
