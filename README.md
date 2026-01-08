# Issue-Driven Development (Codex)

A Codex CLI skill pack for autonomous, GitHub-native software development: work through issues, create PRs, and ship code with a disciplined workflow (TDD, strict typing, review gates, CI monitoring, and more).

This repository is a Codex-focused port of the original `claude-skills` project.

---

## Quick Start

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/troykelly/codex-skills/main/install.sh | bash
```

Installs:

- Helper CLIs: `codex-autonomous`, `codex-account`, `codex-hook-runner`, `codex-subagent`
- Skills into `$CODEX_HOME/skills` (defaults to `~/.codex/skills`)
- Hooks into `$CODEX_HOME/hooks` (for `codex-hook-runner`, optional)
- MCP server stubs in `$CODEX_HOME/config.toml` (optional, controlled by `SKIP_MCP=true`)

### First Use

```bash
codex login
gh auth login
codex-autonomous
```

---

## What’s Included

### CLI Tools

| Tool               | Purpose                                                                     |
| ------------------ | --------------------------------------------------------------------------- |
| `codex-autonomous` | Autonomous development with crash recovery and git worktree isolation       |
| `codex-account`    | Multi-account switching by snapshotting `$CODEX_HOME/auth.json` into `.env` |
| `codex-hook-runner` | Opt-in hook runner that emits `hooks.json` events via `codex exec --json`   |
| `codex-subagent`   | Run agent cards as subagents using a consistent invocation pattern          |

Opinionated defaults:
- All provided CLIs run Codex with `--dangerously-bypass-approvals-and-sandbox` and never enable sandboxing.

### codex-autonomous

```bash
codex-autonomous --new
```

Notes:
- `--new` prompts for instructions before starting Codex.
- Set `CODEX_NEW_PROMPT` to skip the interactive prompt (useful for scripts).

### Skills

- `skills/` contains the core workflow skills (ported from `claude-skills`)
- `external/skills/` contains imported external skills with documented provenance (see `EXTERNAL_SOURCES.md`)
- Codex translations of plugin-dev guidance live in `external/skills/agent-development`, `external/skills/hook-development`, and `external/skills/skill-development`
- `hooks/` contains the Codex hook scripts and `hooks.json` used by `codex-hook-runner`

---

## Hook Runner (Opt-in)

Codex CLI has no native hook events. Use `codex-hook-runner` to emit hook events from `hooks/hooks.json`.

Hooks are enabled by default for `codex-autonomous`. Disable with:

```bash
export CODEX_DISABLE_HOOKS=1
codex-autonomous
```

Run manually:

```bash
codex-hook-runner exec "Your prompt"
```

Notes:
- Hook runner uses `codex exec --json` and writes a JSONL transcript (default: `.codex/logs/`)
- Hook runner output is prettified by default; set `CODEX_HOOK_OUTPUT=json` for raw JSON
- Set `CODEX_HOOK_SHOW_REASONING=true` or `CODEX_HOOK_SHOW_USAGE=true` to include extra details
- `codex-autonomous` uses `codex exec` when hooks are enabled (pretty output by default)
- Override locations with `CODEX_HOOK_ROOT` and `CODEX_HOOK_CONFIG`
- Control prompt hooks with `CODEX_HOOK_PROMPT_MODE=codex|print|skip`

---

## Subagents (Claude-like)

Codex does not auto-discover agent cards. Use `codex-subagent` to run agent cards with a consistent subagent invocation pattern.

```bash
codex-subagent code-reviewer <<'EOF'
Review issue #123 changes for clarity, correctness, and security. Focus on auth and API layers.
EOF
```

Notes:
- Agent cards live in `agents/` and `external/agents/` (override with `CODEX_AGENT_PATHS`)
- The runner uses `profile` or `model` from the agent card frontmatter
- Override with `--profile` or `--model` when needed
- The installer appends default subagent profiles to `$CODEX_HOME/config.toml` (idempotent)

---

## Migration Map (Claude -> Codex)

Mapping from original `claude-skills` artifacts to their Codex equivalents. Status indicates whether the item is ported, imported (manual updates), or not supported in Codex.

### Core Skills

| Claude skill                              | Codex skill                               | Status/Notes |
| ----------------------------------------- | ----------------------------------------- | ------------ |
| `skills/acceptance-criteria-verification` | `skills/acceptance-criteria-verification` | Ported       |
| `skills/api-documentation`                | `skills/api-documentation`                | Ported       |
| `skills/apply-all-findings`               | `skills/apply-all-findings`               | Ported       |
| `skills/autonomous-operation`             | `skills/autonomous-operation`             | Ported       |
| `skills/autonomous-orchestration`         | `skills/autonomous-orchestration`         | Ported       |
| `skills/branch-discipline`                | `skills/branch-discipline`                | Ported       |
| `skills/ci-monitoring`                    | `skills/ci-monitoring`                    | Ported       |
| `skills/clean-commits`                    | `skills/clean-commits`                    | Ported       |
| `skills/comprehensive-review`             | `skills/comprehensive-review`             | Ported       |
| `skills/conflict-resolution`              | `skills/conflict-resolution`              | Ported       |
| `skills/database-architecture`            | `skills/database-architecture`            | Ported       |
| `skills/deferred-finding`                 | `skills/deferred-finding`                 | Ported       |
| `skills/documentation-audit`              | `skills/documentation-audit`              | Ported       |
| `skills/environment-bootstrap`            | `skills/environment-bootstrap`            | Ported       |
| `skills/epic-management`                  | `skills/epic-management`                  | Ported       |
| `skills/error-recovery`                   | `skills/error-recovery`                   | Ported       |
| `skills/features-documentation`           | `skills/features-documentation`           | Ported       |
| `skills/feedback-triage`                  | `skills/feedback-triage`                  | Ported       |
| `skills/inclusive-language`               | `skills/inclusive-language`               | Ported       |
| `skills/initiative-architecture`          | `skills/initiative-architecture`          | Ported       |
| `skills/inline-documentation`             | `skills/inline-documentation`             | Ported       |
| `skills/ipv6-first`                       | `skills/ipv6-first`                       | Ported       |
| `skills/issue-decomposition`              | `skills/issue-decomposition`              | Ported       |
| `skills/issue-driven-development`         | `skills/issue-driven-development`         | Ported       |
| `skills/issue-lifecycle`                  | `skills/issue-lifecycle`                  | Ported       |
| `skills/issue-prerequisite`               | `skills/issue-prerequisite`               | Ported       |
| `skills/local-service-testing`            | `skills/local-service-testing`            | Ported       |
| `skills/memory-integration`               | `skills/memory-integration`               | Ported       |
| `skills/milestone-management`             | `skills/milestone-management`             | Ported       |
| `skills/no-deferred-work`                 | `skills/no-deferred-work`                 | Ported       |
| `skills/pexels-media`                     | `skills/pexels-media`                     | Ported       |
| `skills/postgis`                          | `skills/postgis`                          | Ported       |
| `skills/postgres-rls`                     | `skills/postgres-rls`                     | Ported       |
| `skills/pr-creation`                      | `skills/pr-creation`                      | Ported       |
| `skills/pre-work-research`                | `skills/pre-work-research`                | Ported       |
| `skills/project-board-enforcement`        | `skills/project-board-enforcement`        | Ported       |
| `skills/project-status-sync`              | `skills/project-status-sync`              | Ported       |
| `skills/research-after-failure`           | `skills/research-after-failure`           | Ported       |
| `skills/review-gate`                      | `skills/review-gate`                      | Ported       |
| `skills/review-scope`                     | `skills/review-scope`                     | Ported       |
| `skills/security-review`                  | `skills/security-review`                  | Ported       |
| `skills/session-start`                    | `skills/session-start`                    | Ported       |
| `skills/strict-typing`                    | `skills/strict-typing`                    | Ported       |
| `skills/style-guide-adherence`            | `skills/style-guide-adherence`            | Ported       |
| `skills/tdd-full-coverage`                | `skills/tdd-full-coverage`                | Ported       |
| `skills/timescaledb`                      | `skills/timescaledb`                      | Ported       |
| `skills/verification-before-merge`        | `skills/verification-before-merge`        | Ported       |
| `skills/work-intake`                      | `skills/work-intake`                      | Ported       |
| `skills/worker-dispatch`                  | `skills/worker-dispatch`                  | Ported       |
| `skills/worker-handover`                  | `skills/worker-handover`                  | Ported       |
| `skills/worker-protocol`                  | `skills/worker-protocol`                  | Ported       |

### Codex-only Skills (Subagent Wrappers)

| Claude skill | Codex skill | Status/Notes |
| ------------ | ----------- | ------------ |
| n/a | `skills/code-reviewer` | New (wraps `agents/code-reviewer.md`) |
| n/a | `skills/security-reviewer` | New (wraps `agents/security-reviewer.md`) |
| n/a | `skills/code-architect` | New (wraps `external/agents/code-architect.md`) |
| n/a | `skills/code-explorer` | New (wraps `external/agents/code-explorer.md`) |
| n/a | `skills/code-simplifier` | New (wraps `external/agents/code-simplifier.md`) |
| n/a | `skills/comment-analyzer` | New (wraps `external/agents/comment-analyzer.md`) |
| n/a | `skills/pr-test-analyzer` | New (wraps `external/agents/pr-test-analyzer.md`) |
| n/a | `skills/silent-failure-hunter` | New (wraps `external/agents/silent-failure-hunter.md`) |
| n/a | `skills/type-design-analyzer` | New (wraps `external/agents/type-design-analyzer.md`) |

### External Skills

| Claude skill                                 | Codex skill                                  | Status/Notes                                    |
| -------------------------------------------- | -------------------------------------------- | ----------------------------------------------- |
| `external/skills/agent-development`          | `external/skills/agent-development`          | Ported (Codex guidance; local edits)            |
| `external/skills/hook-development`           | `external/skills/hook-development`           | Ported (Codex guidance; local edits)            |
| `external/skills/skill-development`          | `external/skills/skill-development`          | Ported (Codex guidance; local edits)            |
| `external/skills/frontend-design`            | `external/skills/frontend-design`            | Imported (manual updates; may reference Claude) |
| `external/skills/sentry-code-review`         | `external/skills/sentry-code-review`         | Imported (manual updates; may reference Claude) |
| `external/skills/sentry-setup-ai-monitoring` | `external/skills/sentry-setup-ai-monitoring` | Imported (manual updates; may reference Claude) |
| `external/skills/sentry-setup-logging`       | `external/skills/sentry-setup-logging`       | Imported (manual updates; may reference Claude) |
| `external/skills/sentry-setup-metrics`       | `external/skills/sentry-setup-metrics`       | Imported (manual updates; may reference Claude) |
| `external/skills/sentry-setup-tracing`       | `external/skills/sentry-setup-tracing`       | Imported (manual updates; may reference Claude) |

### Agents

Codex does not auto-discover agent files. Use these prompt files with `codex-subagent` or via skills.

| Claude agent                               | Codex agent                                | Status/Notes                    |
| ------------------------------------------ | ------------------------------------------ | ------------------------------- |
| `agents/code-reviewer.md`                  | `agents/code-reviewer.md`                  | Ported (run via `codex exec`)   |
| `agents/security-reviewer.md`              | `agents/security-reviewer.md`              | Ported (run via `codex exec`)   |
| `external/agents/code-architect.md`        | `external/agents/code-architect.md`        | Imported (run via `codex exec`) |
| `external/agents/code-explorer.md`         | `external/agents/code-explorer.md`         | Imported (run via `codex exec`) |
| `external/agents/code-simplifier.md`       | `external/agents/code-simplifier.md`       | Imported (run via `codex exec`) |
| `external/agents/comment-analyzer.md`      | `external/agents/comment-analyzer.md`      | Imported (run via `codex exec`) |
| `external/agents/pr-test-analyzer.md`      | `external/agents/pr-test-analyzer.md`      | Imported (run via `codex exec`) |
| `external/agents/silent-failure-hunter.md` | `external/agents/silent-failure-hunter.md` | Imported (run via `codex exec`) |
| `external/agents/type-design-analyzer.md`  | `external/agents/type-design-analyzer.md`  | Imported (run via `codex exec`) |

### Hooks

Codex CLI has no native hook events. Use `codex-hook-runner` (see `external/skills/hook-development`).

| Claude hook                             | Codex hook                    | Status/Notes                                               |
| --------------------------------------- | ----------------------------- | ---------------------------------------------------------- |
| `hooks/check-ci-before-stop.sh`         | `hooks/check-ci-before-stop.sh`         | Ported; requires `codex-hook-runner`          |
| `hooks/check-orchestration-sleep.sh`    | `hooks/check-orchestration-sleep.sh`    | Ported; requires `codex-hook-runner`          |
| `hooks/hooks.json`                      | `hooks/hooks.json`                      | Ported; requires `codex-hook-runner`          |
| `hooks/plan-limit-account-switch.sh`    | `hooks/plan-limit-account-switch.sh`    | Ported; requires `codex-hook-runner`          |
| `hooks/post-pr-creation.sh`             | `hooks/post-pr-creation.sh`             | Ported; requires `codex-hook-runner`          |
| `hooks/security-scan.sh`                | `hooks/security-scan.sh`                | Ported; requires `codex-hook-runner`          |
| `hooks/session-start.sh`                | `hooks/session-start.sh`                | Ported; requires `codex-hook-runner`          |
| `hooks/track-test-results.sh`           | `hooks/track-test-results.sh`           | Ported; requires `codex-hook-runner`          |
| `hooks/validate-generated-artifacts.sh` | `hooks/validate-generated-artifacts.sh` | Ported; requires `codex-hook-runner`          |
| `hooks/validate-local-testing.sh`       | `hooks/validate-local-testing.sh`       | Ported; requires `codex-hook-runner`          |
| `hooks/validate-pr-creation.sh`         | `hooks/validate-pr-creation.sh`         | Ported; requires `codex-hook-runner`          |
| `hooks/validate-pr-merge.sh`            | `hooks/validate-pr-merge.sh`            | Ported; requires `codex-hook-runner`          |
| `hooks/validate-tests-pass.sh`          | `hooks/validate-tests-pass.sh`          | Ported; requires `codex-hook-runner`          |
| `hooks/lib/`                            | `hooks/lib/`                            | Ported; used by hook scripts                  |

### MCP Servers

| Claude MCP                    | Codex MCP                                                    | Status/Notes                                                                |
| ----------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `mcp__git` (mcp-server-git)   | `mcp_servers.git` (`uvx mcp-server-git`)                     | Supported (installed by `install.sh`)                                       |
| `mcp__memory` (server-memory) | `mcp_servers.memory` (`@modelcontextprotocol/server-memory`) | Supported (installed by `install.sh`)                                       |
| `mcp__github` (server-github) | `mcp_servers.github` (`@modelcontextprotocol/server-github`) | Supported (installed by `install.sh`, needs `GITHUB_PERSONAL_ACCESS_TOKEN`) |
| `mcp__playwright`             | `mcp_servers.playwright` (`@playwright/mcp`)                 | Supported (optional; `SKIP_PLAYWRIGHT=true`)                                |
| `mcp__puppeteer`              | Not configured                                               | Not supported by default; add manually if needed                            |
| `mcp__plugin_episodic-memory` | Not configured                                               | Not supported by default; use `mcp__memory` instead                         |

### CLI Tools

| Claude tool                 | Codex tool                 | Status/Notes                               |
| --------------------------- | -------------------------- | ------------------------------------------ |
| `scripts/claude-autonomous` | `scripts/codex-autonomous` | Ported (Codex-only repo)                   |
| `scripts/claude-account`    | `scripts/codex-account`    | Ported (Codex-only repo)                   |
| n/a                         | `scripts/codex-hook-runner` | New (hook runner wrapper for Codex CLI)    |
| n/a                         | `scripts/codex-subagent`   | New (agent card runner for Codex subagents) |
| `install.sh`                | `install.sh`               | Ported (Codex CLI, skills, MCP config)     |

---

## Multi-Account Management

`codex-account` stores portable account snapshots (base64 of `$CODEX_HOME/auth.json`) in a gitignored `.env`.

### Commands

```bash
codex-account capture
codex-account list
codex-account list --available
codex-account current
codex-account switch
codex-account switch <email>
codex-account next
codex-account mark-exhausted
codex-account reset-exhausted
codex-account status
```

### `.env` Format

```bash
CODEX_ACCOUNT_USER_EXAMPLE_COM_EMAILADDRESS="user@example.com"
CODEX_ACCOUNT_USER_EXAMPLE_COM_AUTHJSON_B64="eyJ0b2tlbnMiOns..."
```

Environment:

- `CODEX_ACCOUNT_COOLDOWN_MINUTES` (default `5`)
- `CODEX_AUTONOMOUS_MAX_SWITCHES` (default `10`)
- `CODEX_ACCOUNT_FLAP_THRESHOLD` (default `3`, hook runner)
- `CODEX_ACCOUNT_FLAP_WINDOW` (default `60`, hook runner seconds)
- `CODEX_DISABLE_HOOKS` (default `false`)

---

## MCP Servers

The installer appends MCP server definitions to `$CODEX_HOME/config.toml`:

- `mcp_servers.git` (uvx `mcp-server-git`)
- `mcp_servers.memory` (Node `@modelcontextprotocol/server-memory`)
- `mcp_servers.github` (Node `@modelcontextprotocol/server-github`, requires `GITHUB_PERSONAL_ACCESS_TOKEN`)
- `mcp_servers.playwright` (Node `@playwright/mcp`)

To avoid storing secrets in config, GitHub uses:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)"
```

---

## Configure AGENTS.md for Your Project

For best results, configure your project's `AGENTS.md` with instructions that reinforce the issue-driven workflow. Copy the following prompt and paste it into a Codex CLI session in your project directory:

```
Please update my AGENTS.md file with development instructions optimized for the codex-skills issue-driven workflow and autonomous operation.

IMPORTANT: First, remove any existing sections that might conflict with issue-driven development workflows (sections about commit styles, PR processes, testing workflows, code review, documentation requirements, or development methodology). Keep any project-specific configuration like API keys, server addresses, or domain-specific knowledge.

Then add the following instructions:

---

## Development Methodology

This project uses the `issue-driven-development` skill pack from `codex-skills`. All work MUST follow its skills and protocols.

### Foundational Rules

1. **No work without an issue** - Every change requires a GitHub issue first
2. **Never work on main** - All work happens in feature branches
3. **Research before action** - Your training data is stale; research current patterns before coding
4. **Skills are mandatory** - If a skill exists for what you're doing, you MUST use it
5. **Verify before claiming** - Prove things work with evidence before stating completion

### Anti-Shortcut Enforcement

These behaviors are FAILURES that require stopping and redoing:

| Prohibited Behavior | Why It's Wrong |
|---------------------|----------------|
| Skipping code review | Review artifacts are required for PR creation |
| Skipping tests | TDD is mandatory; tests come first |
| Skipping documentation | Inline docs and feature docs are required |
| Batch updates at end | Issues must be updated continuously as work happens |
| Assuming API behavior | Research current APIs; don't trust training data |
| Skipping validation | All generated artifacts must be validated |
| Claiming completion without proof | Show test output, verification results |
| Working without an issue | Create the issue first, always |

### Mandatory Skill Usage

Before ANY of these actions, invoke the corresponding skill:

| Action | Required Skill |
|--------|----------------|
| Starting work | `session-start` |
| Any coding task | `issue-driven-development` |
| Creating a PR | `pr-creation` (requires review artifact) |
| Code review | `comprehensive-review` |
| After 2 failures | `research-after-failure` |
| Large task | `issue-decomposition` |
| Debugging | `error-recovery` |

### Quality Standards

- **Full typing always** - No `any` types; everything fully typed
- **Complete inline documentation** - JSDoc/docstrings on all public APIs
- **TDD with coverage** - Write tests first, maintain coverage
- **Atomic commits** - One logical change per commit
- **IPv6-first** - IPv6 is primary; IPv4 is legacy support only

### Verification Requirements

Before claiming ANY task is complete:

1. Tests pass (show output)
2. Linting passes (show output)
3. Build succeeds (show output)
4. Acceptance criteria verified (post verification report to issue)
5. Review artifact posted (for PRs)

### Issue Lifecycle

Issues must be updated CONTINUOUSLY, not at the end:

- Comment when starting work
- Comment when hitting blockers
- Comment when making progress
- Comment when tests pass/fail
- Update status fields in GitHub Project

---

Make sure to preserve any existing project-specific configuration (environment variables, API endpoints, domain knowledge) that doesn't conflict with these instructions.
```
