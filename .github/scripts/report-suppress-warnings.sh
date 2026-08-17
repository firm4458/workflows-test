#!/usr/bin/env bash
# Report @SuppressWarnings in Java files whose PR diff vs origin/main
# touches that annotation. Writes a markdown report (with review checkboxes)
# to the given file, and emits GitHub Actions workflow commands on stdout
# so those lines are annotated on the PR.
#
# Usage: report-suppress-warnings.sh <output.md> [base-ref]
# Requires origin/main (use fetch-depth: 0, or git fetch origin main).
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <output.md> [base-ref]" >&2
  exit 1
fi

OUTPUT=$1
BASE_REF=${2:-origin/main}
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

# Base URL for GitHub blob permalinks (https://github.com/owner/repo/blob/<sha>).
repo_blob_url() {
  local sha
  sha=$(git rev-parse HEAD)
  if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s/%s/blob/%s' "${GITHUB_SERVER_URL%/}" "$GITHUB_REPOSITORY" "$sha"
    return
  fi
  local origin
  origin=$(git remote get-url origin)
  origin=${origin%.git}
  if [[ "$origin" =~ ^git@([^:]+):(.+)$ ]]; then
    origin="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  elif [[ "$origin" =~ ^ssh://git@([^/]+)/(.+)$ ]]; then
    origin="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
  printf '%s/blob/%s' "$origin" "$sha"
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

  printf '%s/%s#%s\n' "$(repo_blob_url)" "$file" "$range"
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
