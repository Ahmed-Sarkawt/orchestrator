# REFERENCE.md

> Read this before using `find`, `grep`, or `ls` to explore the codebase.
> One-line description per file. Update when adding or removing files.
> Claude Code reads this to orient itself without burning context on filesystem traversal.

## Config

| File                                   | What                                                                                                     |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `CLAUDE.md`                            | Master instructions — read on every session                                                              |
| `.claude/OVERVIEW.md`                  | Agent map, file map, when-stuck flow — injected each session                                             |
| `REFERENCE.md`                         | This file — codebase index                                                                               |
| `docs/decisions/index.md`              | Compact decisions table — one row per decision, links to detail files                                    |
| `docs/decisions/*.md`                  | One file per decision — full rationale, alternatives, consequences                                       |
| `docs/research/index.md`               | Compact research table — one row per session, links to detail files                                      |
| `docs/research/*.md`                   | One file per research session — question, answer, sources, confidence                                    |
| `docs/flow/index.md`                   | Flow overview table — lists all flows with status                                                        |
| `docs/flow/*.md`                       | One file per user flow — steps, success criteria, out-of-scope                                           |
| `.claude/settings.json`                | Hook wiring and Claude Code config                                                                       |
| `.claude/workflows/README.md`          | Workflow runtime quick-ref, primitive table, copy-paste template, when-to-use decision rule              |
| `.claude/workflows/parallel-review.js` | Fan-out code-reviewer per queued file simultaneously, then sequential bug-fixer → test-writer → judge    |
| `.claude/workflows/full-audit.js`      | Parallel code review + UX audit + dependency scan; synthesizes a ranked findings report                  |
| `.claude/workflows/research-sweep.js`  | 4-angle parallel research (docs, security, performance, recent); synthesized and saved to docs/research/ |
| `.claude/skills/workflow/SKILL.md`     | /workflow slash command — invokes any named workflow by name                                             |
| `.claude/.current-session-id`          | Active session ID — written by session-start, read by all loggers                                        |
| `.claude/.review-queue.txt`            | Files queued for /review — cleared at start of each review run                                           |
| `.claude/logs/sessions/<id>.jsonl`     | Structured event log for one session (JSONL, one event per line)                                         |
| `.claude/logs/session-summary.md`      | Human-readable summary of every past session                                                             |
| `.claude/logs/last-test-run.txt`       | Output of most recent sibling test run (read by pre-compact)                                             |
| `.claude/logs/sessions.log`            | One-line session end entries                                                                             |

## Agents (`.claude/agents/`)

| File                   | What                                                                                   |
| ---------------------- | -------------------------------------------------------------------------------------- |
| `code-reviewer.md`     | Reviews TS/React/SQL for correctness, a11y, OWASP, design-system compliance            |
| `bug-fixer.md`         | Applies safe mechanical fixes from code-reviewer findings tagged auto-fixable          |
| `test-writer.md`       | Writes tests for reviewed files — end of /review pipeline                              |
| `judge.md`             | Independently verifies the /review pipeline output — lint, typecheck, tests, pass/fail |
| `researcher.md`        | Plans research (sonnet), delegates execution to research-executor                      |
| `research-executor.md` | Executes research plans (haiku) — searches, fetches, returns raw findings              |
| `doc-updater.md`       | Syncs docs/flow/, docs/decisions/, README when routes/APIs/flows change                |
| `ux-auditor.md`        | Audits UI against UX laws and WCAG AA — invoked via /audit-ux                          |

## Skills (`.claude/skills/<name>/SKILL.md`)

| Skill                              | What                                                                                     |
| ---------------------------------- | ---------------------------------------------------------------------------------------- |
| `review`                           | /review — drain queue: code-reviewer → bug-fixer → test-writer → judge                   |
| `research`                         | /research — invoke researcher for knowledge gaps                                         |
| `audit-ux`                         | /audit-ux — UX + WCAG AA audit of a component, page, or flow                             |
| `workflow`                         | /workflow — invoke any named workflow in .claude/workflows/                              |
| `session-log`                      | /session-log — analyze session JSONL logs for cost, agents, patterns                     |
| `feedback`                         | /feedback — record a correction for a specific agent                                     |
| `init`                             | /init — conversational setup/update wizard                                               |
| `agent-team`                       | Knowledge: full agent graph, invocation chains, who calls whom                           |
| `laws-of-ux`                       | Knowledge: 10 UX laws with application guidance                                          |
| `react-ts-standards`               | Knowledge: enforced React + TypeScript patterns                                          |
| `taste-skill`                      | Knowledge: anti-slop frontend design for landing/portfolio/marketing (vendored, MIT)     |
| `animation-micro-interaction-pack` | Knowledge: motion presets and micro-interaction patterns (vendored, MIT)                 |
| `owasp-security`                   | Knowledge: OWASP Top 10 2025, API Top 10, ASVS 5.0, LLM Top 10 — detection + enforcement |
| `better-ui`                        | Knowledge: UI polish — surfaces, animations, icons, perf (vendored, MIT)                 |
| `better-accessibility`             | Knowledge: focus, keyboard, ARIA, forms, screen readers (vendored, MIT)                  |
| `better-colors`                    | Knowledge: OKLCH color, palettes, contrast, theming (vendored, MIT)                      |
| `better-layout`                    | Knowledge: grouping, alignment, spacing, breakpoints (vendored, MIT)                     |
| `better-typography`                | Knowledge: fonts, spacing, wrapping, variable fonts (vendored, MIT)                      |
| `better-interface`                 | Knowledge: interface design principles (vendored, MIT)                                   |
| `better-writing`                   | Knowledge: product copy — labels, errors, empty states (vendored, MIT)                   |

## Hooks (`.claude/hooks/`)

| File                         | Event                    | What                                                                   |
| ---------------------------- | ------------------------ | ---------------------------------------------------------------------- |
| `session-start.sh`           | SessionStart             | Generates session ID, injects branch/decisions/research/memory context |
| `prompt-logger.sh`           | UserPromptSubmit         | Logs prompt char count to session JSONL                                |
| `guard-dangerous-bash.sh`    | PreToolUse (Bash)        | Blocks rm -r, SQL DROP/TRUNCATE, curl\|sh, push to main — fails closed |
| `format-and-test.sh`         | PostToolUse (Write/Edit) | Prettier-formats saved file, runs sibling test file                    |
| `security-check.sh`          | PostToolUse (Write/Edit) | Deterministic OWASP regex scan of saved file — warns via context       |
| `trigger-code-review.sh`     | PostToolUse (Write/Edit) | Queues source files into .review-queue.txt + meta JSONL                |
| `prompt-reference-update.sh` | PostToolUse (Write)      | Prompts Claude to index new files in REFERENCE.md                      |
| `suggest-doc-update.sh`      | PostToolUse (Write/Edit) | Reminds to invoke doc-updater when route/API/schema files change       |
| `pre-compact.sh`             | PreCompact               | Injects preservation instructions (modified files, failing tests)      |
| `subagent-stop.sh`           | SubagentStop             | Logs agent completion, suggests the logical next step                  |
| `session-end.sh`             | Stop                     | Writes session summary, MEMORY.md cap warning                          |
| `session-logger.sh`          | (helper)                 | Core JSONL logger called by all other hooks                            |

## Scripts, rules, workflows, memory

| File                                  | What                                                                    |
| ------------------------------------- | ----------------------------------------------------------------------- |
| `.claude/scripts/new-decision.sh`     | Creates a dated decision file + index row — returns path on stdout      |
| `.claude/scripts/new-research.sh`     | Creates a dated research file + index row — returns path on stdout      |
| `.claude/rules/frontend.md`           | Path-scoped rules for frontend code                                     |
| `.claude/rules/backend.md`            | Path-scoped rules for backend code                                      |
| `.claude/rules/testing.md`            | Path-scoped rules for test files                                        |
| `.claude/tests/run-tests.sh`          | Hook test suite — run from project root                                 |
| `.claude/memory/MEMORY.md`            | Auto-memory index — first 150 lines injected each session start         |
| `.claude/memory/agent-corrections.md` | Per-agent corrections recorded via /feedback                            |
| `.claude/loop.md`                     | Loop maintenance prompt                                                 |
| `.claude/examples/scheduled-tasks/`   | Scheduled-task skill templates (daily-review, weekly-research) + README |

## Source

<!-- Add one row per file as you build. Claude reads this instead of running find/ls. -->

| File          | What                   |
| ------------- | ---------------------- |
| `[your file]` | [one-line description] |

## Tests

| File               | What                   |
| ------------------ | ---------------------- |
| `[your test file]` | [one-line description] |
