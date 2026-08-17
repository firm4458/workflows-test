#!/usr/bin/env bash
# Set up a quality-gate check directory, run commands, and record status.
# Mirrors .github/scripts/quality-gate/setup.sh and success.sh.
set -euo pipefail

: "${QUALITY_GATE_ID:?id is required}"
: "${QUALITY_GATE_NAME:?name is required}"
: "${QUALITY_GATE_COMMANDS:?commands are required}"

if [[ "$QUALITY_GATE_ID" == */* || "$QUALITY_GATE_ID" == "." || "$QUALITY_GATE_ID" == ".." ]]; then
  echo "Invalid check id: ${QUALITY_GATE_ID}" >&2
  exit 1
fi

OUTPUT_DIRECTORY="${QUALITY_GATE_OUTPUT_ROOT:-${OUTPUT_DIRECTORY:-}}"
if [[ -z "$OUTPUT_DIRECTORY" ]]; then
  echo "OUTPUT_DIRECTORY env (or output-directory input) is required" >&2
  exit 1
fi

QUALITY_GATE_DIR="$OUTPUT_DIRECTORY/$QUALITY_GATE_ID"
QUALITY_GATE_OUTPUT="$QUALITY_GATE_DIR/output.md"
export QUALITY_GATE_ID QUALITY_GATE_NAME QUALITY_GATE_DIR QUALITY_GATE_OUTPUT OUTPUT_DIRECTORY

# setup.sh: create the check directory and an empty status file (Not run until finished).
mkdir -p "$QUALITY_GATE_DIR"
: > "$QUALITY_GATE_DIR/status"
printf '%s\n' "$QUALITY_GATE_NAME" > "$QUALITY_GATE_DIR/name"

set +e
bash --noprofile --norc -eo pipefail -c "$QUALITY_GATE_COMMANDS"
exit_code=$?
set -e

if [[ -s "$QUALITY_GATE_DIR/status" ]]; then
  status=$(<"$QUALITY_GATE_DIR/status")
else
  if [[ $exit_code -eq 0 ]]; then
    status=success
  elif [[ $exit_code -ne 0 ]]; then
    status=fail
  fi
  printf '%s' "$status" > "$QUALITY_GATE_DIR/status"
fi



if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "status=${status}"
    echo "output-directory=${QUALITY_GATE_DIR}"
  } >> "$GITHUB_OUTPUT"
fi

exit "$exit_code"
