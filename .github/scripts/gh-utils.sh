# Percent-encode a value for a GitHub Actions workflow-command message.
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-a-warning-message
gha_escape() {
  local s=$1
  s=${s//'%'/'%25'}
  s=${s//$'\r'/'%0D'}
  s=${s//$'\n'/'%0A'}
  printf '%s' "$s"
}

# Percent-encode a GitHub Actions workflow-command property value (file, title, …).
# Properties additionally require escaping ':' and ','.
gha_escape_prop() {
  local s
  s=$(gha_escape "$1")
  s=${s//':'/'%3A'}
  s=${s//','/'%2C'}
  printf '%s' "$s"
}

# Make a path repo-relative for GitHub file annotations (strip file:// and GITHUB_WORKSPACE).
gha_workspace_path() {
  local path=$1
  path=${path#file://}
  if [[ -n "${GITHUB_WORKSPACE:-}" && "$path" == "${GITHUB_WORKSPACE}"/* ]]; then
    path="${path#"${GITHUB_WORKSPACE}"/}"
  fi
  printf '%s' "$path"
}

# Emit a GitHub Actions file annotation.
# Usage: gha_annotate <error|warning|notice> <file> <line> <message> [title] [end_line] [col] [end_col]
gha_annotate() {
  local level=$1
  local file=$2
  local line=$3
  local message=$4
  local title=${5:-}
  local end_line=${6:-}
  local col=${7:-}
  local end_col=${8:-}

  local -a props=("file=$(gha_escape_prop "$file")")
  [[ -n "$line" ]] && props+=("line=${line}")
  [[ -n "$end_line" ]] && props+=("endLine=${end_line}")
  [[ -n "$col" ]] && props+=("col=${col}")
  [[ -n "$end_col" ]] && props+=("endColumn=${end_col}")
  [[ -n "$title" ]] && props+=("title=$(gha_escape_prop "$title")")

  local IFS=','
  echo "::${level} ${props[*]}::$(gha_escape "$message")"
}


# Permalink GitHub will auto-embed as a code snippet in PR comments.
# https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-a-permanent-link-to-a-code-snippet
make_permalink() {
  local file=$1
  local line=$2
  local github_server_url=$3
  local github_repository=$4
  local context="${5:-2}"
  local start=$((line - context))
  local end=$((line + context))
  local total

  [[ $start -lt 1 ]] && start=1
  total=$(wc -l < "$file" | tr -d ' ')
  [[ $end -gt $total ]] && end=$total

  local range="L${start}"
  [[ $start -ne $end ]] && range="L${start}-L${end}"

  printf '%s/%s/blob/%s/%s#%s' "${github_server_url%/}" "$github_repository" "$(git rev-parse HEAD)" "$file" "$range"
}

