#!/usr/bin/env bash
# Usage: ./fetch-issue.sh <project_path> <issue_iid>
# Example: ./fetch-issue.sh mygroup/myproject 42
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <project_path> <issue_iid>" >&2
  echo "Example: $0 mygroup/myproject 42" >&2
  exit 1
fi

parse_args "$@"
load_env

PROJECT_PATH="${PARSED_POSITIONALS[0]}"
ISSUE_IID="${PARSED_POSITIONALS[1]}"
ENCODED_PROJECT="$(urlencode_project "$PROJECT_PATH")"

issue_json="$(gl_get "/projects/${ENCODED_PROJECT}/issues/${ISSUE_IID}")"

title="$(printf '%s' "$issue_json" | jq -r '.title')"
safe_title="$(md_escape_heading "$title")"

echo "# Issue ${PROJECT_PATH}#${ISSUE_IID}: ${safe_title}"
echo ""

echo "## Metadata"
echo ""
printf '%s' "$issue_json" | jq -r '
  "- **state**: " + .state,
  "- **author**: @" + .author.username,
  "- **labels**: " + (if (.labels | length) > 0 then (.labels | join(", ")) else "_none_" end),
  "- **created_at**: " + .created_at,
  "- **updated_at**: " + .updated_at,
  "- **web_url**: " + .web_url
'
echo ""

echo "## Description"
echo ""
printf '%s' "$issue_json" | jq -r '.description // "_No description provided._"'
echo ""

echo "## Comments"
echo ""
notes_json="$(gl_paginate "/projects/${ENCODED_PROJECT}/issues/${ISSUE_IID}/notes")"
count="$(printf '%s' "$notes_json" | jq '[.[] | select(.system == false)] | length')"

if [[ "$count" -eq 0 ]]; then
  echo "_No comments._"
else
  printf '%s' "$notes_json" | jq -r '
    .[] | select(.system == false) |
    "### @" + .author.username + " — " + .created_at,
    "",
    .body,
    ""
  '
  echo "_Total: ${count} comment(s)._"
fi
echo ""

echo "## Related Merge Requests"
echo ""
related_json="$(gl_get "/projects/${ENCODED_PROJECT}/issues/${ISSUE_IID}/related_merge_requests" 2>/dev/null)" || related_json="[]"
related_count="$(printf '%s' "$related_json" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo "0")"

if [[ "$related_count" -eq 0 ]]; then
  echo "_No related merge requests._"
else
  printf '%s' "$related_json" | jq -r '
    if type == "array" then
      .[] | "- !" + (.iid | tostring) + " **" + .title + "** (" + .state + ") → " + .web_url
    else empty end
  '
fi
