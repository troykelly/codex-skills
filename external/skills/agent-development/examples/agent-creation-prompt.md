# Codex Agent Card Generation Template

Use this template to generate Codex agent cards with the system prompt in `references/agent-creation-system-prompt.md`.

## Usage Pattern

### Step 1: Describe the Agent

Be specific about:
- Task scope
- When to use it
- Output expectations
- Any project conventions

### Step 2: Ask for JSON Output

Send this to Codex (with the system prompt loaded):

```
Create an agent card based on this request: "[YOUR DESCRIPTION]"
Return ONLY the JSON object.
```

### Step 3: Convert JSON to an Agent Card

Create `agents/[identifier].md`:

```markdown
---
name: [identifier]
description: [description]
profile: [profile name, if provided]
model: [model, if provided]
---

[prompt]
```

### Step 4: Run the Agent

```bash
codex-subagent [identifier] <<'EOF'
[Provide task context and scope here.]
EOF
```

## Example: Code Review Agent

**Request:**
```
I need an agent that reviews recent code changes for quality issues and security risks. It should output a structured report with file:line references.
```

**JSON (example):**
```json
{
  "identifier": "code-quality-reviewer",
  "description": "Use when the user asks for a code review, audit of recent changes, or quality check; run the code-quality-reviewer agent card.",
  "prompt": "You are an expert code quality reviewer...",
  "profile": "[profiles.review-worker]\nmodel = \"gpt-5.2-codex\"\nsandbox_mode = \"workspace-write\"\napproval_policy = \"on-request\""
}
```

**Agent card:**
```markdown
---
name: code-quality-reviewer
description: Use when the user asks for a code review, audit of recent changes, or quality check; run the code-quality-reviewer agent card.
profile: review-worker
model: gpt-5.2-codex
---

You are an expert code quality reviewer...
```

## Validation

Validate generated cards before using them:

```bash
external/skills/agent-development/scripts/validate-agent.sh agents/code-quality-reviewer.md
```
