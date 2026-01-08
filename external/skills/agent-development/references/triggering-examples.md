# Agent Triggering Examples (Codex)

Codex does not support `<example>` blocks in agent cards. Use **skill descriptions** and **runbook language** to describe when to use a Codex agent.

## Skill Description Patterns

Skill descriptions must be a single line and <= 500 characters. Use concrete phrases users say:

```yaml
description: Use when the user asks to review a PR, audit recent code changes, or request a code quality check; run the pr-reviewer agent card.
```

More examples:

```yaml
description: Use when the user asks to generate tests, improve coverage, or write test cases for new functions; run the test-generator agent card.
```

```yaml
description: Use when the user requests a security audit, vulnerability check, or hardening review; run the security-reviewer agent card.
```

## Runbook Examples (Manual Triggering)

When you need to trigger an agent manually, use a consistent response pattern:

```
"I'll run the pr-reviewer agent now and report back with findings."
```

```
"Spinning up the test-generator agent to draft test coverage for the new module."
```

Then run the agent card with:

```bash
codex-subagent <agent-name> <<'EOF'
[Provide task context and scope here.]
EOF
```

## Proactive Triggers

Use proactive triggers after relevant work completes:

- After implementing significant code changes, invoke the review agent.
- After editing tests, invoke a test-quality agent.
- After merging dependencies or auth changes, invoke a security agent.

Keep the trigger language consistent so future skills can reuse it.
