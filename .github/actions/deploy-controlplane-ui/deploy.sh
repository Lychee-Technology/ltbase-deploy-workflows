#!/usr/bin/env bash

set -euo pipefail

MANIFEST_PATH=""
RUNTIME_CONFIG_JSON=""
CLOUDFLARE_PAGES_PROJECT=""
PAGES_BRANCH=""
ARTIFACT_NAME="controlplane-ui"
DEPLOY_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest-path)
      MANIFEST_PATH="$2"
      shift 2
      ;;
    --runtime-config-json)
      RUNTIME_CONFIG_JSON="$2"
      shift 2
      ;;
    --cloudflare-pages-project)
      CLOUDFLARE_PAGES_PROJECT="$2"
      shift 2
      ;;
    --pages-branch)
      PAGES_BRANCH="$2"
      shift 2
      ;;
    --artifact-name)
      ARTIFACT_NAME="$2"
      shift 2
      ;;
    --deploy-root)
      DEPLOY_ROOT="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for name in RUNTIME_CONFIG_JSON CLOUDFLARE_PAGES_PROJECT ARTIFACT_NAME; do
  if [[ -z "${!name:-}" ]]; then
    echo "${name} is required" >&2
    exit 1
  fi
done

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "manifest.json not found: ${MANIFEST_PATH}" >&2
  exit 1
fi

if ! printf '%s' "${RUNTIME_CONFIG_JSON}" | jq -e 'type == "object" and (.stacks | type == "array")' >/dev/null; then
  echo "runtime config JSON must be an object with a stacks array" >&2
  exit 1
fi

artifact_file="$(jq -r --arg artifact_name "${ARTIFACT_NAME}" '.artifacts[]? | select(.name == $artifact_name) | .file' "${MANIFEST_PATH}" | head -n 1)"

if [[ -z "${artifact_file}" || "${artifact_file}" == "null" ]]; then
  echo "control plane UI artifact entry not found in manifest" >&2
  exit 1
fi

release_dir="$(dirname "${MANIFEST_PATH}")"
artifact_path="${release_dir}/${artifact_file}"

if [[ ! -f "${artifact_path}" ]]; then
  echo "control plane UI artifact file not found: ${artifact_path}" >&2
  exit 1
fi

if [[ -z "${DEPLOY_ROOT}" ]]; then
  DEPLOY_ROOT="$(mktemp -d)"
  cleanup_deploy_root=true
else
  cleanup_deploy_root=false
  rm -rf "${DEPLOY_ROOT}"
  mkdir -p "${DEPLOY_ROOT}"
fi

if [[ "${cleanup_deploy_root}" == true ]]; then
  trap 'rm -rf "${DEPLOY_ROOT}"' EXIT
fi

tar -xzf "${artifact_path}" -C "${DEPLOY_ROOT}"

pages_dir="${DEPLOY_ROOT}"

printf '%s' "${RUNTIME_CONFIG_JSON}" > "${pages_dir}/ltbase-controlplane.config.json"

if ! command -v wrangler >/dev/null 2>&1; then
  npm install --global wrangler >/dev/null
fi

deploy_args=(pages deploy "${pages_dir}" --project-name "${CLOUDFLARE_PAGES_PROJECT}")
if [[ -n "${PAGES_BRANCH}" ]]; then
  deploy_args+=(--branch "${PAGES_BRANCH}")
fi

wrangler "${deploy_args[@]}"
