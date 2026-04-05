#!/usr/bin/env bash

# Reconcile the managed DSQL endpoint for a given Pulumi stack.
#
# Usage:
#   scripts/reconcile-managed-dsql-endpoint.sh \
#     --stack devo \
#     --aws-region ap-northeast-1 \
#     --infra-dir infra
#
# The script reads dsqlClusterIdentifier from the Pulumi stack output,
# calls aws dsql get-cluster to fetch the authoritative endpoint, and
# writes it back to Pulumi config as dsqlEndpoint.
#
# Requires: pulumi (already logged in), aws CLI with DSQL permissions.

set -euo pipefail

STACK="devo"
AWS_REGION=""
INFRA_DIR="infra"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      STACK="$2"
      shift 2
      ;;
    --aws-region)
      AWS_REGION="$2"
      shift 2
      ;;
    --infra-dir)
      INFRA_DIR="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${AWS_REGION}" ]]; then
  echo "--aws-region is required" >&2
  exit 1
fi

resolve_dsql_cluster_identifier() {
  pulumi stack output dsqlClusterIdentifier --stack "${STACK}" 2>/dev/null
}

clear_managed_dsql_endpoint() {
  pulumi config rm dsqlEndpoint --stack "${STACK}" >/dev/null 2>&1 || true
}

pushd "${INFRA_DIR}" >/dev/null

dsql_cluster_identifier="$(resolve_dsql_cluster_identifier || true)"
if [[ -z "${dsql_cluster_identifier}" ]]; then
  clear_managed_dsql_endpoint
  echo "failed to resolve dsqlClusterIdentifier for stack ${STACK}" >&2
  popd >/dev/null
  exit 1
fi

if ! dsql_endpoint="$(aws dsql get-cluster \
    --identifier "${dsql_cluster_identifier}" \
    --region "${AWS_REGION}" \
    --query endpoint \
    --output text)"; then
  clear_managed_dsql_endpoint
  echo "failed to resolve managed DSQL endpoint for stack ${STACK}" >&2
  popd >/dev/null
  exit 1
fi

if [[ -z "${dsql_endpoint}" || "${dsql_endpoint}" == "None" || "${dsql_endpoint}" == "null" ]]; then
  clear_managed_dsql_endpoint
  echo "managed DSQL endpoint was empty for stack ${STACK}" >&2
  popd >/dev/null
  exit 1
fi

pulumi config set dsqlEndpoint "${dsql_endpoint}" --stack "${STACK}"
popd >/dev/null
