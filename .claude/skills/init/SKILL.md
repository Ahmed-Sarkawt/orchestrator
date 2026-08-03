---
name: init
description: Initialize or update project-specific Claude configuration — covers all 12 setup options conversationally. Works as both first-time setup and an update wizard.
disable-model-invocation: true
---

You are running the setup wizard for this claude-boilerplate project. Ask each question conversationally, wait for the answer, apply the change immediately, then move to the next step. Do not batch — apply each change as you go so the user can see progress.

## Before starting

1. Check for `.claude/setup-config.json`. If it exists, read it with:

   ```bash
   cat .claude/setup-config.json
   ```

   Use every value in it as the default for the corresponding question. Show the current value in brackets so the user can press enter to keep it: e.g. "Frontend directory? [src]"

2. Read `CLAUDE.md` to detect if the `[FILL IN]` placeholder is still present.

3. Read `.claude/settings.json` to detect which hooks are active.

This makes `/init` work as both a first-time setup wizard and an update command — the user only needs to answer the questions where they want to change something.

4. **Git connection check (do this before anything else).** Run:

   ```bash
   git remote get-url origin 2>/dev/null
   ```

   If the URL matches the boilerplate's own repo (`github.com/itssulaimann/orchestrator`, `github.com/Ahmed-Sarkawt/orchestrator`, or `.../claude-boilerplate`), this folder is still connected to the boilerplate — commits and pushes would land in the boilerplate repo, which must never happen for a real project. Tell the user, then ask: "Detach this project from the boilerplate repo? Git stays local; only the remote link is removed. Answer no ONLY if you are developing the boilerplate itself. (yes/no — default: yes)"

   If **yes** (default): run `git remote remove origin`, then ask: "Also start a fresh git history? Discards the boilerplate's commits — say no if you already made commits of your own. (yes/no — default: no)". If yes AND `.git` is a normal directory (not a worktree — check `git rev-parse --git-common-dir` returns `.git`): `rm -rf .git && git init`. Finish by telling the user: "Add your own remote later with: git remote add origin <your-repo-url>".

   If **no**: skip — boilerplate development mode.

---

## Step 1 — Project identity

Read `CLAUDE.md`. If the `[FILL IN]` placeholder is still present, ask:

- "What does this project do and who is it for? (one sentence)"
- "What's the primary success metric? (e.g. 'time to first value < 5 min')"

Replace the `[FILL IN]` line in `CLAUDE.md` with: `{description} The primary success metric is: {metric}.`

If the placeholder is already filled, show the current value and ask: "Update the project description? (enter to keep)"

---

## Step 2 — Source layout

Ask: "Where does your frontend code live? (default: src/)"
Ask: "Where does your backend code live? (default: server/ — leave blank if none)"

Update the `paths` frontmatter in:

- `.claude/rules/frontend.md`
- `.claude/rules/backend.md`

Also update the source path patterns in:

- `.claude/hooks/trigger-code-review.sh`
- `.claude/hooks/format-and-test.sh`

---

## Step 3 — Test runner

Ask: "What test runner do you use? (vitest / jest / other — default: vitest)"

Update the test run command in `.claude/hooks/format-and-test.sh`:

- vitest → `npx vitest run`
- jest → `npx jest`
- other → `npx {runner} run`

---

## Step 4 — Git push strategy

Ask: "Should Claude push directly to main, or always use feature branches? (branches/main — default: branches)"

If **main**: append `ALLOW_PUSH_MAIN=1` to `.env.claude` (create if missing), add `.env.claude` to `.gitignore`.
If **branches**: no change needed — `guard-dangerous-bash.sh` already blocks pushes to main by default.

---

## Step 5 — Model tier

Ask: "Which model tier for agents?

1. Economy — haiku for all (fastest, cheapest)
2. Balanced — sonnet primary, haiku utility (default)
3. Powerful — opus primary, sonnet utility (best quality)"

Primary agents (code-reviewer, researcher, test-writer, ux-auditor) and utility agents (bug-fixer, research-executor, doc-updater) each have a `model:` line in their frontmatter in `.claude/agents/`.

Apply the mapping:

- Economy: replace `model: sonnet` → `model: haiku` in primary agents
- Balanced: no change
- Powerful: replace `model: sonnet` → `model: opus` in primary agents; `model: haiku` → `model: sonnet` in utility agents

---

## Step 6 — Auto-format on save

Ask: "Run Prettier + sibling test automatically on every file save? (yes/no — default: yes)"

If **no**: remove the `format-and-test.sh` entry from the `PostToolUse` array in `.claude/settings.json` using:

```bash
tmp=$(mktemp)
jq '(.hooks.PostToolUse) |= map(select(any(.hooks[]; .command | contains("format-and-test")) | not))' .claude/settings.json > "$tmp" && mv "$tmp" .claude/settings.json
```

---

## Step 7 — Session logging

Ask: "Write session logs to .claude/logs/? Used by /session-log. (yes/no — default: yes)"

If **no**: remove the `UserPromptSubmit` and `Stop` hook sections from `.claude/settings.json`:

```bash
tmp=$(mktemp)
jq 'del(.hooks.UserPromptSubmit) | del(.hooks.Stop)' .claude/settings.json > "$tmp" && mv "$tmp" .claude/settings.json
```

---

## Step 8 — Commit signing

Ask: "Enforce signed commits (git commit -S)? Requires GPG setup. (yes/no — default: no)"

If **yes**:

1. Run `git config commit.gpgsign true`
2. Append to `CLAUDE.md` hard rules: `8. **Sign all commits. Always use \`git commit -S\`. Never use \`--no-gpg-sign\`.\*\*`
3. Warn: "Requires a GPG key — see https://docs.github.com/authentication/managing-commit-signature-verification"

---

## Step 9 — Branch naming convention

Ask: "Branch naming prefix? Adds a hard rule enforcing consistent names. (e.g. feat, fix, claude — leave blank to skip)"

If provided: append to `CLAUDE.md` hard rules:
`8. **Branch names must follow \`{prefix}/<short-description>\` (e.g. \`{prefix}/add-login\`). Never push directly to main unless ALLOW_PUSH_MAIN=1 is set.\*\*`

---

## Step 10 — Review sensitivity

Ask: "How strict should the code reviewer be?

1. Strict — reports Block, Recommend, and Note (default)
2. Normal — reports Block and Recommend only
3. Relaxed — reports Block only"

If **normal**: append to `.claude/agents/code-reviewer.md`:

```
## Review threshold

Report **🔴 Block** and **🟡 Recommend** findings only. Do not include **🟢 Note** findings in your output.
```

If **relaxed**: append to `.claude/agents/code-reviewer.md`:

```
## Review threshold

Report **🔴 Block** findings only. Do not include **🟡 Recommend** or **🟢 Note** findings in your output.
```

If **strict**: no change needed — that is the default behavior.

---

## Step 11 — Agent Teams

Ask: "Enable experimental Agent Teams? Lets multiple Claude instances share a task list in parallel worktrees. (yes/no — default: no)"

If **yes**: append `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to `.env.claude`, add `.env.claude` to `.gitignore`.

---

## Step 12 — Docs tracking (research logs)

The boilerplate ships with both `docs/decisions/2*.md` and `docs/research/2*.md` gitignored — that keeps the boilerplate repo's own development history off GitHub. A real project is different: decision records document why the code is the way it is and **must be committed**.

**Always do (no question):** remove the `docs/decisions/2*.md` line from `.gitignore`:

```bash
(grep -vxF 'docs/decisions/2*.md' .gitignore || true) > .gitignore.tmp && mv .gitignore.tmp .gitignore
```

**Ask:** "Commit research logs (docs/research/) to git too? Useful for teams; keep them local if research is scratch work. (yes/no — default: no)"

If **yes**: also remove the research ignore line and its comment:

```bash
(grep -vxF 'docs/research/2*.md' .gitignore || true) > .gitignore.tmp && mv .gitignore.tmp .gitignore
(grep -vF '# Project-history docs' .gitignore || true) > .gitignore.tmp && mv .gitignore.tmp .gitignore
```

If **no**: keep the line — research files stay on this machine only, and the hooks/scripts keep working locally.

---

## Step 13 — Project-specific rules

Ask: "Any project-specific hard rules to add to CLAUDE.md? (e.g. 'never use class components', 'all API calls go through src/lib/api.ts' — leave blank to skip)"

If provided: append each rule to the hard rules list in `CLAUDE.md`.

---

## Step 14 — Make hooks executable

Run: `chmod +x .claude/hooks/*.sh`

---

## Step 15 — Summary

Show a clean summary of every setting and what was changed vs kept at default. Then say:

"Setup complete. Commit these files to your repo so every Claude Code session uses these settings:

````
git add .claude/ CLAUDE.md REFERENCE.md docs/ .gitignore
git commit -m 'chore: add Claude Code configuration'
```"
````
