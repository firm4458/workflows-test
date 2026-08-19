#!/usr/bin/env bash
# Parse a PMD SARIF report. Appends a markdown table to the given file and
# emits GitHub Actions workflow-command annotations on stdout so findings are
# marked on the PR files view.
#
# Usage: parse-pmd.sh <output.md> <sarif.json>
# Exits 1 if the report contains any findings.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <output.md> <sarif.json>" >&2
  exit 1
fi

source "$(dirname "$0")/gh-utils.sh"

OUTPUT=$1
SARIF=$2
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$(pwd)/$OUTPUT"
fi
if [[ "$SARIF" != /* ]]; then
  SARIF="$(pwd)/$SARIF"
fi

if [[ ! -f "$SARIF" ]]; then
  echo "PMD SARIF report not found: $SARIF" >&2
  exit 1
fi

cd "$(git rev-parse --show-toplevel)"

{
  echo -e "\n\nPMD\n"
  echo "|Type|Message|Location|"
  echo "|--|--|--|"
} >> "$OUTPUT"

count=0
while IFS= read -r result; do
  [[ -z "$result" ]] && continue

  rule_id=$(jq -r '.ruleId // empty' <<<"$result")
  message=$(jq -r '.message.text // empty' <<<"$result")
  file=$(gha_workspace_path "$(jq -r '.locations[0].physicalLocation.artifactLocation.uri // empty' <<<"$result")")
  start_line=$(jq -r '.locations[0].physicalLocation.region.startLine // empty' <<<"$result")
  end_line=$(jq -r '.locations[0].physicalLocation.region.endLine // empty' <<<"$result")
  start_col=$(jq -r '.locations[0].physicalLocation.region.startColumn // empty' <<<"$result")
  end_col=$(jq -r '.locations[0].physicalLocation.region.endColumn // empty' <<<"$result")

  location="$file"
  if [[ -n "$start_line" ]]; then
    location="${file}:${start_line}"
    [[ -n "$end_line" ]] && location="${location}-${end_line}"
  fi

  echo "|${rule_id}|${message}|${location}|" >> "$OUTPUT"
  gha_annotate error "$file" "$start_line" "$message" "$rule_id" "$end_line" "$start_col" "$end_col"
  count=$((count + 1))
done < <(jq -c '.runs[].results[]?' "$SARIF")

echo "Reported ${count} PMD finding(s) to ${OUTPUT}."

if [[ "$count" -ne 0 ]]; then
  exit 1
fi
