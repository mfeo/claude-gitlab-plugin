#!/usr/bin/env bash
# Usage: ./fetch-mr.sh <project_path> <mr_iid> [--diff] [--discussions]
# Example: ./fetch-mr.sh mygroup/myproject 101
#          ./fetch-mr.sh mygroup/myproject 101 --diff
#          ./fetch-mr.sh mygroup/myproject 101 --diff --discussions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <project_path> <mr_iid> [--diff] [--discussions]" >&2
  echo "Example: $0 mygroup/myproject 101" >&2
  exit 1
fi

parse_args "$@"
load_env

PROJECT_PATH="${PARSED_POSITIONALS[0]}"
MR_IID="${PARSED_POSITIONALS[1]}"
ENCODED_PROJECT="$(urlencode_project "$PROJECT_PATH")"

mr_json="$(gl_get "/projects/${ENCODED_PROJECT}/merge_requests/${MR_IID}")"

title="$(printf '%s' "$mr_json" | jq -r '.title')"
safe_title="$(md_escape_heading "$title")"

echo "# Merge Request ${PROJECT_PATH}!${MR_IID}: ${safe_title}"
echo ""

echo "## Metadata"
echo ""
printf '%s' "$mr_json" | jq -r '
  "- **state**: " + .state,
  "- **author**: @" + .author.username,
  "- **branch**: " + .source_branch + " → " + .target_branch,
  "- **draft**: " + ((.draft // .work_in_progress // false) | tostring),
  "- **created_at**: " + .created_at,
  "- **updated_at**: " + .updated_at,
  "- **web_url**: " + .web_url
'
echo ""

echo "## Description"
echo ""
printf '%s' "$mr_json" | jq -r '.description // "_No description provided._"'
echo ""

if [[ "$INCLUDE_DIFF" == "1" ]]; then
  echo "## Diff"
  echo ""
  diffs_json="$(gl_paginate "/projects/${ENCODED_PROJECT}/merge_requests/${MR_IID}/diffs" 20)"
  file_count="$(printf '%s' "$diffs_json" | jq 'length')"

  if [[ "$file_count" -eq 0 ]]; then
    echo "_No diff available._"
    echo ""
  else
    while IFS= read -r entry; do
      new_path="$(printf '%s' "$entry" | jq -r '.new_path')"
      old_path="$(printf '%s' "$entry" | jq -r '.old_path')"
      renamed="$(printf '%s' "$entry" | jq -r '.renamed_file')"
      diff_body="$(printf '%s' "$entry" | jq -r '.diff')"

      if [[ "$renamed" == "true" && "$old_path" != "$new_path" ]]; then
        echo "### ${old_path} → ${new_path}"
      else
        echo "### ${new_path}"
      fi
      echo ""

      if [[ -z "$diff_body" ]]; then
        echo "_Binary or empty diff._"
      else
        total_lines="$(printf '%s' "$diff_body" | wc -l | tr -d ' ')"
        if [[ "$total_lines" -gt "$MAX_DIFF_LINES_PER_FILE" ]]; then
          echo '```diff'
          printf '%s' "$diff_body" | head -n "$MAX_DIFF_LINES_PER_FILE"
          echo '```'
          echo ""
          echo "_(diff truncated at ${MAX_DIFF_LINES_PER_FILE} lines; ${total_lines} total)_"
        else
          echo '```diff'
          printf '%s' "$diff_body"
          echo '```'
        fi
      fi
      echo ""
    done < <(printf '%s' "$diffs_json" | jq -c '.[]')
  fi
fi

if [[ "$USE_DISCUSSIONS" == "1" ]]; then
  echo "## Discussions"
  echo ""
  discussions_json="$(gl_paginate "/projects/${ENCODED_PROJECT}/merge_requests/${MR_IID}/discussions")"
  thread_count="$(printf '%s' "$discussions_json" | jq 'length')"

  if [[ "$thread_count" -eq 0 ]]; then
    echo "_No discussions._"
  else
    while IFS= read -r thread; do
      notes_raw="$(printf '%s' "$thread" | jq -c '[.notes[] | select(.system == false)]')"
      note_count="$(printf '%s' "$notes_raw" | jq 'length')"
      [[ "$note_count" -eq 0 ]] && continue

      resolvable_count="$(printf '%s' "$notes_raw" | jq '[.[] | select(.resolvable == true)] | length')"
      resolved_count="$(printf '%s' "$notes_raw" | jq '[.[] | select(.resolvable == true and .resolved == true)] | length')"
      if [[ "$resolvable_count" -gt 0 && "$resolvable_count" -eq "$resolved_count" ]]; then
        status="resolved"
      elif [[ "$resolvable_count" -gt 0 ]]; then
        status="unresolved"
      else
        status="general"
      fi

      first_note="$(printf '%s' "$notes_raw" | jq -c '.[0]')"
      position_path="$(printf '%s' "$first_note" | jq -r '.position.new_path // empty')"
      position_line="$(printf '%s' "$first_note" | jq -r '(.position.new_line // .position.old_line) // empty')"

      if [[ -n "$position_path" ]]; then
        echo "### Thread on ${position_path}:${position_line} [${status}]"
      else
        echo "### General Thread [${status}]"
      fi
      echo ""

      while IFS= read -r note; do
        author="$(printf '%s' "$note" | jq -r '.author.username')"
        ts="$(printf '%s' "$note" | jq -r '.created_at')"
        body="$(printf '%s' "$note" | jq -r '.body')"
        echo "#### @${author} — ${ts}"
        echo ""
        echo "${body}"
        echo ""
      done < <(printf '%s' "$notes_raw" | jq -c '.[]')

    done < <(printf '%s' "$discussions_json" | jq -c '.[]')
  fi
else
  echo "## Comments"
  echo ""
  notes_json="$(gl_paginate "/projects/${ENCODED_PROJECT}/merge_requests/${MR_IID}/notes")"
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
fi
