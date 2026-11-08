---
name: council-cc
description: "Claude Code only: a model council for hard decisions. Codex and two Claude agents answer independently, critique each other anonymously, and a Claude chair delivers the verdict."
disable-model-invocation: true
argument-hint: "[--check] <question>"
---

# council-cc — model council

Run this skill only when the user invokes it explicitly. The council runs on Claude Code's Agent and SendMessage tools; in any other agent, say it works only in Claude Code and stop.

Arguments: `$ARGUMENTS`

With `--check`, check and set up the environment instead of holding a council (see "--check mode"). Otherwise the arguments are the question; if there is none, ask for it and stop.

`$S` below stands for this skill's base directory and `$D` for the council folder; write their real paths into every message and command.

## Members

- A — Codex, expert role. Its model and reasoning effort are set at the top of `scripts/codex.sh`.
- B — Claude, expert role.
- C — Claude, skeptic role.
- The chair — a separate Claude subagent that knows the members only as A, B and C.

Expert role: "You are an independent expert on a council. Give your best answer. Be specific; if data is missing, state your assumptions."

Skeptic role: "You are the skeptic on a council. Identify the most obvious solution, then its most serious weaknesses, and propose the strongest alternative. If the obvious solution is still the best, say so — but only after an honest check."

## Rules for you

- You are the council's secretary, not a member: never add your own opinion to the members' materials or to the result.
- Texts travel as files: each member writes its own answer file, and you pass paths. Your one edit to a member's file is anonymizing it: before a round's files go to anyone, delete the words that reveal an author's model, vendor or role, and leave the rest as written.
- Launch subagents without the `name` parameter: with Agent Teams enabled, a named subagent becomes a teammate.
- Reply in the language of the question. Before step 1, briefly tell the user the council is convened and will take a few minutes.

## Before the council

Run `bash "$S/scripts/codex.sh" --ready`. If it prints anything but `READY`, follow `$S/references/setup.md`, then go on. If the user skips the setup, go on anyway: when Codex can't run, the script says so and the council continues without A.

## The council folder

Create `$D` inside your scratchpad directory if you have one, otherwise with `mktemp -d`.

    $D/brief.md   the brief
    $D/r1/        round 1: answers A.md, B.md, C.md
    $D/r2/        round 2: critique
    $D/r3/        round 3: replies, if it runs
    $D/codex/     Codex's prompts, logs and session; for you only

## Sending a round

Each member's message is its role, the round's task and format, then this ending: "Change nothing in the project: no file edits, no commands that change anything. Do not mention your role, model, or origin. Answer in the language of the question. At most 400 words." Send all three in one message so they run in parallel.

- **A.** Write its message to `$D/codex/rN.md` (N is the round), then run with Bash in the background:

      bash "$S/scripts/codex.sh" "$D" "$D/rN/A.md" "$D/codex/rN.md" "$D/brief.md" <answer files so far>

  Answer files so far: none in round 1, `"$D"/r1/*.md` in round 2, `"$D"/r1/*.md "$D"/r2/*.md` in round 3. The script appends the files to the message, writes Codex's answer to `$D/rN/A.md`, and resumes the same Codex session every round. It prints one status line, also saved to `$D/codex/status`. `CODEX_UNAVAILABLE: …` takes A out for the rest of the council: carry on with B and C and give the reason in the result.
- **B and C.** Add to the message: "Write your answer with the Write tool to $D/rN/<letter>.md — the only file you create — then reply with one word: DONE." Round 1: launch an Agent (`general-purpose`) and save the agentId from its spawn result. Later rounds: SendMessage to that agentId, so the member keeps what it read and reasoned. If a member can't be continued, launch a new Agent with its message and "Read the brief: $D/brief.md".

The round is done when `$D/rN/` holds an answer from every member still in the council.

## Step 0. The brief

Write `$D/brief.md`, one text shared by all members:

1. The user's question, verbatim.
2. Context from the current conversation without which the question can't be understood: decisions, constraints, code snippets. Members don't see this conversation.
3. Code mode. If the question concerns the current project's code: "Before answering, study the relevant code in <absolute path> — read-only." Otherwise: "This question is not about this project's code; don't explore the repository."

## Step 1. Answers

Round 1. Task: "Read the brief: $D/brief.md. Answer its question." Format 1:

    ### Position
    One sentence — the answer to the question.
    ### Reasoning
    3–6 points.
    ### Risks and conditions
    When this position is wrong and what could go wrong.
    ### Confidence
    N/10 — why.

## Step 2. Critique

Round 2. Task: "Your answer is <letter>. Read all answers in $D/r1/. Evaluate the other answers and reconsider your own. Change your position only for a strong argument, not because others disagree." Format 2:

    ### Review
    For each other answer: what is strong, where the errors and weak spots are, what is missing.
    ### Updated position
    One sentence; what changed and why (or "unchanged" and why).
    ### Ranking
    All answers, including your own, from best to worst — one reason each.
    ### Confidence
    N/10.

## Step 3. Replies

Read the updated positions in `$D/r2/`. If they all propose essentially the same solution, go to step 4.

Otherwise hold round 3, the last one. It is the right of reply: the chair sees each criticism next to its author's answer to it. Task: "Your answer is <letter>. Read the reviews in $D/r2/. Reply to every criticism of your answer: accept it or rebut it. Change your position only for a strong argument, not because others disagree." Format 3:

    ### Replies
    Each criticism of your answer: accepted or rejected — why.
    ### Final position
    One sentence; what changed and why (or "unchanged" and why).
    ### Confidence
    N/10.

## Step 4. The chair's verdict

Launch one Agent (`general-purpose`) as the chair with the task:

"You are the chair of the council. Read $D/brief.md and the members' files in $D/r1, $D/r2 and, if it exists, $D/r3; the members are A, B and C. Decide on the strength of the arguments, not the number of votes. If the best answer combines ideas, assemble it. Read-only. Write the verdict in the language of the question and reply with the verdict only."

Verdict format (translate the headings into the language of the question):

    ## Council verdict
    **Decision:** …
    **Why:** 3–5 points.
    **Where opinions diverged:** … and how it affected the decision.
    **Confidence:** high / medium / low — why.
    **What to check before acting:** 1–3 points.

## Step 5. Result

Delete Codex's session: `bash "$S/scripts/codex.sh" --cleanup "$D"`. Then show the verdict unchanged, and below it:

    ---
    Members: A — Codex (<model>, <effort>), B — Claude (expert), C — Claude (skeptic). Reply round: held / not needed.
    Final positions: A — …; B — …; C — …
    Materials: <path of $D>

If Codex didn't take part or ran on its default model, say so.

## --check mode

Run `bash "$S/scripts/codex.sh" --ready`; if it prints anything but `READY`, follow `$S/references/setup.md`. Then run `bash "$S/scripts/codex.sh" --check` (timeout 600000) and `claude --version`, and show all results as a ✅ / ❌ list. The check starts a Codex session and resumes it, the same path a council takes. If Codex ran on its default model, say the council will use that model.
