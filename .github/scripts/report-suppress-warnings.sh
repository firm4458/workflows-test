#!/usr/bin/env bash
# Report @SuppressWarnings in Java files whose PR diff vs origin/main
# touches that annotation. Writes a markdown report (with review checkboxes)
# to the given file, and emits GitHub Actions workflow commands on stdout
# so those lines are annotated on the PR.
#
# Usage: report-suppress-warnings.sh <output.md> <server-url> <repository> [base-ref]
# Requires origin/main (use fetch-depth: 0, or git fetch origin main).
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <output.md> <server-url> <repository> [base-ref]" >&2
  exit 1
fi

source "$(dirname "$0")/gh-utils.sh"

OUTPUT=$1
GITHUB_SERVER_URL=$2
GITHUB_REPOSITORY=$3
BASE_REF=${4:-origin/main}
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$(pwd)/$OUTPUT"
fi

cd "$(git rev-parse --show-toplevel)"

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "Fetching $BASE_REF..."
  git fetch --no-tags origin "${BASE_REF#origin/}:${BASE_REF}"
fi

files=$(git diff "${BASE_REF}...HEAD" -G"@SuppressWarnings" --name-only | grep "\.java" || true)

if [[ -z "$files" ]]; then
  echo "No Java files with \`@SuppressWarnings\` changes vs \`${BASE_REF}\`." >> "$OUTPUT"
  echo "No Java files with @SuppressWarnings changes vs ${BASE_REF}."
  exit 0
fi

found=0

{
  echo -e "\n\n# :warning:New Warning Suppressions:warning:\n"
  echo
} >> "$OUTPUT"

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  if [[ ! -f "$file" ]]; then
    {
      echo "- [ ] \`${file}\` (file deleted in this PR)"
      echo
    } >> "$OUTPUT"
    continue
  fi

  matches=$(grep -n -- "@SuppressWarnings" "$file" || true)
  if [[ -z "$matches" ]]; then
    continue
  fi

  while IFS= read -r match; do
    lineno=${match%%:*}
    content=${match#*:}
    # Trim leading whitespace for the checkbox label.
    label=${content#"${content%%[![:space:]]*}"}

    {
      echo "- [ ] \`${file}:${lineno}\` — \`${label}\`"
      echo
      make_permalink "$file" "$lineno" "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY"
      echo
      echo
    } >> "$OUTPUT"

    gha_annotate warning "$file" "$lineno" "$content" "@SuppressWarnings"
    found=$((found + 1))
  done <<< "$matches"
done <<< "$files"

if [[ "$found" -ne 0 ]]; then
  if [[ -n "${QUALITY_GATE_DIR:-}" && -f "${QUALITY_GATE_DIR}/status" ]]; then
    echo "warning" > "${QUALITY_GATE_DIR}/status"
  fi
fi
