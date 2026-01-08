# External Sources

This directory contains skills and agents imported from [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official).

**DO NOT EDIT FILES IN THIS DIRECTORY** unless explicitly noted below.

## Current Sources

### Agents (from pr-review-toolkit)

| Agent | Purpose |
|-------|---------|
| `silent-failure-hunter` | Identifies silent failures and inadequate error handling |
| `pr-test-analyzer` | Reviews PR test coverage quality |
| `type-design-analyzer` | Analyzes type design for invariants and encapsulation |
| `code-simplifier` | Simplifies code while preserving functionality |
| `comment-analyzer` | Analyzes code comments for accuracy |

### Agents (from feature-dev)

| Agent | Purpose |
|-------|---------|
| `code-architect` | Designs feature architectures with implementation blueprints |
| `code-explorer` | Traces execution paths and maps architecture layers |

### Skills (from plugin-dev)

**Note:** The plugin-dev skills are **ported to Codex** and maintained locally.

| Skill | Purpose |
|-------|---------|
| `skill-development` | Skill authoring best practices (Codex port) |
| `hook-development` | Hook creation and validation (Codex port) |
| `agent-development` | Agent authoring guidance (Codex port) |

## Contributing

To update imported files:
1. Fork `anthropics/claude-plugins-official`
2. Make changes in your fork
3. Submit a PR upstream
4. Manually port the relevant changes into this repo with provenance notes

To modify Codex-ported plugin-dev skills:
1. Edit the files directly in `external/skills/{skill-development,hook-development,agent-development}`

See [EXTERNAL_SOURCES.md](../EXTERNAL_SOURCES.md) for full documentation.
