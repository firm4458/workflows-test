#!/usr/bin/env bash
# Compile per-check quality-gate results into a single markdown report.
#
# Each immediate subdirectory of <results-directory> is treated as a check:
#   <id>/status      — check outcome (missing or blank → "Not run")
#   <id>/name        — optional display name
#   <id>/output.md   — optional markdown body
#
# The report includes a check only if its status is not "success", or if
# output.md is present.
#
# Usage: compile.sh <results-directory> [output.md]
# Writes to stdout if [output.md] is omitted.
# Exits 1 if any check status is "fail" or "Not run".
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <results-directory> [output.md]" >&2
  exit 1
fi

RESULTS_DIR=$1
OUTPUT=${2:-}

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "Results directory not found: $RESULTS_DIR" >&2
  exit 1
fi

trim() {
  local s=$1
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

read_status() {
  local status_file=$1
  if [[ ! -f "$status_file" ]]; then
    printf '%s' "Not run"
    return
  fi
  local content
  content=$(trim "$(<"$status_file")")
  if [[ -z "$content" ]]; then
    printf '%s' "Not run"
    return
  fi
  printf '%s' "$content"
}

read_should_block() {
  local should_block_file=$1
  if [[ ! -f "$should_block_file" ]]; then
    printf '%s' "false"
    return
  fi
  local content
  content=$(trim "$(<"$should_block_file")")
  if [[ -z "$content" ]]; then
    printf '%s' "false"
    return
  fi
  printf '%s' "$content"
}

read_name() {
  local name_file=$1
  local fallback=$2
  if [[ ! -f "$name_file" ]]; then
    printf '%s' "$fallback"
    return
  fi
  local content
  content=$(trim "$(<"$name_file")")
  if [[ -z "$content" ]]; then
    printf '%s' "$fallback"
    return
  fi
  printf '%s' "$content"
}

shopt -s nullglob
dirs=()
for dir in "$RESULTS_DIR"/*/; do
  dirs+=("$dir")
done
if [[ ${#dirs[@]} -gt 0 ]]; then
  IFS=$'\n' dirs=($(printf '%s\n' "${dirs[@]}" | LC_ALL=C sort))
  unset IFS
fi

names=()
statuses=()
all_results=()
unsuccessful=0
if [[ ${#dirs[@]} -gt 0 ]]; then
  for i in "${!dirs[@]}"; do
    dir=${dirs[$i]}
    id=$(basename "$dir")
    status=$(read_status "${dir}status")
    name=$(read_name "${dir}name" "$id")
    should_block=$(read_should_block "${dir}block")
    names+=("$name")
    statuses+=("$status")
    normalized=$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')
    if [[ $should_block == "true" ]]; then
      unsuccessful=1
    fi
    all_results+=("$i")
  done  
fi

emit() {
  if [[ -n "$OUTPUT" ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    cat > "$OUTPUT"
  else
    cat
  fi
}

{
  echo "# Quality Gate Results"
  echo

  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "_No checks found in \`${RESULTS_DIR}\`._"
  elif [[ ${#all_results[@]} -eq 0 ]]; then
    echo "_All checks succeeded._"
  else
    echo "| Check | Status |"
    echo "|-------|--------|"
    for i in "${all_results[@]}"; do
      echo "| ${names[$i]} | ${statuses[$i]} |"
    done

    for i in "${all_results[@]}"; do
      output_file="${dirs[$i]}output.md"
      if [[ -f "$output_file" && -s "$output_file" ]]; then
        echo
        echo "---"
        echo
        echo "# ${names[$i]}"
        echo
        echo "status: ${statuses[$i]}"
        echo
        cat "$output_file"
        echo
      fi
    done
  fi
} | emit

exit "$unsuccessful"
