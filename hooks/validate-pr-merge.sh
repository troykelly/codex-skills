#!/usr/bin/env bash
# Validate PR is ready for merge
#
# Exit codes:
#   0 = Allow
#   2 = Deny (message shown to Codex)

set -euo pipefail

# Source logging utility if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log-event.sh
if [ -f "${SCRIPT_DIR}/lib/log-event.sh" ]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/log-event.sh"
fi
# shellcheck source=lib/github-state.sh
if [ -f "${SCRIPT_DIR}/lib/github-state.sh" ]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/github-state.sh"
fi

INPUT=$(cat)

TOOL_NAME=$(echo "${INPUT}" | jq -r '.tool_name // empty')
if [ "${TOOL_NAME}" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "${INPUT}" | jq -r '.tool_input.command // empty')

# Only check gh pr merge commands
if ! echo "${COMMAND}" | grep -q "gh pr merge"; then
  exit 0
fi

# Extract PR number (using sed for macOS compatibility)
PR_NUM=$(echo "${COMMAND}" | sed -n 's/.*gh pr merge[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)

if [ -z "${PR_NUM}" ]; then
  exit 0  # Can't determine PR, allow and let gh handle it
fi

REPO=$(get_repo)
if [ -z "${REPO}" ]; then
  exit 0  # Can't determine repo, allow and let gh handle it
fi

# Get PR details
PR_DATA=$(gh api "/repos/${REPO}/pulls/${PR_NUM}" 2>/dev/null || echo "{}")

if [ "${PR_DATA}" = "{}" ]; then
  exit 0  # Can't get PR data, allow and let gh handle it
fi

# Check mergeable status
MERGEABLE=$(echo "${PR_DATA}" | jq -r '.mergeable // empty')
MERGEABLE_STATE=$(echo "${PR_DATA}" | jq -r '.mergeable_state // empty')

if [ "${MERGEABLE}" = "false" ] || [ "${MERGEABLE_STATE}" = "dirty" ]; then
  log_hook_event "PreToolUse" "validate-pr-merge" "blocked" \
    "{\"pr\": ${PR_NUM}, \"reason\": \"conflicts\"}"
  cat >&2 <<EOF
MERGE BLOCKED

PR #${PR_NUM} has merge conflicts.

Resolve conflicts before merging:
1. git fetch origin
2. git rebase origin/main (or merge)
3. Resolve conflicts
4. git push --force-with-lease
EOF
  exit 2
fi

# Check CI status - get failed or pending checks
CHECKS_JSON=$(get_pr_checks_json "${REPO}" "${PR_NUM}" 2>/dev/null || echo "[]")
FAILED_CHECKS=$(echo "${CHECKS_JSON}" | jq -r '[.[] | select(.conclusion == "FAILURE")] | length')
PENDING_CHECKS=$(echo "${CHECKS_JSON}" | jq -r '[.[] | select(.state == "PENDING")] | length')

if [ "${FAILED_CHECKS}" != "0" ] && [ -n "${FAILED_CHECKS}" ]; then
  log_hook_event "PreToolUse" "validate-pr-merge" "blocked" \
    "{\"pr\": ${PR_NUM}, \"reason\": \"ci_failed\", \"failed_checks\": ${FAILED_CHECKS}}"
  cat >&2 <<EOF
MERGE BLOCKED

PR #${PR_NUM} has ${FAILED_CHECKS} failing CI checks.

Run 'gh pr checks ${PR_NUM}' to see status.
Fix failures before merging.
EOF
  exit 2
fi

if [ "${PENDING_CHECKS}" != "0" ] && [ -n "${PENDING_CHECKS}" ]; then
  log_hook_event "PreToolUse" "validate-pr-merge" "blocked" \
    "{\"pr\": ${PR_NUM}, \"reason\": \"ci_pending\", \"pending_checks\": ${PENDING_CHECKS}}"
  cat >&2 <<EOF
MERGE BLOCKED

PR #${PR_NUM} has ${PENDING_CHECKS} pending CI checks.

Wait for CI to complete before merging.
Run 'gh pr checks ${PR_NUM}' to monitor status.
EOF
  exit 2
fi

log_hook_event "PreToolUse" "validate-pr-merge" "allowed" "{\"pr\": ${PR_NUM}}"
exit 0
