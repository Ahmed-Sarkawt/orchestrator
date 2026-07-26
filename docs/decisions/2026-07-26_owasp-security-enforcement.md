# OWASP security enforcement: skill + hook + reviewer

**Date:** 2026-07-26
**Status:** Active

## Decision

Three-layer OWASP enforcement, built from 4-agent parallel research (see docs/research/2026-07-26_owasp-standards-2026.md):

1. **`.claude/skills/owasp-security/SKILL.md`** — comprehensive knowledge skill: Top 10:2025, API Top 10:2023, ASVS 5.0 L2 checklist, LLM Top 10:2025, each with TS/React/Node detection signals and enforcement imperatives.
2. **`.claude/hooks/security-check.sh`** — new PostToolUse (Write|Edit|MultiEdit) hook: deterministic regex scan of every saved source file (hardcoded secrets, SQL interpolation, eval/Function, XSS sinks, weak crypto, Math.random tokens, TLS bypass, CORS wildcard, JWT misuse, command injection). Non-blocking; findings injected as additionalContext with an instruction to fix immediately or justify, plus a pointer to the skill. Logs `security_warning` events.
3. **`code-reviewer` agent** — OWASP section upgraded from Top 10 2021 to 2025 numbering (SSRF folded into A01; new A03 Supply Chain and A10 Exceptional Conditions sections), with instructions to load the skill's API/LLM sections when reviewing route handlers or LLM code.

## Rationale

- Write-time reinforcement needs to be fast and deterministic — regex heuristics catch the classic footguns instantly without model judgment; the reviewer stays the thorough, contextual gate at /review time.
- Non-blocking (exit 0) because heuristics have false positives; blocking on regex would fight legitimate code. The context injection forces an immediate fix-or-justify response instead.
- The skill centralizes all four standards so agents and hooks reference one source of truth.

## Alternatives considered

- **Blocking PreToolUse guard for security patterns** — rejected: too many false positives for content-level heuristics; guard-dangerous-bash.sh stays scoped to unambiguous destructive commands.
- **Context-injection reminders only (no scanning)** — rejected: relies entirely on model attention; deterministic checks are free and instant.
- **External SAST (semgrep) in a hook** — rejected for now: violates hard rule 3 (new dependency) and setup-free portability; regex covers the top signals. Revisit if a real app accumulates.

## Consequences

- Every saved source file gets an instant security scan; warnings appear in-session and in session logs (`security_warning` events).
- 6 new hook tests in run-tests.sh (39 total).
- The 2025 renumbering means old findings files referencing 2021 categories (A03 Injection etc.) don't map 1:1 to new category labels.
