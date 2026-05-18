#!/usr/bin/env bash

set -euo pipefail

WORKING_DIRECTORY=""
TARGET_STACK=""
CANDIDATE_STACKS=""
CONTROLPLANE_UI_DOMAIN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --working-directory)
      WORKING_DIRECTORY="$2"
      shift 2
      ;;
    --target-stack)
      TARGET_STACK="$2"
      shift 2
      ;;
    --candidate-stacks)
      CANDIDATE_STACKS="$2"
      shift 2
      ;;
    --controlplane-ui-domain)
      CONTROLPLANE_UI_DOMAIN="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for name in WORKING_DIRECTORY TARGET_STACK CANDIDATE_STACKS CONTROLPLANE_UI_DOMAIN; do
  if [[ -z "${!name:-}" ]]; then
    echo "${name} is required" >&2
    exit 1
  fi
done

cd "${WORKING_DIRECTORY}"

stacks_json='[]'
IFS=',' read -r -a stack_list <<< "${CANDIDATE_STACKS}"
target_in_candidates=false

for raw_stack in "${stack_list[@]}"; do
  stack="$(printf '%s' "${raw_stack}" | xargs)"
  if [[ "${stack}" == "${TARGET_STACK}" ]]; then
    target_in_candidates=true
    break
  fi
done

if [[ "${target_in_candidates}" != true ]]; then
  echo "candidate stacks must include target stack ${TARGET_STACK}" >&2
  exit 1
fi

for raw_stack in "${stack_list[@]}"; do
  stack="$(printf '%s' "${raw_stack}" | xargs)"
  if [[ -z "${stack}" ]]; then
    continue
  fi

  stack_outputs="$(pulumi stack output --json --stack "${stack}")"
  stack_config_json="$(printf '%s' "${stack_outputs}" | jq -r '.controlplaneUiStackConfig // empty')"

  if [[ -z "${stack_config_json}" ]]; then
    if [[ "${stack}" == "${TARGET_STACK}" ]]; then
      echo "missing controlplaneUiStackConfig for target stack ${TARGET_STACK}" >&2
      exit 1
    fi
    echo "skipping stack ${stack} because controlplaneUiStackConfig is missing" >&2
    continue
  fi

  if ! stack_entry="$(printf '%s' "${stack_config_json}" | jq -c --arg redirect_uri "https://${CONTROLPLANE_UI_DOMAIN}/auth/callback" '
    if type != "object" then
      error("controlplaneUiStackConfig must decode to an object")
    elif (.key // "") == "" or (.label // "") == "" or (.projectId // "") == "" or (.authBaseUrl // "") == "" or (.controlPlaneBaseUrl // "") == "" or (.apiBaseUrl // "") == "" or (.oidcClientId // "") == "" or (.authProviders | type != "array") or (.authProviders | length == 0) then
      error("controlplaneUiStackConfig is incomplete")
    else
      . + {redirectUri: $redirect_uri}
    end')"; then
    if [[ "${stack}" == "${TARGET_STACK}" ]]; then
      echo "invalid controlplaneUiStackConfig for target stack ${TARGET_STACK}" >&2
      exit 1
    fi
    echo "skipping stack ${stack} because controlplaneUiStackConfig is invalid" >&2
    continue
  fi
  stacks_json="$(jq -cn --argjson stacks "${stacks_json}" --argjson entry "${stack_entry}" '$stacks + [$entry]')"
done

jq -cn --argjson stacks "${stacks_json}" '{stacks: $stacks}'
