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

OUTPUT=$1
GITHUB_SERVER_URL=$2
GITHUB_REPOSITORY=$3
BASE_REF=${4:-origin/main}
if [[ "$OUTPUT" != /* ]]; then
  OUTPUT="$(pwd)/$OUTPUT"
fi

cd "$(git rev-parse --show-toplevel)"

CONTEXT=2

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "Fetching $BASE_REF..."
  git fetch --no-tags origin "${BASE_REF#origin/}:${BASE_REF}"
fi

# Percent-encode a value for a GitHub Actions workflow-command message.
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-a-warning-message
gha_escape() {
  local s=$1
  s=${s//'%'/'%25'}
  s=${s//$'\r'/'%0D'}
  s=${s//$'\n'/'%0A'}
  printf '%s' "$s"
}

# Permalink GitHub will auto-embed as a code snippet in PR comments.
# https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-a-permanent-link-to-a-code-snippet
print_permalink() {
  local file=$1
  local line=$2
  local start=$((line - CONTEXT))
  local end=$((line + CONTEXT))
  local total

  [[ $start -lt 1 ]] && start=1
  total=$(wc -l < "$file" | tr -d ' ')
  [[ $end -gt $total ]] && end=$total

  local range="L${start}"
  [[ $start -ne $end ]] && range="L${start}-L${end}"

  printf '%s/%s/blob/%s/%s#%s\n' "${GITHUB_SERVER_URL%/}" "$GITHUB_REPOSITORY" "$(git rev-parse HEAD)" "$file" "$range"
}

files=$(git diff "${BASE_REF}...HEAD" -G"@SuppressWarnings" --name-only | grep "\.java" || true)

{
  echo -e "\n\n# :warning:New Warning Suppressions:warning:\n"
  echo
} >> "$OUTPUT"

if [[ -z "$files" ]]; then
  echo "No Java files with \`@SuppressWarnings\` changes vs \`${BASE_REF}\`." >> "$OUTPUT"
  echo "No Java files with @SuppressWarnings changes vs ${BASE_REF}."
  exit 0
fi

found=0

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
      print_permalink "$file" "$lineno"
      echo
    } >> "$OUTPUT"

    echo "::warning file=${file},line=${lineno},title=@SuppressWarnings::$(gha_escape "$content")"
    found=$((found + 1))
  done <<< "$matches"
done <<< "$files"

{
  echo "---"
  echo
  echo "Found ${found} \`@SuppressWarnings\` annotation(s) to review."
} >> "$OUTPUT"

echo "Wrote ${found} @SuppressWarnings annotation(s) to ${OUTPUT}."
