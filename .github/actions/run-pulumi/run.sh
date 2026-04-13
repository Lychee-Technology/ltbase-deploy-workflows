#!/usr/bin/env bash

set -euo pipefail

WORKING_DIRECTORY=""
COMMAND_NAME=""
STACK=""
PREFER_WRAPPER="true"
WRAPPER_PATH="scripts/pulumi-wrapper.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --working-directory)
      WORKING_DIRECTORY="$2"
      shift 2
      ;;
    --command)
      COMMAND_NAME="$2"
      shift 2
      ;;
    --stack)
      STACK="$2"
      shift 2
      ;;
    --prefer-wrapper)
      PREFER_WRAPPER="$2"
      shift 2
      ;;
    --wrapper-path)
      WRAPPER_PATH="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for name in WORKING_DIRECTORY COMMAND_NAME STACK PREFER_WRAPPER WRAPPER_PATH; do
  if [[ -z "${!name}" ]]; then
    echo "${name} is required" >&2
    exit 1
  fi
done

working_directory_abs="$(cd "${WORKING_DIRECTORY}" && pwd)"

case "${COMMAND_NAME}" in
  preview)
    pulumi_args=(preview --stack "${STACK}" --non-interactive --logtostderr --logflow -v=6)
    ;;
  up)
    pulumi_args=(up --stack "${STACK}" --yes --non-interactive --logtostderr --logflow -v=6)
    ;;
  refresh)
    pulumi_args=(refresh --stack "${STACK}" --yes --non-interactive)
    ;;
  *)
    echo "unsupported command: ${COMMAND_NAME}" >&2
    exit 1
    ;;
esac

wrapper_candidate="${WRAPPER_PATH}"
if [[ "${wrapper_candidate}" != /* ]]; then
  wrapper_candidate="${working_directory_abs}/${wrapper_candidate}"
fi

runner=(pulumi)
if [[ "${PREFER_WRAPPER}" == "true" && -x "${wrapper_candidate}" ]]; then
  runner=("${wrapper_candidate}")
  printf 'Using Pulumi wrapper: %s\n' "${wrapper_candidate}"
else
  printf 'Using direct Pulumi CLI\n'
fi

printf 'Runner architecture: %s\n' "$(uname -m)"
printf 'Go env hints: GOMAXPROCS=%s, GOMEMLIMIT=%s, GOGC=%s\n' "${GOMAXPROCS:-}" "${GOMEMLIMIT:-}" "${GOGC:-}"

(
  cd "${working_directory_abs}"
  "${runner[@]}" "${pulumi_args[@]}"
)
