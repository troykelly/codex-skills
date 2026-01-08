#!/usr/bin/env bash
# Stop hook to check CI status before allowing session to end
#
# Blocks stopping if there are PRs with running or failed CI that
# haven't been addressed.
#
# Exit codes:
#   0 = Allow stop
#   2 = Block stop (message fed back to Codex for self-correction)

set -euo pipefail

# Source logging utility if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log-event.sh
if [ -f "${SCRIPT_DIR}/lib/log-event.sh" ]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/log-event.sh"
fi

log_hook_event "Stop" "check-ci-before-stop" "started" "{}"

# Check if we're in a git repository
if ! git rev-parse --git-dir &>/dev/null 2>&1; then
  log_hook_event "Stop" "check-ci-before-stop" "skipped" '{"reason": "not a git repo"}'
  exit 0
fi

# Check if gh CLI is available
if ! command -v gh &>/dev/null; then
  log_hook_event "Stop" "check-ci-before-stop" "skipped" '{"reason": "gh not available"}'
  exit 0
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
if [ -z "${REPO}" ]; then
  log_hook_event "Stop" "check-ci-before-stop" "skipped" '{"reason": "not a github repo"}'
  exit 0
fi

# Get current user for author filtering
CURRENT_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")

# Check for ALL open PRs in the repo (not just current branch)
# This catches PRs created during this session from any feature branch
if [ -n "${CURRENT_USER}" ]; then
  # Filter to PRs authored by current user
  OPEN_PRS=$(gh pr list --author "${CURRENT_USER}" --state open --json number,title,headRefName 2>/dev/null || echo "[]")
else
  # Fallback to all open PRs if we can't determine user
  OPEN_PRS=$(gh pr list --state open --json number,title,headRefName 2>/dev/null || echo "[]")
fi
PR_COUNT=$(echo "${OPEN_PRS}" | jq 'length')

if [ "${PR_COUNT}" = "0" ]; then
  # No open PRs - allow stop
  log_hook_event "Stop" "check-ci-before-stop" "completed" '{"status": "no open PRs"}'
  exit 0
fi

# Check CI status for each open PR
running_prs=()
failed_prs=()
passed_prs=()

format_pr_list() {
  local out=""
  local pr
  for pr in "$@"; do
    out+="#${pr} "
  done
  printf '%s' "${out% }"
}

while IFS= read -r pr_num; do
  [[ -n "${pr_num}" ]] || continue
  CHECKS_JSON=$(gh pr checks "${pr_num}" --json name,state,conclusion 2>/dev/null || echo "[]")

  if [ "${CHECKS_JSON}" = "[]" ]; then
    continue
  fi

  PENDING=$(echo "${CHECKS_JSON}" | jq 'any(.[]; .state == "PENDING")')
  FAILED=$(echo "${CHECKS_JSON}" | jq 'any(.[]; .conclusion == "FAILURE")')
  ALL_SUCCESS=$(echo "${CHECKS_JSON}" | jq 'all(.[]; .conclusion == "SUCCESS")')

  if [ "${PENDING}" = "true" ]; then
    running_prs+=("${pr_num}")
  elif [ "${FAILED}" = "true" ]; then
    failed_prs+=("${pr_num}")
  elif [ "${ALL_SUCCESS}" = "true" ]; then
    passed_prs+=("${pr_num}")
  fi
done < <(echo "${OPEN_PRS}" | jq -r '.[].number')

# If there are running PRs, block stop
if [ "${#running_prs[@]}" -gt 0 ]; then
  running_prs_text=$(format_pr_list "${running_prs[@]}")
  cat >&2 <<EOF
CI MONITORING GATE

Cannot stop: CI is still running for PRs: ${running_prs_text}

Required action:
1. Wait for CI to complete: gh pr checks [PR_NUMBER] --watch
2. If CI passes, you may stop
3. If CI fails, fix the failures before stopping

PRs must have green CI before ending the session.
EOF

  log_hook_event "Stop" "check-ci-before-stop" "blocked" \
    "$(json_obj "reason" "ci_running" "prs" "${running_prs_text}")"
  exit 2
fi

# If there are failed PRs without documentation, block stop
if [ "${#failed_prs[@]}" -gt 0 ]; then
  # Check if failures are documented in PR comments
  undocumented_failures=()

  for pr_num in "${failed_prs[@]}"; do
    # Check for CI failure documentation comment
    DOCUMENTED=$(gh api "/repos/${REPO}/pulls/${pr_num}/comments" \
      --jq '[.[] | select(.body | test("CI (Failed|Failure|Issue)"; "i"))] | length' 2>/dev/null || echo "0")

    # Also check issue comments
    ISSUE_DOCUMENTED=$(gh api "/repos/${REPO}/issues/${pr_num}/comments" \
      --jq '[.[] | select(.body | test("CI (Failed|Failure|Issue)"; "i"))] | length' 2>/dev/null || echo "0")

    if [ "${DOCUMENTED}" = "0" ] && [ "${ISSUE_DOCUMENTED}" = "0" ]; then
      undocumented_failures+=("${pr_num}")
    fi
  done

  if [ "${#undocumented_failures[@]}" -gt 0 ]; then
    undocumented_failures_text=$(format_pr_list "${undocumented_failures[@]}")
    cat >&2 <<EOF
CI MONITORING GATE

Cannot stop: CI has failures that are not documented: ${undocumented_failures_text}

Required action:
1. Investigate failures: gh run view [RUN_ID] --log-failed
2. Either:
   a. Fix the failures and push, OR
   b. Document the issue if unfixable (comment on PR explaining why)
3. Retry stopping after addressing failures

All CI failures must be fixed or documented before ending the session.
EOF

    log_hook_event "Stop" "check-ci-before-stop" "blocked" \
      "$(json_obj "reason" "undocumented_failures" "prs" "${undocumented_failures_text}")"
    exit 2
  fi

  # Failures are documented - allow but warn
  failed_prs_text=$(format_pr_list "${failed_prs[@]}")
  echo "⚠️ Warning: PRs ${failed_prs_text}have failing CI but failures are documented." >&2
fi

# All checks passed or failures documented
passed_prs_text=$(format_pr_list "${passed_prs[@]}")
failed_prs_text="${failed_prs_text:-$(format_pr_list "${failed_prs[@]}")}"
log_hook_event "Stop" "check-ci-before-stop" "completed" \
  "$(json_obj "passed_prs" "${passed_prs_text}" "failed_prs" "${failed_prs_text}")"

exit 0
