#!/usr/bin/env bash
# GitHub-based state management for orchestration
#
# Provides functions to read/write state to GitHub Issues and Project Board.
# This eliminates the need for local state files, ensuring state survives crashes.
#
# Usage:
#   source lib/github-state.sh
#   TRACKING_ISSUE=123
#   set_orchestration_state "running" '{"current_phase": "implementation"}'
#   state=$(get_orchestration_state)
#
# Requirements:
#   - gh CLI authenticated
#   - GITHUB_REPO or auto-detect from git remote
#   - jq for JSON processing

set -euo pipefail

# Source logging if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=log-event.sh
if [ -f "$SCRIPT_DIR/log-event.sh" ]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/log-event.sh"
fi

# Structured comment markers
readonly STATE_MARKER_START="<!-- ORCHESTRATION:STATE -->"
readonly STATE_MARKER_END="<!-- /ORCHESTRATION:STATE -->"
readonly WORKER_MARKER_START="<!-- WORKER:ASSIGNED -->"
readonly WORKER_MARKER_END="<!-- /WORKER:ASSIGNED -->"
readonly HANDOVER_MARKER_START="<!-- HANDOVER:START -->"
readonly HANDOVER_MARKER_END="<!-- HANDOVER:END -->"
readonly SLEEP_MARKER_START="<!-- ORCHESTRATION:SLEEP -->"
readonly SLEEP_MARKER_END="<!-- /ORCHESTRATION:SLEEP -->"

# Get repository from environment or git remote
get_repo() {
  if [ -n "${GITHUB_REPO:-}" ]; then
    echo "$GITHUB_REPO"
    return 0
  fi
  if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    echo "$GITHUB_REPOSITORY"
    return 0
  fi
  if [ -n "${GH_REPO:-}" ]; then
    echo "$GH_REPO"
    return 0
  fi
  if [ -n "${CODEX_REPO_CACHE:-}" ]; then
    echo "$CODEX_REPO_CACHE"
    return 0
  fi

  local remote repo
  remote=$(git remote get-url origin 2>/dev/null || git config --get remote.origin.url 2>/dev/null || echo "")
  repo=""

  case "$remote" in
    git@*:* )
      repo="${remote#*:}"
      ;;
    ssh://git@*/* )
      repo="${remote#ssh://git@*/}"
      ;;
    https://*/* )
      repo="${remote#https://*/}"
      ;;
    http://*/* )
      repo="${remote#http://*/}"
      ;;
    git://*/* )
      repo="${remote#git://*/}"
      ;;
  esac

  repo="${repo%.git}"
  if [[ "$repo" == [0-9]*/* ]]; then
    repo="${repo#*/}"
  fi

  if [ -n "$repo" ] && [[ "$repo" == */* ]]; then
    CODEX_REPO_CACHE="$repo"
    export CODEX_REPO_CACHE
    echo "$repo"
    return 0
  fi

  if command -v gh &>/dev/null; then
    repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
    if [ -n "$repo" ]; then
      CODEX_REPO_CACHE="$repo"
      export CODEX_REPO_CACHE
      echo "$repo"
      return 0
    fi
  fi
}

# Get owner and repo separately
get_owner_repo() {
  local repo
  repo=$(get_repo)
  if [ -n "$repo" ]; then
    echo "$repo" | tr '/' ' '
  fi
}

# Get PR check summary via REST (avoids GraphQL usage in gh cli commands).
# Arguments:
#   $1 - owner/repo
#   $2 - PR number
get_pr_checks_json() {
  local repo="${1:-}"
  local pr_number="${2:-}"

  if [ -z "$repo" ] || [ -z "$pr_number" ]; then
    echo "[]"
    return 0
  fi

  local pr_json sha
  pr_json=$(gh api "/repos/$repo/pulls/$pr_number" 2>/dev/null || echo "")
  sha=$(echo "$pr_json" | jq -r '.head.sha // empty' 2>/dev/null || echo "")

  if [ -z "$sha" ]; then
    echo "[]"
    return 0
  fi

  local check_runs statuses
  check_runs=$(gh api "/repos/$repo/commits/$sha/check-runs" \
    -H "Accept: application/vnd.github+json" \
    --jq '.check_runs // []' 2>/dev/null || echo "[]")
  statuses=$(gh api "/repos/$repo/commits/$sha/status" \
    --jq '.statuses // []' 2>/dev/null || echo "[]")

  jq -cn \
    --argjson check_runs "$check_runs" \
    --argjson statuses "$statuses" \
    '($check_runs // [] | map({
      name: .name,
      state: (if .status == "completed" then "COMPLETED" else "PENDING" end),
      conclusion: (if .status != "completed" then "PENDING"
                   elif .conclusion == "success" then "SUCCESS"
                   else "FAILURE" end)
    })) + ($statuses // [] | map({
      name: .context,
      state: (if .state == "pending" then "PENDING" else "COMPLETED" end),
      conclusion: (if .state == "pending" then "PENDING"
                   elif .state == "success" then "SUCCESS"
                   else "FAILURE" end)
    }))' || echo "[]"
}

# Check GitHub API rate limits via REST.
# Arguments:
#   $1 - GraphQL remaining minimum (optional, default: GITHUB_GRAPHQL_MIN_REMAINING or 100)
#   $2 - REST remaining minimum (optional, default: GITHUB_REST_MIN_REMAINING or 100)
# Returns:
#   0 if limits are above thresholds, 1 otherwise
check_rate_limits() {
  local graphql_min="${1:-${GITHUB_GRAPHQL_MIN_REMAINING:-100}}"
  local rest_min="${2:-${GITHUB_REST_MIN_REMAINING:-100}}"

  if ! command -v gh &>/dev/null; then
    echo "GitHub rate limit check skipped: gh not available"
    return 1
  fi

  local rate_json
  rate_json=$(gh api rate_limit 2>/dev/null || echo "")
  if [ -z "$rate_json" ] || [ "$rate_json" = "null" ]; then
    echo "GitHub rate limit check unavailable"
    return 1
  fi

  local graphql_remaining graphql_limit graphql_reset
  local rest_remaining rest_limit rest_reset
  graphql_remaining=$(echo "$rate_json" | jq -r '.resources.graphql.remaining // 0')
  graphql_limit=$(echo "$rate_json" | jq -r '.resources.graphql.limit // 0')
  graphql_reset=$(echo "$rate_json" | jq -r '.resources.graphql.reset // 0')
  rest_remaining=$(echo "$rate_json" | jq -r '.resources.core.remaining // 0')
  rest_limit=$(echo "$rate_json" | jq -r '.resources.core.limit // 0')
  rest_reset=$(echo "$rate_json" | jq -r '.resources.core.reset // 0')

  echo "GitHub API rate limits: GraphQL ${graphql_remaining}/${graphql_limit}, REST ${rest_remaining}/${rest_limit}"

  local ok=true
  local now wait_seconds
  now=$(date -u +%s)

  if [ "$graphql_remaining" -lt "$graphql_min" ]; then
    ok=false
    wait_seconds=$((graphql_reset - now))
    if [ "$wait_seconds" -gt 0 ]; then
      echo "GraphQL remaining below ${graphql_min}; resets in ${wait_seconds}s"
    else
      echo "GraphQL remaining below ${graphql_min}; reset time unknown"
    fi
  fi

  if [ "$rest_remaining" -lt "$rest_min" ]; then
    ok=false
    wait_seconds=$((rest_reset - now))
    if [ "$wait_seconds" -gt 0 ]; then
      echo "REST remaining below ${rest_min}; resets in ${wait_seconds}s"
    else
      echo "REST remaining below ${rest_min}; reset time unknown"
    fi
  fi

  if [ "$ok" = "true" ]; then
    return 0
  fi
  return 1
}

# Extract JSON from a structured comment block
# Arguments:
#   $1 - Full comment body text
#   $2 - Start marker
#   $3 - End marker
extract_json_from_comment() {
  local body="$1"
  local start_marker="$2"
  local end_marker="$3"

  # Use awk to extract content between markers
  echo "$body" | awk -v start="$start_marker" -v end="$end_marker" '
    BEGIN { found=0; json="" }
    $0 ~ start { found=1; next }
    $0 ~ end { found=0 }
    found { json = json $0 "\n" }
    END { print json }
  ' | jq -c '.' 2>/dev/null || echo "{}"
}

# Find the latest comment containing a specific marker
# Arguments:
#   $1 - Issue number
#   $2 - Marker to search for
find_comment_with_marker() {
  local issue_number="$1"
  local marker="$2"
  local repo
  repo=$(get_repo)

  if [ -z "$repo" ]; then
    echo ""
    return 1
  fi

  # Get all comments and find the latest with the marker
  gh api "/repos/$repo/issues/$issue_number/comments" \
    --jq "map(select(.body | contains(\"$marker\"))) | last // empty" 2>/dev/null || echo ""
}

# ============================================================================
# Orchestration State Functions
# ============================================================================

# Get the current orchestration state from the tracking issue
# Arguments:
#   $1 - Tracking issue number
# Returns: JSON object with state data
get_orchestration_state() {
  local issue_number="${1:-${TRACKING_ISSUE:-}}"

  if [ -z "$issue_number" ]; then
    echo '{"error": "no tracking issue specified"}'
    return 1
  fi

  local comment
  comment=$(find_comment_with_marker "$issue_number" "$STATE_MARKER_START")

  if [ -z "$comment" ]; then
    # No state comment found, return default
    echo '{"status": "unknown", "initialized": false}'
    return 0
  fi

  local body
  body=$(echo "$comment" | jq -r '.body // ""')
  extract_json_from_comment "$body" "$STATE_MARKER_START" "$STATE_MARKER_END"
}

# Set the orchestration state by posting/updating a comment
# Arguments:
#   $1 - Status (running, sleeping, stopped, error)
#   $2 - Additional state JSON (optional)
#   $3 - Tracking issue number (optional, uses TRACKING_ISSUE env)
set_orchestration_state() {
  local status="$1"
  local state_json="${2:-"{}"}"
  local issue_number="${3:-${TRACKING_ISSUE:-}}"

  if [ -z "$issue_number" ]; then
    log_hook_event "StateWrite" "github-state" "error" '{"reason": "no tracking issue"}'
    return 1
  fi

  local repo
  repo=$(get_repo)
  if [ -z "$repo" ]; then
    log_hook_event "StateWrite" "github-state" "error" '{"reason": "no repo"}'
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build the full state JSON
  local full_state
  full_state=$(jq -cn \
    --arg status "$status" \
    --arg ts "$timestamp" \
    --argjson data "$state_json" \
    '{
      status: $status,
      updated_at: $ts,
      data: $data
    }')

  # Format the comment body
  local comment_body
  comment_body=$(cat <<EOF
$STATE_MARKER_START
\`\`\`json
$full_state
\`\`\`
$STATE_MARKER_END

**Orchestration Status:** $status
**Updated:** $timestamp
EOF
)

  # Check if we should update existing or create new
  local existing_comment
  existing_comment=$(find_comment_with_marker "$issue_number" "$STATE_MARKER_START")

  if [ -n "$existing_comment" ]; then
    local comment_id
    comment_id=$(echo "$existing_comment" | jq -r '.id')
    gh api "/repos/$repo/issues/comments/$comment_id" \
      -X PATCH \
      -f body="$comment_body" >/dev/null 2>&1
  else
    gh api "/repos/$repo/issues/$issue_number/comments" \
      -X POST \
      -f body="$comment_body" >/dev/null 2>&1
  fi

  log_hook_event "StateWrite" "github-state" "success" \
    "$(json_obj "issue" "$issue_number" "status" "$status")"
}

# ============================================================================
# Worker Assignment Functions
# ============================================================================

# Get worker assignment for an issue
# Arguments:
#   $1 - Issue number
get_worker_assignment() {
  local issue_number="$1"

  if [ -z "$issue_number" ]; then
    echo '{"error": "no issue specified"}'
    return 1
  fi

  local comment
  comment=$(find_comment_with_marker "$issue_number" "$WORKER_MARKER_START")

  if [ -z "$comment" ]; then
    echo '{"assigned": false}'
    return 0
  fi

  local body
  body=$(echo "$comment" | jq -r '.body // ""')
  extract_json_from_comment "$body" "$WORKER_MARKER_START" "$WORKER_MARKER_END"
}

# Assign a worker to an issue
# Arguments:
#   $1 - Issue number
#   $2 - Worker ID/session ID
#   $3 - Additional worker data JSON (optional)
set_worker_assignment() {
  local issue_number="$1"
  local worker_id="$2"
  local worker_data="${3:-"{}"}"

  if [ -z "$issue_number" ] || [ -z "$worker_id" ]; then
    return 1
  fi

  local repo
  repo=$(get_repo)
  if [ -z "$repo" ]; then
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local assignment_json
  assignment_json=$(jq -cn \
    --arg worker "$worker_id" \
    --arg ts "$timestamp" \
    --argjson data "$worker_data" \
    '{
      assigned: true,
      worker_id: $worker,
      assigned_at: $ts,
      data: $data
    }')

  local comment_body
  comment_body=$(cat <<EOF
$WORKER_MARKER_START
\`\`\`json
$assignment_json
\`\`\`
$WORKER_MARKER_END

**Worker Assigned:** \`$worker_id\`
**Assigned At:** $timestamp
EOF
)

  gh api "/repos/$repo/issues/$issue_number/comments" \
    -X POST \
    -f body="$comment_body" >/dev/null 2>&1

  log_hook_event "WorkerAssign" "github-state" "success" \
    "$(json_obj "issue" "$issue_number" "worker" "$worker_id")"
}

# Clear worker assignment from an issue
# Arguments:
#   $1 - Issue number
clear_worker_assignment() {
  local issue_number="$1"
  local repo
  repo=$(get_repo)

  if [ -z "$repo" ] || [ -z "$issue_number" ]; then
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local clear_json='{"assigned": false, "cleared_at": "'"$timestamp"'"}'

  local comment_body
  comment_body=$(cat <<EOF
$WORKER_MARKER_START
\`\`\`json
$clear_json
\`\`\`
$WORKER_MARKER_END

**Worker Assignment Cleared**
**Cleared At:** $timestamp
EOF
)

  gh api "/repos/$repo/issues/$issue_number/comments" \
    -X POST \
    -f body="$comment_body" >/dev/null 2>&1
}

# ============================================================================
# Handover Context Functions
# ============================================================================

# Get handover context for an issue
# Arguments:
#   $1 - Issue number
get_handover_context() {
  local issue_number="$1"

  if [ -z "$issue_number" ]; then
    echo '{"error": "no issue specified"}'
    return 1
  fi

  local comment
  comment=$(find_comment_with_marker "$issue_number" "$HANDOVER_MARKER_START")

  if [ -z "$comment" ]; then
    echo '{"has_handover": false}'
    return 0
  fi

  # Extract the full handover content (not just JSON)
  local body
  body=$(echo "$comment" | jq -r '.body // ""')

  # For handover, we return the markdown content, not parsed JSON
  local content
  content=$(echo "$body" | awk -v start="$HANDOVER_MARKER_START" -v end="$HANDOVER_MARKER_END" '
    BEGIN { found=0 }
    $0 ~ start { found=1; next }
    $0 ~ end { found=0 }
    found { print }
  ')

  # Return as JSON with content field
  jq -cn --arg content "$content" '{"has_handover": true, "content": $content}'
}

# Set handover context for an issue
# Arguments:
#   $1 - Issue number
#   $2 - Handover markdown content
#   $3 - Previous session ID (optional)
set_handover_context() {
  local issue_number="$1"
  local content="$2"
  local prev_session="${3:-}"

  if [ -z "$issue_number" ] || [ -z "$content" ]; then
    return 1
  fi

  local repo
  repo=$(get_repo)
  if [ -z "$repo" ]; then
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local comment_body
  comment_body=$(cat <<EOF
$HANDOVER_MARKER_START

## Handover Context

**Created:** $timestamp
${prev_session:+**Previous Session:** \`$prev_session\`}

---

$content

$HANDOVER_MARKER_END
EOF
)

  gh api "/repos/$repo/issues/$issue_number/comments" \
    -X POST \
    -f body="$comment_body" >/dev/null 2>&1

  log_hook_event "Handover" "github-state" "created" \
    "$(json_obj "issue" "$issue_number")"
}

# ============================================================================
# Sleep Status Functions
# ============================================================================

# Get sleep status from tracking issue
# Arguments:
#   $1 - Tracking issue number
get_sleep_status() {
  local issue_number="${1:-${TRACKING_ISSUE:-}}"

  if [ -z "$issue_number" ]; then
    echo '{"sleeping": false, "error": "no tracking issue"}'
    return 1
  fi

  local comment
  comment=$(find_comment_with_marker "$issue_number" "$SLEEP_MARKER_START")

  if [ -z "$comment" ]; then
    echo '{"sleeping": false}'
    return 0
  fi

  local body
  body=$(echo "$comment" | jq -r '.body // ""')
  extract_json_from_comment "$body" "$SLEEP_MARKER_START" "$SLEEP_MARKER_END"
}

# Set orchestration to sleep
# Arguments:
#   $1 - Reason for sleeping
#   $2 - PRs to wait on (comma-separated or JSON array)
#   $3 - Resume session ID (optional)
#   $4 - Tracking issue number (optional)
set_sleep_status() {
  local reason="$1"
  local waiting_prs="$2"
  local resume_session="${3:-}"
  local issue_number="${4:-${TRACKING_ISSUE:-}}"

  if [ -z "$issue_number" ]; then
    return 1
  fi

  local repo
  repo=$(get_repo)
  if [ -z "$repo" ]; then
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Convert comma-separated to JSON array if needed
  local prs_array
  if echo "$waiting_prs" | jq -e '.' >/dev/null 2>&1; then
    prs_array="$waiting_prs"
  else
    prs_array=$(echo "$waiting_prs" | tr ',' '\n' | jq -R '.' | jq -s '.')
  fi

  local sleep_json
  sleep_json=$(jq -cn \
    --arg reason "$reason" \
    --arg ts "$timestamp" \
    --arg resume "$resume_session" \
    --argjson prs "$prs_array" \
    '{
      sleeping: true,
      reason: $reason,
      since: $ts,
      waiting_on: $prs,
      resume_session: (if $resume != "" then $resume else null end)
    }')

  local comment_body
  comment_body=$(cat <<EOF
$SLEEP_MARKER_START
\`\`\`json
$sleep_json
\`\`\`
$SLEEP_MARKER_END

**Orchestration Sleeping**
- **Reason:** $reason
- **Since:** $timestamp
- **Waiting On:** $waiting_prs
${resume_session:+- **Resume Session:** \`$resume_session\`}
EOF
)

  # Check if we should update existing or create new
  local existing_comment
  existing_comment=$(find_comment_with_marker "$issue_number" "$SLEEP_MARKER_START")

  if [ -n "$existing_comment" ]; then
    local comment_id
    comment_id=$(echo "$existing_comment" | jq -r '.id')
    gh api "/repos/$repo/issues/comments/$comment_id" \
      -X PATCH \
      -f body="$comment_body" >/dev/null 2>&1
  else
    gh api "/repos/$repo/issues/$issue_number/comments" \
      -X POST \
      -f body="$comment_body" >/dev/null 2>&1
  fi

  log_hook_event "Sleep" "github-state" "sleeping" \
    "$(json_obj "issue" "$issue_number" "reason" "$reason")"
}

# Wake orchestration from sleep
# Arguments:
#   $1 - Wake reason
#   $2 - Tracking issue number (optional)
wake_from_sleep() {
  local wake_reason="$1"
  local issue_number="${2:-${TRACKING_ISSUE:-}}"

  if [ -z "$issue_number" ]; then
    return 1
  fi

  local repo
  repo=$(get_repo)
  if [ -z "$repo" ]; then
    return 1
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local wake_json
  wake_json=$(jq -cn \
    --arg reason "$wake_reason" \
    --arg ts "$timestamp" \
    '{
      sleeping: false,
      wake_reason: $reason,
      woke_at: $ts
    }')

  local comment_body
  comment_body=$(cat <<EOF
$SLEEP_MARKER_START
\`\`\`json
$wake_json
\`\`\`
$SLEEP_MARKER_END

**Orchestration Awake**
- **Wake Reason:** $wake_reason
- **Woke At:** $timestamp
EOF
)

  # Update existing sleep comment
  local existing_comment
  existing_comment=$(find_comment_with_marker "$issue_number" "$SLEEP_MARKER_START")

  if [ -n "$existing_comment" ]; then
    local comment_id
    comment_id=$(echo "$existing_comment" | jq -r '.id')
    gh api "/repos/$repo/issues/comments/$comment_id" \
      -X PATCH \
      -f body="$comment_body" >/dev/null 2>&1
  else
    gh api "/repos/$repo/issues/$issue_number/comments" \
      -X POST \
      -f body="$comment_body" >/dev/null 2>&1
  fi

  log_hook_event "Sleep" "github-state" "awake" \
    "$(json_obj "issue" "$issue_number" "reason" "$wake_reason")"
}

# ============================================================================
# Project Board Status Functions
# ============================================================================

# Get issue status from project board
# Arguments:
#   $1 - Issue number
#   $2 - Project number (optional, uses GITHUB_PROJECT env)
get_project_status() {
  local issue_number="$1"
  local project="${2:-${GITHUB_PROJECT:-}}"

  if [ -z "$issue_number" ]; then
    echo ""
    return 1
  fi

  local repo
  repo=$(get_repo)
  if [ -z "$repo" ]; then
    return 1
  fi

  # Get the issue's project item and status
  gh issue view "$issue_number" --repo "$repo" \
    --json projectItems \
    --jq '.projectItems[] | select(.project.number == '"$project"') | .status.name // ""' 2>/dev/null | head -1
}

# Update issue status on project board
# Arguments:
#   $1 - Issue number
#   $2 - New status value
#   $3 - Project number (optional)
set_project_status() {
  local issue_number="$1"
  local new_status="$2"
  local project="${3:-${GITHUB_PROJECT:-}}"

  if [ -z "$issue_number" ] || [ -z "$new_status" ]; then
    return 1
  fi

  local repo
  repo=$(get_repo)
  if [ -z "$repo" ]; then
    return 1
  fi

  # This requires GraphQL mutation - for now, log and return
  # The actual implementation would use gh api graphql
  log_hook_event "ProjectStatus" "github-state" "requested" \
    "$(json_obj "issue" "$issue_number" "status" "$new_status")"

  # Note: Full implementation requires GraphQL mutation
  # gh api graphql -f query='mutation { updateProjectV2ItemFieldValue(...) }'
  echo "Project status update requested: issue #$issue_number -> $new_status"
}
