#!/usr/bin/env bash

set -euo pipefail

PULUMI_BACKEND_URL=""
PULUMI_STACK=""
PULUMI_SECRETS_PROVIDER=""
WORKING_DIRECTORY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pulumi-backend-url)
      PULUMI_BACKEND_URL="$2"
      shift 2
      ;;
    --pulumi-stack)
      PULUMI_STACK="$2"
      shift 2
      ;;
    --pulumi-secrets-provider)
      PULUMI_SECRETS_PROVIDER="$2"
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

for name in PULUMI_BACKEND_URL PULUMI_STACK PULUMI_SECRETS_PROVIDER WORKING_DIRECTORY; do
  if [[ -z "${!name}" ]]; then
    echo "${name} is required" >&2
    exit 1
  fi
done

cd "${WORKING_DIRECTORY}"
pulumi login "${PULUMI_BACKEND_URL}"

if pulumi stack select "${PULUMI_STACK}" >/dev/null 2>&1; then
  current_provider="$(
    pulumi stack export --stack "${PULUMI_STACK}" |
      jq -r '.deployment.secrets_providers.state.url // empty'
  )"
  if [[ "${current_provider}" != "${PULUMI_SECRETS_PROVIDER}" ]]; then
    echo "secrets provider mismatch for stack ${PULUMI_STACK}: expected ${PULUMI_SECRETS_PROVIDER}, got ${current_provider:-<empty>}" >&2
    exit 1
  fi
else
  pulumi stack init "${PULUMI_STACK}" --secrets-provider "${PULUMI_SECRETS_PROVIDER}" >/dev/null
fi
