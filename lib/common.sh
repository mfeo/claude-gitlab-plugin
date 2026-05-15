#!/usr/bin/env bash
set -euo pipefail

load_env() {
  if [[ -z "${GITLAB_URL:-}" ]]; then
    echo "Error: GITLAB_URL is not set. Add it to your shell rc or ~/.claude/settings.json env block." >&2
    exit 1
  fi
  if [[ -z "${GITLAB_TOKEN:-}" ]]; then
    echo "Error: GITLAB_TOKEN is not set. Add it to your shell rc or ~/.claude/settings.json env block." >&2
    exit 1
  fi
  GITLAB_URL="${GITLAB_URL%/}"
}

urlencode_project() {
  local path="$1"
  printf '%s' "${path//\//%2F}"
}

handle_http_status() {
  local code="$1"
  local body="$2"
  case "$code" in
    401)
      echo "Error 401: Token invalid or expired. Check GITLAB_TOKEN." >&2
      ;;
    403)
      echo "Error 403: Insufficient scope or no project access. Required scope: read_api." >&2
      ;;
    404)
      echo "Error 404: Project path or iid not found. Check URL encoding and iid value." >&2
      ;;
    *)
      echo "Error $code: Unexpected response." >&2
      echo "$body" >&2
      ;;
  esac
  exit 1
}

gl_get() {
  local path="$1"
  local tmp_headers
  tmp_headers="$(mktemp)"
  local body
  body="$(curl -sS -D "$tmp_headers" \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${GITLAB_URL}${path}")"
  local code
  code="$(head -1 "$tmp_headers" | grep -oE '[0-9]{3}')"
  rm -f "$tmp_headers"
  if [[ "$code" != 2* ]]; then
    handle_http_status "$code" "$body"
  fi
  printf '%s' "$body"
}

gl_paginate() {
  local path="$1"
  local per_page="${2:-100}"
  local page=1
  local all_pages=()
  local tmp_headers body code next_page

  while true; do
    tmp_headers="$(mktemp)"
    body="$(curl -sS -D "$tmp_headers" \
      -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
      "${GITLAB_URL}${path}?per_page=${per_page}&page=${page}")"
    code="$(head -1 "$tmp_headers" | grep -oE '[0-9]{3}')"
    if [[ "$code" != 2* ]]; then
      rm -f "$tmp_headers"
      handle_http_status "$code" "$body"
    fi
    next_page="$(grep -i '^x-next-page:' "$tmp_headers" | tr -d '\r' | awk '{print $2}')"
    rm -f "$tmp_headers"
    all_pages+=("$body")
    if [[ -z "$next_page" ]]; then
      break
    fi
    page="$next_page"
  done

  # merge all pages into a single JSON array
  printf '%s\n' "${all_pages[@]}" | jq -s 'add // []'
}

MAX_DIFF_LINES_PER_FILE="${MAX_DIFF_LINES_PER_FILE:-500}"

parse_args() {
  USE_DISCUSSIONS="0"
  INCLUDE_DIFF="0"
  local positionals=()
  for arg in "$@"; do
    case "$arg" in
      --discussions) USE_DISCUSSIONS="1" ;;
      --diff)        INCLUDE_DIFF="1" ;;
      *)             positionals+=("$arg") ;;
    esac
  done
  export USE_DISCUSSIONS INCLUDE_DIFF
  PARSED_POSITIONALS=("${positionals[@]+"${positionals[@]}"}")
}

md_escape_heading() {
  printf '%s' "$1" | tr -d '\n\r' | sed 's/^[[:space:]#]*//'
}
