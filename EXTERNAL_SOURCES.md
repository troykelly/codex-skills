# External Source Attribution

This document tracks skills and agents sourced from external repositories.

## Source Repositories

### Primary Source
**Repository:** [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)
**Description:** Anthropic-managed directory of high quality Claude Code Plugins
**License:** See source repository for license terms

### Additional Sources
**Repository:** [getsentry/sentry-for-claude](https://github.com/getsentry/sentry-for-claude)
**Description:** Official Sentry error monitoring integration for Claude Code
**License:** See source repository for license terms

## Imported Artifacts

The following artifacts were imported from external repositories for provenance. There is no automated sync; updates must be applied manually. **Do not edit these files directly** unless noted below.

### Agents (from `pr-review-toolkit` plugin)

| Local Path | Source Path | Description |
|------------|-------------|-------------|
| `external/agents/silent-failure-hunter.md` | `plugins/pr-review-toolkit/agents/silent-failure-hunter.md` | Identifies silent failures and inadequate error handling |
| `external/agents/pr-test-analyzer.md` | `plugins/pr-review-toolkit/agents/pr-test-analyzer.md` | Reviews PR test coverage quality |
| `external/agents/type-design-analyzer.md` | `plugins/pr-review-toolkit/agents/type-design-analyzer.md` | Analyzes type design for invariants and encapsulation |
| `external/agents/code-simplifier.md` | `plugins/pr-review-toolkit/agents/code-simplifier.md` | Simplifies code while preserving functionality |
| `external/agents/comment-analyzer.md` | `plugins/pr-review-toolkit/agents/comment-analyzer.md` | Analyzes code comments for accuracy and maintainability |

### Agents (from `feature-dev` plugin)

| Local Path | Source Path | Description |
|------------|-------------|-------------|
| `external/agents/code-architect.md` | `plugins/feature-dev/agents/code-architect.md` | Designs feature architectures with implementation blueprints |
| `external/agents/code-explorer.md` | `plugins/feature-dev/agents/code-explorer.md` | Traces execution paths and maps architecture layers |

### Skills (from `plugin-dev` plugin)

**Note:** The plugin-dev skills listed below are **ported to Codex** and maintained locally in this repo.

| Local Path | Source Path | Description |
|------------|-------------|-------------|
| `external/skills/skill-development/` | `plugins/plugin-dev/skills/skill-development/` | Skill authoring best practices (Codex port) |
| `external/skills/hook-development/` | `plugins/plugin-dev/skills/hook-development/` | Hook creation and validation (Codex port) |
| `external/skills/agent-development/` | `plugins/plugin-dev/skills/agent-development/` | Agent authoring guidance (Codex port) |

### Skills (from `frontend-design` plugin)

| Local Path | Source Path | Description |
|------------|-------------|-------------|
| `external/skills/frontend-design/` | `plugins/frontend-design/skills/frontend-design/` | Production-grade frontend interface design guidance |

### Skills (from `getsentry/sentry-for-claude`)

| Local Path | Source Path | Description |
|------------|-------------|-------------|
| `external/skills/sentry-code-review/` | `skills/sentry-code-review/` | Sentry code review integration |
| `external/skills/sentry-setup-ai-monitoring/` | `skills/sentry-setup-ai-monitoring/` | AI monitoring setup for Sentry |
| `external/skills/sentry-setup-logging/` | `skills/sentry-setup-logging/` | Logging setup for Sentry |
| `external/skills/sentry-setup-metrics/` | `skills/sentry-setup-metrics/` | Metrics setup for Sentry |
| `external/skills/sentry-setup-tracing/` | `skills/sentry-setup-tracing/` | Tracing setup for Sentry |

## Why These Artifacts

### Complementing Issue-Driven Development

| External Artifact | Complements Our Skill | Purpose |
|-------------------|----------------------|---------|
| `silent-failure-hunter` | `comprehensive-review` | Catches error handling gaps our review might miss |
| `pr-test-analyzer` | `tdd-full-coverage` | Provides test coverage analysis during PR review |
| `type-design-analyzer` | `strict-typing` | Deep type design analysis beyond basic typing |
| `code-simplifier` | Post-implementation | Simplifies code after implementation complete |
| `comment-analyzer` | `inline-documentation` | Validates comment accuracy against code |
| `code-architect` | `pre-work-research` | Provides architectural design before coding |
| `code-explorer` | `session-start` | Deep codebase exploration for understanding |
| `frontend-design` | UI/frontend work | High-quality, distinctive frontend interface design |
| `sentry-*` | Error monitoring | Sentry error tracking, logging, metrics, and tracing integration |

### Codex Development Helpers

The `plugin-dev` skills help us maintain and improve this Codex skill pack:
- `skill-development` - For writing new skills
- `hook-development` - For creating/modifying hooks
- `agent-development` - For creating new agents

### Frontend Design

The `frontend-design` skill provides guidance for creating production-grade, visually distinctive frontend interfaces that avoid generic AI aesthetics.

### Sentry Integration

The Sentry skills from `getsentry/sentry-for-claude` provide comprehensive error monitoring integration:
- **sentry-code-review** - Analyze and validate Sentry code review feedback
- **sentry-setup-ai-monitoring** - Configure AI/ML model monitoring
- **sentry-setup-logging** - Set up structured logging
- **sentry-setup-metrics** - Configure custom metrics
- **sentry-setup-tracing** - Set up distributed tracing

## Modification Policy

| Directory | Editable? | Notes |
|-----------|-----------|-------|
| `external/` | NO* | Imported for provenance; update manually with upstream references |
| `agents/` | YES | Our custom agents |
| `skills/` | YES | Our custom skills |

*Exception: `external/skills/{skill-development,hook-development,agent-development}` are Codex ports and are maintained locally.

To update an imported artifact:
1. Fork the upstream repository
2. Make changes there
3. Submit PR to upstream
4. Manually port the relevant changes into this repo with provenance notes

## Manual Update Workflow

Use this checklist when updating any imported external artifact:

1. Identify the upstream repo, path, and commit/tag to pull from.
2. Copy the upstream file(s) into the matching `external/` path.
3. Re-apply Codex-specific edits (frontmatter limits, tool names, env vars, hook runner guidance).
4. Update this document if sources, paths, or descriptions changed.
5. Update `README.md` Migration Map if the mapping or status changed.
6. Record provenance in the commit message (repo + commit/tag).
