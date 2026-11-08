# AGENTS.md

Personal toolkit for AI coding agents: skills and shared instructions.
The content is vendor-neutral; each agent gets a thin adapter on top of it.

## Layout

- `skills/<name>/SKILL.md` — skills in the open Agent Skills format
  (frontmatter with `name` and `description`, then the instructions).
  This is the shared core: any agent that supports Agent Skills can read it.
- `skills/<name>/agents/openai.yaml` — Codex metadata for that skill
  (see "Writing skills").
- `AGENTS.md` — this file: how the repository is organized and how to change it.
- `.claude-plugin/` — plugin adapter: `marketplace.json` (catalog) and
  `plugin.json` (plugin manifest). Claude Code reads it; Codex and GitHub
  Copilot fall back to it when there is no adapter folder of their own.
- `.github/` — GitHub automation: the workflow that raises the plugin
  version and the script it runs.

## Rules for changes

- Keep skills vendor-neutral. Do not reference tools or paths that exist
  in only one agent unless the skill is explicitly agent-specific.
- An agent-specific skill says so wherever it shows: its name ends with
  the agent's suffix (`-cc` for Claude Code), its description starts with
  "<Agent> only", and its first instruction stops it in other agents.
  Skill names can't contain `claude` or `anthropic` (reserved by
  Anthropic), hence the suffix.
- One skill per folder; the folder name matches the `name` in `SKILL.md`.
- Put every vendor-specific file into that vendor's adapter folder,
  never into `skills/`. The one exception is `agents/openai.yaml` inside
  each skill folder: Codex reads it only from there.
- Claude Code adapter:
  - `version` in `plugin.json` is raised automatically: after every push to
    `main` that changes the plugin, the `Bump plugin version` workflow
    (`.github/workflows/bump-version.yml`) raises the patch number and
    commits it. Agents reinstall the plugin only when this number changes.
    Don't raise the patch number by hand. To change the major or minor
    number (e.g. to 2.0.0), edit it in your commit: the workflow then keeps it.
  - Run `git pull` before editing: the workflow adds its own commit after
    each of your pushes.
  - Plugin names must not start with `claude-`, `anthropic-`,
    `anthropics-` or `cc-plugin-` (reserved by the validator).
  - Check changes with `claude plugin validate .`.

## Writing skills

- Every skill is one of two kinds:
  - **Command-only**: runs only when the user types its name. Set
    `disable-model-invocation: true` in the frontmatter (Claude Code) and
    `policy.allow_implicit_invocation: false` in `agents/openai.yaml`
    (Codex). The `description` is a one-line summary for a person browsing
    commands, without trigger phrases.
  - **Situational**: the agent may also start it on its own. Omit
    `disable-model-invocation` and the `policy` block. The `description`
    lists the situations and phrases that should trigger it.
- Every skill has `agents/openai.yaml` next to its `SKILL.md` with Codex
  menu metadata:

  ```yaml
  interface:
    display_name: "Polish"            # name shown in the Codex skill picker
    short_description: "One line"     # summary shown under the name
  policy:                             # command-only skills only
    allow_implicit_invocation: false
  ```

  Keep it in sync with `SKILL.md`: a skill is command-only in both agents
  or in neither.
- When one skill needs another, write an explicit instruction to call the
  Skill tool with the skill's name, e.g. `Call the Skill tool with "review-mr"`.
  Do not write `/review-mr` in prose: agents often miss it as a command, and
  the slash is one vendor's syntax. A command-only skill cannot be called
  this way.
