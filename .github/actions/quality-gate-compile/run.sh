#!/usr/bin/env bash
# Resolve quality-gate compile inputs and write the markdown report.
set -euo pipefail

OUTPUT_DIRECTORY="${QUALITY_GATE_OUTPUT_ROOT:-${OUTPUT_DIRECTORY:-}}"
if [[ -z "$OUTPUT_DIRECTORY" ]]; then
  echo "OUTPUT_DIRECTORY env (or output-directory input) is required" >&2
  exit 1
fi

REPORT="${QUALITY_GATE_REPORT:-$OUTPUT_DIRECTORY/results.md}"

ACTION_PATH="${GITHUB_ACTION_PATH:-$(cd "$(dirname "$0")" && pwd)}"

set +e
bash "${ACTION_PATH}/compile.sh" "$OUTPUT_DIRECTORY" "$REPORT"
exit_code=$?
set -e

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "report=${REPORT}" >> "$GITHUB_OUTPUT"
fi

exit "$exit_code"
