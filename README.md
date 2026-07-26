# An Agent Orchestrator: Helps you build better

A Claude Code configuration layer. Drop it into any project and get a structured agent team, automated quality gates, persistent memory across sessions, and enforced coding standards — without writing any of it yourself.

**Stack-agnostic.** Works with any language or framework. Optimized for TypeScript/Node projects out of the box, adaptable to anything via `setup.sh`.

---

## Requirements

> **⚠ Install these before running setup.sh or starting any Claude session:**

| Dependency          | Why                                                                                                                                                                 | Install                                        |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| **jq**              | Required by all hooks for JSON parsing. Without it, the Bash safety guard fails closed (blocks all commands until installed) and loggers/context injection degrade. | `brew install jq` · `apt install jq`           |
| **python3**         | Required by setup.sh for safe file replacement.                                                                                                                     | `brew install python3` · `apt install python3` |
| **Claude Code CLI** | The tool this config runs inside.                                                                                                                                   | [claude.ai/code](https://claude.ai/code)       |

---

## Which setup path should I use?

| Situation                                            | Use                                                                               |
| ---------------------------------------------------- | --------------------------------------------------------------------------------- |
| At a terminal before opening Claude                  | `bash setup.sh` — interactive prompts                                             |
| Inside a Claude Code or Cowork session               | `/init` — conversational wizard, applies changes directly                         |
| CI pipeline or scripted automation                   | `bash setup.sh --mode advanced --name "..." --desc "..."` — non-interactive flags |
| Want to see current config without changing anything | `bash setup.sh --print-config`                                                    |
| Want to preview what setup would do                  | `bash setup.sh --dry-run [flags]`                                                 |

Both paths read and write `.claude/setup-config.json`, so switching between them mid-project is safe — each tool picks up where the other left off.

---

## Quick start (5 minutes)

**1. Run setup**

```bash
bash setup.sh
```

**2. Verify hooks work**

```bash
bash .claude/tests/run-tests.sh
```

All tests should pass before your first session.

**3. Commit**

```bash
git add .claude/ CLAUDE.md REFERENCE.md docs/ .gitignore
git commit -m "chore: add Claude Code configuration"
```

**4. Open Claude Code**

```bash
claude
```

Run `/init` if you want to make further customizations interactively.

---

## How it works

### The review pipeline (`/review`)

The main quality loop. Run it after writing code:

```
/review
  → code-reviewer    scans for bugs, a11y issues, security, TS errors
  → bug-fixer        applies all Auto-fixable findings automatically
  → test-writer      writes failing tests for every reviewed file
  → judge            independently verifies fixes applied and tests pass
```

Files are queued automatically by `trigger-code-review.sh` every time you save. **Crash-safe:** if Claude closes mid-review, the next session detects the interrupted state and warns you immediately so nothing slips through.

### Research (`/research` or automatic)

When Claude hits a knowledge gap, the researcher fires automatically. It:

1. **Plans** what to search (sonnet — judgment)
2. Delegates actual fetching to `research-executor` **(haiku — cheap)**
3. **Synthesizes** findings and saves them to `docs/research/` using consistent naming

Findings persist across sessions via the index file.

### Safety guards

Dangerous commands are blocked before execution — `rm -rf`, SQL drops, `curl | sh`, and direct pushes to main.

### Security (OWASP, three layers)

1. **Write time** — `security-check.sh` regex-scans every saved source file (hardcoded secrets, SQL interpolation, `eval`, XSS sinks, weak crypto, TLS bypass, CORS wildcards, JWT misuse) and injects warnings Claude must fix or justify immediately.
2. **On demand** — the `owasp-security` skill: OWASP Top 10 2025, API Security Top 10, ASVS 5.0 checklist, and LLM Top 10 with TS/React/Node detection signals.
3. **Review time** — `code-reviewer` runs the full OWASP Top 10 2025 checklist on every file in `/review`.

### Docs structure

Three folders replace flat files. Each has a compact index Claude reads on startup, and individual detail files it reads on demand:

| Folder            | What goes in it                      | Who writes                                 |
| ----------------- | ------------------------------------ | ------------------------------------------ |
| `docs/decisions/` | One `.md` per architectural decision | You or `doc-updater` via `new-decision.sh` |
| `docs/research/`  | One `.md` per research session       | `researcher` agent via `new-research.sh`   |
| `docs/flow/`      | One `.md` per user flow              | You or `doc-updater`                       |

**Git tracking:** setup always tracks `docs/decisions/` in git — decision records are part of the project. Research logs are opt-in (`setup.sh` asks; `--research-log yes|no` for CI) and stay local-only by default.

### Session logging

Every session produces `.claude/logs/sessions/<id>.jsonl` with events: prompts, file saves, agent completions, blocked commands. At session end, a summary appends to `.claude/logs/session-summary.md`. Run `/session-log` to analyze patterns.

---

## Agents

| Agent               | When invoked                    | Model  | Cost   |
| ------------------- | ------------------------------- | ------ | ------ |
| `code-reviewer`     | `/review` — after writing code  | sonnet | medium |
| `bug-fixer`         | Auto — part of `/review`        | haiku  | low    |
| `researcher`        | Auto when stuck, or `/research` | sonnet | medium |
| `research-executor` | Auto — invoked by researcher    | haiku  | low    |
| `test-writer`       | Auto — end of `/review`         | sonnet | medium |
| `judge`             | Auto — final gate of `/review`  | sonnet | medium |
| `ux-auditor`        | `/audit-ux` — secondary         | sonnet | medium |
| `doc-updater`       | Manual — secondary              | haiku  | low    |

**Secondary agents** (ux-auditor, doc-updater) are not in the default pipeline. Invoke them when you specifically need them.

---

## Hooks at a glance

| Event                    | Hook                         | Effect                                       |
| ------------------------ | ---------------------------- | -------------------------------------------- |
| Session opens            | `session-start.sh`           | Context injection + interrupted review check |
| User submits any prompt  | `prompt-logger.sh`           | Logs prompt to session JSONL                 |
| Any Bash command         | `guard-dangerous-bash.sh`    | Hard-blocks dangerous patterns               |
| File saved               | `format-and-test.sh`         | Prettier + sibling test run                  |
| File saved               | `security-check.sh`          | OWASP regex scan — fix-or-justify warnings   |
| File saved               | `trigger-code-review.sh`     | Queues file for `/review`                    |
| New file created         | `prompt-reference-update.sh` | Prompts Claude to update REFERENCE.md        |
| Route/API/schema changed | `suggest-doc-update.sh`      | Suggests invoking doc-updater                |
| Context fills up         | `pre-compact.sh`             | Preserves modified files + failing tests     |
| Agent finishes           | `subagent-stop.sh`           | Next-step suggestion per agent type          |
| Session closes           | `session-end.sh`             | Writes session summary                       |

---

## Skills

Slash commands and on-demand knowledge, one directory each in `.claude/skills/`:

| Skill                              | Type      | What                                                                      |
| ---------------------------------- | --------- | ------------------------------------------------------------------------- |
| `review`                           | command   | `/review` — the quality pipeline described above                          |
| `research`                         | command   | `/research` — invoke the researcher                                       |
| `audit-ux`                         | command   | `/audit-ux` — UX Laws + WCAG AA audit                                     |
| `workflow`                         | command   | `/workflow <name>` — run a deterministic multi-agent workflow             |
| `session-log`                      | command   | `/session-log` — analyze session logs                                     |
| `feedback`                         | command   | `/feedback` — record a permanent correction for an agent                  |
| `init`                             | command   | `/init` — conversational setup wizard                                     |
| `owasp-security`                   | knowledge | OWASP Top 10 2025 + API Top 10 + ASVS 5.0 + LLM Top 10, TS/Node signals   |
| `taste-skill`                      | knowledge | Anti-slop frontend design for landing/portfolio/marketing (vendored, MIT) |
| `animation-micro-interaction-pack` | knowledge | Motion presets and micro-interaction patterns (vendored, MIT)             |
| `laws-of-ux`                       | knowledge | 13 UX laws with application guidance + pitfalls checklist                 |
| `react-ts-standards`               | knowledge | Enforced React + TypeScript patterns                                      |
| `agent-team`                       | knowledge | The full agent graph — who invokes whom                                   |

---

## Customization

### Add a project-specific rule

```text
<!-- .claude/rules/payments.md -->
---
paths: ["src/payments/**/*.ts"]
---

# Payment module rules
- Never log card numbers or CVVs
- All Stripe calls go through src/lib/stripe.ts
```

---

## Troubleshooting

| Problem                                      | Fix                                                                                |
| -------------------------------------------- | ---------------------------------------------------------------------------------- |
| `/review` says queue is empty                | Check your source files match patterns in `trigger-code-review.sh`                 |
| Session start warns about interrupted review | Run `/review` to resume, or `rm .claude/.review-queue-active.txt`                  |
| Tests failing in `run-tests.sh`              | Run from project root; run `bash .claude/hooks/session-start.sh > /dev/null` first |

---

## What this doesn't include (by design)

- **GitHub Actions CI** — add `anthropics/claude-code-action@v1` when ready.
- **Your design tokens** — design _taste_ skills are included; add a `.claude/skills/design-system/SKILL.md` with your own tokens and component patterns.
- **MCP servers** — project-specific. Add to `.claude/settings.json` under `mcpServers`.
