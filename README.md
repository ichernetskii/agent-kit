# agent-kit

Personal skills for AI coding agents, in the open [Agent Skills](https://agentskills.io) format.
Works as a plugin in Claude Code and Codex, and updates itself.

## Install

Claude Code:

```bash
claude plugin marketplace add ichernetskii/agent-kit
claude plugin install agent-kit@ichernetskii
```

Codex:

```bash
codex plugin marketplace add ichernetskii/agent-kit
codex plugin add agent-kit@ichernetskii
```

## Skills

- [`commit-message`](skills/commit-message/SKILL.md): draft a Conventional Commit message for the staged changes, or for all changes if nothing is staged; it writes text only and never commits. Ask for a commit message or run `/commit-message`, optionally with `lang=ru`, `source=staged|all`, `body=none|always` or `variants=3`.
- [`polish`](skills/polish/SKILL.md): polish English text or translate it from Russian. Run `/polish <text>`; add `--rewrite` (`-r`) for a free rewrite.

## License

[MIT](LICENSE)
