---
name: laws-of-ux
description: Reference the relevant Laws of UX when justifying UI/UX design decisions in commit messages, decision logs, or design rationale. Use when explaining WHY a particular layout or flow choice was made.
---

# Laws of UX — Reference

Use these to justify design decisions with evidence, not opinion.
Cite the law by name when writing a rationale: "Per Hick's Law, we reduced choices from 8 to 3."

---

## Hick's Law

> The time to make a decision increases with the number and complexity of choices.

**Use when:** Justifying reducing options, hiding advanced settings, or progressive disclosure.
**Signal:** If a screen has more than 5–7 primary choices, Hick's Law predicts friction.

---

## Miller's Law

> The average person can hold ~7 (±2) items in working memory at once.

**Use when:** Designing navigation, onboarding steps, or any list of items the user must evaluate.
**Signal:** More than 7 items in a list, menu, or step sequence warrants chunking or pagination.

---

## Fitts's Law

> The time to acquire a target is a function of distance to and size of the target.

**Use when:** Justifying button size, placement of primary CTAs, or proximity of related controls.
**Signal:** A primary action that is small, far from the cursor's resting position, or surrounded by competing targets.

---

## Aesthetic-Usability Effect

> Users perceive aesthetically pleasing designs as easier to use.

**Use when:** Justifying investment in visual polish, consistency, or design system enforcement.
**Signal:** Inconsistent visual application of tokens raises perceived complexity even when functionality is unchanged.

---

## Doherty Threshold

> Productivity soars when a system responds in under 400ms.

**Use when:** Justifying optimistic UI, skeleton screens, or animation timing budgets.
**Signal:** Any interaction that exceeds 400ms without visual feedback creates perceived lag.
**Rule:** Animation duration ≤ 300ms for micro-interactions, ≤ 500ms for page-level transitions.

---

## Jakob's Law

> Users spend most of their time on other sites and expect yours to work the same way.

**Use when:** Justifying adherence to established UI conventions (nav placement, form patterns, icon meanings).
**Signal:** Deviating from a convention that every major competitor follows requires strong justification.

---

## Peak-End Rule

> People judge an experience by its peak (most intense moment) and its end.

**Use when:** Designing the emotional arc of an onboarding, checkout, or any multi-step flow.
**Signal:** The last screen a user sees in a flow has outsized impact on their memory of the whole experience.

---

## Tesler's Law (Conservation of Complexity)

> Every system has an irreducible amount of complexity. Simplifying the UI moves it, not removes it.

**Use when:** Justifying where to put required friction (into the platform, into defaults, into later steps).
**Signal:** If removing a field or step from the user's view feels like a win, ask: where did the complexity go?

---

## Zeigarnik Effect

> People remember uncompleted tasks better than completed ones.

**Use when:** Designing progress indicators, completion meters, or step-by-step onboarding flows.
**Signal:** Showing a partially filled progress bar motivates users to complete what they started.

---

## von Restorff Effect (Isolation Effect)

> An item that stands out from its peers is more likely to be remembered.

**Use when:** Justifying a single highlighted CTA, a visually distinct primary action, or a "recommended" badge.
**Signal:** If everything is emphasized, nothing is. Use visual distinction sparingly and with purpose.

---

## Law of Proximity (Gestalt)

> Objects near each other are perceived as related.

**Use when:** Justifying grouping of labels with their inputs, card layouts, or whitespace between unrelated sections.
**Signal:** A label sitting closer to the wrong field, or two unrelated controls closer to each other than to their own groups.

---

## Law of Similarity (Gestalt)

> Elements that share visual traits (color, shape, size) are perceived as related or behaving the same way.

**Use when:** Justifying consistent button variants (all destructive actions red), uniform icon sizing, or link styling.
**Signal:** Two elements that look the same but behave differently — or the same action styled two ways.

---

## Serial Position Effect

> Users best remember the first and last items in a series.

**Use when:** Justifying ordering of navigation items, list content, or the closing step of a flow.
**Signal:** A critical item buried mid-list, or a flow that ends on housekeeping instead of the key action.

---

## Common pitfalls (audit checklist)

Adapted from the process-oriented laws-of-ux pattern in [lev-os/agents](https://github.com/lev-os/agents/tree/main/skills-db/thinking/patterns/laws-of-ux) (credit: lawsofux.com, Jon Yablonski).

- **Touch targets under 44×44px (iOS) / 48×48px (Material)** — Fitts's Law violation; causes mis-taps and accessibility failures.
- **20+ simultaneous options** (mega-menus, monolithic forms) — Hick's Law violation; drives abandonment.
- **Reinvented conventions** (non-standard cart icon, logo that doesn't link home) — Jakob's Law violation; forces relearning.
- **Ungrouped long lists or forms** — Miller's Law violation; exceeds working memory, users skip fields.
- **Inconsistent spacing/color/alignment** — Proximity/Similarity violation; users misread relationships and click wrong elements.
