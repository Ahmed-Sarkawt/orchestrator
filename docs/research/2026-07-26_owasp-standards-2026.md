# OWASP Security Standards — current editions and TS/Node enforcement

**Date:** 2026-07-26
**Requested by:** user (via 4 parallel research agents)
**Confidence:** High

## Question

What are the current OWASP security standards (as of mid-2026), and how do they map to concrete detection signals and enforcement rules in a TypeScript/React/Node codebase?

## Answer

Four standards researched in parallel from official OWASP sources; the full distilled content lives in `.claude/skills/owasp-security/SKILL.md` (the operational artifact). Current editions:

- **OWASP Top 10:2025** (final, released Nov 2025) — SSRF merged into A01 Broken Access Control; two new categories: A03 Software Supply Chain Failures, A10 Mishandling of Exceptional Conditions. A09 renamed to emphasize *alerting*.
- **API Security Top 10:2023** — still the latest edition; no newer release as of July 2026.
- **ASVS 5.0.0** (May 2025) — ~350 requirements, 17 chapters, fully renumbered vs 4.0.3. L2 is the right target for a SaaS app. Cookie/CSRF/header requirements moved to V3; password storage to V11.
- **LLM Top 10:2025 (v2.0)** — still canonical; the 2026 cycle produced a *separate* "Top 10 for Agentic Applications" rather than a replacement.

## Key findings

- The highest-leverage cross-standard rules for this stack: ownership-scoped queries (BOLA/IDOR), parameterized everything (SQL/shell), fail-closed error handling, zod-parse at every trust boundary (including third-party API responses and LLM output), CSPRNG for all randomness, and server-side-only authorization.
- LLM output must be treated exactly like untrusted user input — same sinks (XSS, SQLi, SSRF), new vector.
- Supply chain is now a first-class Top 10 category — this repo's hard rule 3 (decision file per dependency) directly satisfies part of it.

## Sources

- https://owasp.org/Top10/ (Top 10:2025)
- https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- https://owasp.org/www-project-application-security-verification-standard/ and https://github.com/OWASP/ASVS/tree/v5.0.0/5.0/en
- https://genai.owasp.org/llm-top-10/

## Gaps

- OWASP Top 10 for Agentic Applications (2026, separate list) not yet distilled — worth a follow-up when its final version stabilizes.
- ASVS checklist is the ~25 highest-leverage L1/L2 items, not all ~350 requirements.
