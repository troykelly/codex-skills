---
name: agent-development
description: Use when the user wants to design Codex agent equivalents (specialized workers/profiles/prompt files), define triggering conditions, or build reusable agent prompts and validation tools.
---

# Agent Development (Codex)

## Overview

Codex CLI does not auto-discover "agent" files the way Claude plugins do. To recreate agent behavior in Codex, combine:

- Prompt files that define the agent's role and workflow.
- Codex config profiles to set model/sandbox/approval defaults.
- Skills that describe when to use the agent and how to launch it.
- Worker processes (`codex-subagent`, `codex exec`, or `worker-dispatch`) for isolated execution.

This skill standardizes an **agent card** format (YAML frontmatter + prompt body) and shows how to run it with Codex.

## Agent Card Format (Codex Convention)

Store agent prompts in `agents/<agent-name>.md`. Frontmatter is metadata for humans and validators; Codex does not read it automatically.

Required fields:
- `name` (kebab-case identifier)
- `description` (when to use this agent)

Recommended fields:
- `profile` (Codex config profile name)
- `model` (override model)
- `sandbox_mode` and `approval_policy` (safety defaults)
- `tools` (advisory list of tools; use sandbox/approval to enforce)

Example:

```markdown
---
name: pr-reviewer
description: Use this agent when the user asks for a code review or to audit a pull request.
profile: review-worker
model: gpt-5.2-codex
sandbox_mode: workspace-write
approval_policy: on-request
tools: ["Read", "Grep", "Bash"]
---

You are a senior PR reviewer...
```

## Running an Agent

Preferred (subagent runner):

```bash
codex-subagent pr-reviewer <<'EOF'
[Provide task context and scope here.]
EOF
```

Fallback (manual `codex exec`):

```bash
awk 'BEGIN{c=0} /^---$/{c++; next} c>=2 {print}' agents/pr-reviewer.md | codex exec -p review-worker -
```

## Profiles as Agent Defaults

Define per-agent profiles in `~/.codex/config.toml`:

```toml
[profiles.review-worker]
model = "gpt-5.2-codex"
sandbox_mode = "workspace-write"
approval_policy = "on-request"
```

Profiles capture the model and safety settings that Claude agents used to embed in frontmatter.

## Triggering (Codex Equivalent)

To make agent usage automatic, create a **skill** describing the trigger and invocation. The skill body should instruct how to run the agent card or spawn a worker.

Example trigger entry:

```yaml
description: Use when the user asks for a PR review or code audit; run the pr-reviewer agent card.
```

See `references/triggering-examples.md`.

## Validation

Use `scripts/validate-agent.sh` to validate agent cards for required fields and prompt length.

## References

- `references/system-prompt-design.md` for prompt structure
- `references/triggering-examples.md` for trigger phrasing
- `references/agent-creation-system-prompt.md` for AI-assisted agent card generation
- `examples/agent-creation-prompt.md` for a complete prompt template
- `examples/complete-agent-examples.md` for full agent card examples
