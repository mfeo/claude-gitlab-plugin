#!/usr/bin/env bash
# Tests for parse_args / emit_user_request in lib/common.sh
#
# COMMON_SH may be overridden to point the tests at a different copy of the
# library (used to verify that a test fails against the pre-change version).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SH="${COMMON_SH:-$SCRIPT_DIR/../lib/common.sh}"
# shellcheck disable=SC1090
source "$COMMON_SH"
set +e

FAILURES=0
TOTAL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   - $label"
  else
    echo "FAIL - $label"
    echo "         expected: [$expected]"
    echo "         actual:   [$actual]"
    FAILURES=$((FAILURES + 1))
  fi
}

positionals() {
  printf '%s' "${PARSED_POSITIONALS[*]+${PARSED_POSITIONALS[*]}}"
}

prompt() {
  printf '%s' "${PARSED_PROMPT:-}"
}

# --- happy path: positionals only, no prompt -------------------------------
parse_args mygroup/myproject 101
assert_eq "no prompt: positionals" "mygroup/myproject 101" "$(positionals)"
assert_eq "no prompt: prompt is empty" "" "$(prompt)"
assert_eq "no prompt: --diff off" "0" "$INCLUDE_DIFF"
assert_eq "no prompt: --discussions off" "0" "$USE_DISCUSSIONS"
assert_eq "no prompt: emits no User Request section" "" "$(emit_user_request)"

# --- flags without a prompt stay working -----------------------------------
parse_args mygroup/myproject 101 --diff --discussions
assert_eq "flags only: positionals" "mygroup/myproject 101" "$(positionals)"
assert_eq "flags only: prompt is empty" "" "$(prompt)"
assert_eq "flags only: --diff on" "1" "$INCLUDE_DIFF"
assert_eq "flags only: --discussions on" "1" "$USE_DISCUSSIONS"

# --- trailing prompt -------------------------------------------------------
parse_args mygroup/myproject 101 review this MR
assert_eq "trailing prompt: positionals unchanged" "mygroup/myproject 101" "$(positionals)"
assert_eq "trailing prompt: captured" "review this MR" "$(prompt)"

# --- flags before the prompt are still parsed as flags ---------------------
parse_args mygroup/myproject 101 --diff --discussions review this MR
assert_eq "flags then prompt: --diff on" "1" "$INCLUDE_DIFF"
assert_eq "flags then prompt: --discussions on" "1" "$USE_DISCUSSIONS"
assert_eq "flags then prompt: positionals unchanged" "mygroup/myproject 101" "$(positionals)"
assert_eq "flags then prompt: prompt excludes flags" "review this MR" "$(prompt)"

# --- once the prompt starts, flag-looking tokens are prompt text -----------
parse_args mygroup/myproject 101 explain the --diff output
assert_eq "flag inside prompt: --diff not consumed" "0" "$INCLUDE_DIFF"
assert_eq "flag inside prompt: kept verbatim" "explain the --diff output" "$(prompt)"

# --- non-ASCII prompt ------------------------------------------------------
parse_args mygroup/myproject 101 幫我 review 這個 MR
assert_eq "cjk prompt: captured" "幫我 review 這個 MR" "$(prompt)"

# --- emit_user_request output ----------------------------------------------
parse_args mygroup/myproject 101 review this MR
expected_section="## User Request

review this MR"
assert_eq "emit_user_request: renders section" "$expected_section" "$(emit_user_request)"

# --- issue-style invocation (no flags defined) -----------------------------
parse_args mygroup/myproject 42 draft an implementation plan
assert_eq "issue style: positionals" "mygroup/myproject 42" "$(positionals)"
assert_eq "issue style: prompt captured" "draft an implementation plan" "$(prompt)"

# --- a lone positional must not be mistaken for a prompt -------------------
parse_args mygroup/myproject
assert_eq "single positional: positionals" "mygroup/myproject" "$(positionals)"
assert_eq "single positional: prompt is empty" "" "$(prompt)"

# --- no arguments at all ---------------------------------------------------
parse_args
assert_eq "no args: positionals empty" "" "$(positionals)"
assert_eq "no args: prompt empty" "" "$(prompt)"

echo ""
echo "${TOTAL} assertion(s), ${FAILURES} failure(s)"
[[ "$FAILURES" -eq 0 ]]
