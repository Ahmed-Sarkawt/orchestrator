# Vendor external design skills (taste, animation, UX laws)

**Date:** 2026-07-26
**Status:** Active

## Decision

Vendor two external skills into `.claude/skills/` and merge a third into an existing skill, so a fresh clone of this repo ships fully configured:

1. `design-taste-frontend` — verbatim from [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) `skills/taste-skill/SKILL.md` (MIT), with an attribution + repo-precedence header.
2. `animation-micro-interaction-pack` — verbatim from [majiayu000/claude-skill-registry](https://github.com/majiayu000/claude-skill-registry) (MIT), same header treatment.
3. `laws-of-ux` — extended in place with 3 laws (Proximity, Similarity, Serial Position) and a pitfalls checklist adapted from [lev-os/agents](https://github.com/lev-os/agents) laws-of-ux pattern.

## Rationale

- Vendoring (not linking/plugins) means zero install steps after clone — skills auto-register from `.claude/skills/`.
- MIT sources are copied verbatim with attribution. lev-os/agents has **no license**, so its content was rewritten into our house format (facts about published UX laws, credited to lawsofux.com/Jon Yablonski) rather than copied.
- Precedence headers resolve conflicts with CLAUDE.md hard rules: rule 7 (shadcn/ui base) and rule 4 (cross-browser animations) win for product UI; `design-taste-frontend` applies to landing/marketing/portfolio surfaces only.

## Alternatives considered

- **Claude Code plugin/marketplace install** — rejected: requires per-machine setup, defeating the "clone and go" goal.
- **Replacing our laws-of-ux with the lev-os version** — rejected: no license for verbatim copy, and ours is tailored to rationale-writing (commit messages, decision logs); merged the missing content instead.
- **Vendoring all 12 taste-skill variants** (brutalist, minimalist, brandkit, etc.) — rejected: only the flagship was requested; the rest can be added on demand from the same repo.

## Consequences

- Two new skill directories + one extended skill; upstream updates must be pulled manually (source URLs are in each file's header).
- `design-taste-frontend` is large (~1,200 lines) but loads only when invoked — no per-session context cost.
