# Setting up Codex for the council

The council needs, in this order:

1. Node.js 18.18 or later.
2. The Codex plugin for Claude Code ([openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)), installed and enabled.
3. The Codex CLI.
4. A Codex sign-in.

`bash "$S/scripts/codex.sh" --ready` prints a `MISSING` line for each gap. Fix the first one, then run `--ready` again. Setup is done when it prints `READY`.

## Node.js

The user installs it from https://nodejs.org. Tell them so and wait.

## The plugin

Ask the user with AskUserQuestion whether to set up the Codex plugin, with the options "Set up the Codex plugin (Recommended)" and "Skip for now". On yes:

- Not installed: if `claude plugin marketplace list` doesn't show `openai-codex`, run `claude plugin marketplace add openai/codex-plugin-cc`. Then run `claude plugin install codex@openai-codex`.
- Disabled: run `claude plugin enable codex@openai-codex`.

Then ask the user to run `/reload-plugins` so this session loads the plugin, and wait.

## The Codex CLI and sign-in

Call the Skill tool with "codex:setup". The plugin's setup offers to install the CLI and explains how to sign in. Signing in is the user's step: pass on its guidance (`!codex login`) and wait.

If the Skill tool doesn't know "codex:setup", this session hasn't loaded the plugin yet: ask the user to run `/reload-plugins` first.
