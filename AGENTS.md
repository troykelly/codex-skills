# Instructions

## Skills

A skill is a set of local instructions to follow that is stored in a `SKILL.md` file.

### Available skills

System skills live in `$CODEX_HOME/skills/.system/` (typically `~/.codex/skills/.system/`).

- `skill-creator`: Guide for creating effective skills. Use when creating or updating a skill that extends Codex's capabilities.
- `skill-installer`: Install Codex skills into `$CODEX_HOME/skills` from a curated list or a GitHub repo path.

### How to use skills

- **Discovery**: Skills have metadata (`name`, `description`) and a body in `SKILL.md`.
- **Trigger rules**: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description, use that skill for that turn.
- **Missing/blocked**: If a named skill isn't available or can't be read, state that briefly and continue with the best fallback.
- **Progressive disclosure**:
  1) Read the `SKILL.md` for any skill you decide to use.
  2) If `SKILL.md` references `references/`, load only files needed for the request (don’t bulk-load).
  3) If `scripts/` exist, prefer running or patching them over retyping large code blocks.
  4) If `assets/` or templates exist, reuse them instead of recreating.
- **Coordination and sequencing**:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you’ll use them.
  - Announce which skill(s) you’re using and why (one short line).
- **Context hygiene**:
  - Keep context small: summarize long sections instead of pasting them.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- **Safety and fallback**: If a skill can’t be applied cleanly (missing files, unclear instructions), state the issue and continue with the next-best approach.

