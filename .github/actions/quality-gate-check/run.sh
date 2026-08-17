#!/usr/bin/env bash
# Set up a quality-gate check directory, run commands, and record status.
set -euo pipefail

: "${QUALITY_GATE_ID:?id is required}"
: "${QUALITY_GATE_NAME:?name is required}"
: "${QUALITY_GATE_COMMANDS:?commands are required}"
: "${QUALITY_GATE_OUTPUT_ROOT:?root output directory is required}"

if [[ "$QUALITY_GATE_ID" == */* || "$QUALITY_GATE_ID" == "." || "$QUALITY_GATE_ID" == ".." ]]; then
  echo "Invalid check id: ${QUALITY_GATE_ID}" >&2
  exit 1
fi

QUALITY_GATE_DIR="$QUALITY_GATE_OUTPUT_ROOT/$QUALITY_GATE_ID"
QUALITY_GATE_OUTPUT="$QUALITY_GATE_DIR/output.md"
QUALITY_GATE_STATUS="$QUALITY_GATE_DIR/status"
QUALITY_GATE_SHOULD_BLOCK="$QUALITY_GATE_DIR/block"
export QUALITY_GATE_ID QUALITY_GATE_NAME QUALITY_GATE_DIR QUALITY_GATE_OUTPUT QUALITY_GATE_STATUS QUALITY_GATE_SHOULD_BLOCK

mkdir -p "$QUALITY_GATE_DIR"
: > "$QUALITY_GATE_OUTPUT"
: > "$QUALITY_GATE_STATUS"
: > "$QUALITY_GATE_SHOULD_BLOCK"
printf '%s\n' "$QUALITY_GATE_NAME" > "$QUALITY_GATE_DIR/name"

set +e
bash --noprofile --norc -eo pipefail -c "$QUALITY_GATE_COMMANDS"
exit_code=$?
set -e

if [[ $exit_code -eq 0 ]]; then
  status="success"
elif [[ $exit_code -eq 1 ]]; then
  status="fail"
elif [[ $exit_code -eq 2 ]]; then
  status="warn"
else
  status="unknown"
fi

printf '%s' "$status" > "$QUALITY_GATE_STATUS"


if [[ $exit_code -ne 0 &&  "${QUALITY_GATE_BLOCKING_CHECK,,}" == "true" ]]; then
  printf 'true' > "$QUALITY_GATE_SHOULD_BLOCK"
  final_exit_code=1
else
  printf 'false' > "$QUALITY_GATE_SHOULD_BLOCK"
  final_exit_code=0
fi

exit "$final_exit_code"
