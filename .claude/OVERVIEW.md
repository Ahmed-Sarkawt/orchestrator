# Claude Session Overview

> Read this when disoriented. One page. Everything you need to navigate this project.
> A compact version is injected automatically by session-start.sh — this is the full reference.

---

## Agent decision map

Read this before exploring files or guessing. Every situation has an owner.

| Situation                                                     | What to do                                                                        |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| You don't know something (library, API, error, best practice) | Invoke `researcher` — don't guess                                                 |
| User or you can't answer a question                           | Invoke `researcher` — do not ask the user to look it up                           |
| After writing or editing any source file                      | `trigger-code-review.sh` queues it automatically — user runs `/review` when ready |
| Processing the review queue                                   | `/review` → `code-reviewer` → `bug-fixer` → `test-writer` → `judge`               |
| Any UI feature built or changed                               | `/audit-ux` → `ux-auditor` (secondary — on demand)                                |
| Route path, API shape, or DB schema changed                   | `doc-updater` (secondary — on demand)                                             |

## When stuck — in order

```
1. Check docs/research/index.md  — already researched? Use it, don't re-search.
2. Check docs/decisions/index.md — prior decision covers this? Respect it.
3. Check REFERENCE.md            — does the file/function exist? Read it.
4. Invoke researcher agent       — web search, fetch authoritative docs.
5. Ask the user                  — only if research didn't resolve it.
```

Never skip to step 5. The researcher exists precisely so the user doesn't have to answer questions Claude can look up.

## File map — where to find everything

| I need...                                         | Read this                                               |
| ------------------------------------------------- | ------------------------------------------------------- |
| Hard rules, coding guidelines, definition of done | `CLAUDE.md`                                             |
| Every file in the project (one-liner each)        | `REFERENCE.md`                                          |
| Past decisions (index)                            | `docs/decisions/index.md` → then read the linked file   |
| Past research (index)                             | `docs/research/index.md` → then read the linked file    |
| User flows                                        | `docs/flow/index.md` → then read the linked file        |
| Agent definitions                                 | `.claude/agents/<name>.md`                              |
| Path-scoped coding rules                          | `.claude/rules/frontend.md`, `backend.md`, `testing.md` |
| Custom slash command definitions                  | `.claude/skills/<name>/SKILL.md`                        |
| UX laws with application guidance                 | `.claude/skills/laws-of-ux/SKILL.md`                    |
| Full agent graph and recommended chains           | `.claude/skills/agent-team/SKILL.md`                    |
| Claude Code hooks, settings, patterns reference   | `claude-code-research.md`                               |
| Session memory index                              | `.claude/memory/MEMORY.md`                              |

## What's running automatically right now

You don't need to trigger these — they fire on their own.

| Event                | What runs                | Effect                                                          |
| -------------------- | ------------------------ | --------------------------------------------------------------- |
| Session opens        | `session-start.sh`       | Branch, recent decisions, recent research injected into context |
| Any file is saved    | `format-and-test.sh`     | Prettier formats it; sibling test runs                          |
| Any file is saved    | `security-check.sh`      | OWASP regex scan — warnings injected, fix or justify            |
| Any file is saved    | `trigger-code-review.sh` | File queued in `.claude/.review-queue.txt`                      |
| Context window fills | `pre-compact.sh`         | Preserves modified files, failing tests, current task           |
| Any agent finishes   | `subagent-stop.sh`       | Suggests the logical next step                                  |
| Session closes       | `session-end.sh`         | Logs session to `.claude/logs/sessions/`                        |

## Slash commands

| Command        | Invokes                                                 | When to use                                                        |
| -------------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| `/review`      | `code-reviewer` → `bug-fixer` → `test-writer` → `judge` | After writing code                                                 |
| `/research`    | `researcher`                                            | Knowledge gap, or any question neither you nor the user can answer |
| `/audit-ux`    | `ux-auditor`                                            | After any UI work (secondary — on demand)                          |
| `/session-log` | Claude reads JSONL logs                                 | Analyze cost, tokens, agents, repeated patterns                    |
| `/init`        | Setup wizard                                            | Reconfigure paths, test runner, rules                              |

## Workflows

Workflows are deterministic JS scripts that fan out agents in parallel and hold intermediate results outside Claude's context window. Any `.js` file in `.claude/workflows/` auto-registers by name.

| Workflow          | Trigger                               | When to use                                                                                                 |
| ----------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `parallel-review` | `/workflow parallel-review`           | Queue has > 3 files — fans out one `code-reviewer` per file simultaneously, then fix → test → judge         |
| `full-audit`      | `/workflow full-audit`                | Before a release — runs code review, UX audit, and dependency scan in parallel, synthesizes a ranked report |
| `research-sweep`  | `/workflow research-sweep <question>` | Deep research — 4 parallel angles (docs, security, performance, recent changes), saved to `docs/research/`  |

**Workflow vs. slash command:** Use a workflow when you need parallel fan-out, a discover-then-fan-out barrier, or intermediate results that should not fill Claude's context window. See `.claude/workflows/README.md` for the runtime primitive quick-ref and template.

## Agent sub-invocation rules

These agents can invoke `researcher` as a sub-agent:

- `code-reviewer` — when an unfamiliar library or version needs verification
- `ux-auditor` — when a UX claim or WCAG guidance needs verification

`researcher` invokes `research-executor` (haiku) to execute searches and fetches cheaply.

These agents invoke nobody:

- `research-executor`, `bug-fixer`, `test-writer`, `doc-updater`, `judge`

## Agent Teams — confirmed constraints

Agent Teams is enabled by default via `settings.json`. One confirmed limitation to be aware of:

- **`TeammateIdle`, `TaskCompleted`, and `TaskCreated` hooks are TypeScript SDK only.** They cannot be wired as shell command hooks in `settings.json`. If you need a quality gate that blocks task completion until the judge passes, you must use the TypeScript Agent SDK — shell hooks cannot implement this.

Everything else about Agent Teams (task list sharing, parallel worktrees, `TaskCreate`/`TaskUpdate`/`TaskGet` tools) works from the CLI as normal.

## Shared state files (never delete these)

| File                                              | Who writes                        | Who reads                              |
| ------------------------------------------------- | --------------------------------- | -------------------------------------- |
| `docs/research/index.md` + `docs/research/*.md`   | `researcher`                      | session-start hook, all agents         |
| `docs/decisions/index.md` + `docs/decisions/*.md` | `doc-updater`, user               | session-start hook, all agents         |
| `docs/flow/index.md` + `docs/flow/*.md`           | `doc-updater`, user               | `test-writer`, `doc-updater`           |
| `.claude/.review-queue.txt`                       | `trigger-code-review.sh`          | `/review` (cleared at start of review) |
| `.claude/.review-queue-meta.jsonl`                | `trigger-code-review.sh`          | `code-reviewer` (rich edit context)    |
| `.claude/.review-queue-active.txt`                | `/review` command                 | `/review`, `session-start.sh`          |
| `.claude/findings/<path>.json`                    | `code-reviewer`                   | `bug-fixer`, `test-writer`, `judge`    |
| `.claude/findings/bug-fixer-summary.json`         | `bug-fixer`                       | `judge`                                |
| `.claude/.current-session-id`                     | `session-start.sh`                | All logger hooks                       |
| `.claude/logs/sessions/<id>.jsonl`                | All hooks via `session-logger.sh` | `/session-log`, `session-end.sh`       |
| `.claude/logs/session-summary.md`                 | `session-end.sh`                  | `/session-log`, user                   |
| `.claude/logs/last-test-run.txt`                  | `format-and-test.sh`              | `pre-compact.sh`                       |
| `REFERENCE.md`                                    | User (kept manually)              | All agents                             |
| `.claude/memory/MEMORY.md`                        | Claude auto-memory                | Every session (first 200 lines)        |
