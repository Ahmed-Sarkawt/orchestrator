---
name: owasp-security
description: Comprehensive OWASP security standards — Top 10 2025, API Security Top 10 2023, ASVS 5.0 verification checklist, and LLM Top 10 2025 — with TypeScript/React/Node detection signals and enforcement rules. Load when writing or reviewing auth, API routes, DB queries, file handling, LLM integrations, or any security-sensitive code. The security-check hook points here when it flags a saved file.
---

# OWASP Security Standards

> Researched 2026-07-26 from official OWASP sources (see Sources; full research in `docs/research/`).
> Current editions verified: **Top 10:2025** (final, Nov 2025), **API Security Top 10:2023**, **ASVS 5.0.0** (May 2025), **LLM Top 10:2025 (v2.0)**.

## How enforcement works in this repo (3 layers)

| Layer                         | When                        | What                                                                                                                                                                                                                                                          |
| ----------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `security-check.sh` hook      | Every Write/Edit, instantly | Deterministic regex scan (secrets, SQL interpolation, eval, XSS sinks, weak crypto, TLS bypass, CORS wildcard, JWT misuse). Warnings are injected into context — fix immediately or state why it's a false positive. Heuristic only: **no warning ≠ secure.** |
| This skill                    | On demand while writing     | Deep guidance: what each risk looks like in TS/React/Node and how to prevent it.                                                                                                                                                                              |
| `code-reviewer` via `/review` | Review time                 | Full OWASP Top 10 2025 checklist per file; consults this skill for API/ASVS/LLM sections when relevant.                                                                                                                                                       |

When writing new code, apply the rules below **proactively** — the hook and reviewer are safety nets, not the design process.

---

## 1. OWASP Top 10:2025 (web application risks)

2025 changes vs 2021: SSRF merged into A01; two new categories — A03 Software Supply Chain Failures and A10 Mishandling of Exceptional Conditions.

### A01:2025 — Broken Access Control (includes SSRF)

Failures to enforce what users can do — including the server making attacker-controlled requests.

**Detect:** handler queries by `req.params.id`/`input.id` with no ownership filter; authorization only in React with no server check; role from `req.body`/headers; `fetch(userSuppliedUrl)` without host allowlist; CORS `*` with credentials.
**Enforce:** deny-by-default server-side authorization on every route/server action; ownership in the query itself (`where: { id, userId: session.user.id }`); validate outbound URLs with `new URL()` + host allowlist, reject private/link-local/metadata ranges (`127.0.0.1`, `[::1]`, `169.254.169.254`), re-check on redirects.

### A02:2025 — Security Misconfiguration

**Detect:** `rejectUnauthorized: false` / `NODE_TLS_REJECT_UNAUTHORIZED=0`; missing `helmet()`/Next `headers()` (CSP, HSTS, `X-Content-Type-Options`); stack traces in API error JSON; GraphQL introspection/playground unconditionally on; default-open CORS.
**Enforce:** security headers on every HTTP entrypoint; ban TLS-verification bypass outright; gate all debug output behind `NODE_ENV !== 'production'` with generic client errors in production.

### A03:2025 — Software Supply Chain Failures

**Detect:** no lockfile / `latest` / `*` ranges; `npm install` (not `npm ci`) in CI; `postinstall` scripts; CI actions pinned by tag not SHA; `npx <unpinned>` in scripts.
**Enforce:** lockfile committed + `npm ci` in CI; pin actions to commit SHAs; `npm audit` blocking on high/critical; every new dependency needs a `docs/decisions/` entry (hard rule 3); review anything requiring lifecycle scripts.

### A04:2025 — Cryptographic Failures

**Detect:** `createHash('md5'|'sha1')` for passwords/tokens; `Math.random()` for tokens/session IDs/OTPs; hardcoded keys/salts; `jwt.decode()` where `verify()` needed; `http://` API URLs; PII in logs/URLs.
**Enforce:** argon2id/bcrypt/scrypt only for passwords; `crypto.randomBytes`/`crypto.randomUUID` for all secrets; keys in secrets manager/env; verify every JWT with pinned algorithm/issuer/audience/expiry; TLS everywhere.

### A05:2025 — Injection

**Detect:** template literals/concat in queries (`` `SELECT ... ${id}` ``, `$queryRawUnsafe`, `knex.raw` with input); `child_process.exec(userInput)`; `eval()`/`new Function()` on request data; `dangerouslySetInnerHTML` without DOMPurify; user `href` allowing `javascript:`; raw `req.body` in Mongo `find()` (`{ $gt: "" }` operator injection).
**Enforce:** parameterized queries everywhere (hard rule 5); `execFile`/`spawn` with arg arrays; DOMPurify on any raw HTML sink; zod validation + type coercion at every boundary before input reaches a query.

### A06:2025 — Insecure Design

**Detect:** auth/reset/checkout endpoints with no rate limit; client-computed prices/totals/roles trusted server-side; recovery flows leaking account existence; multi-tenant queries not centrally scoped by `tenantId`.
**Enforce:** recompute every price/permission server-side; rate limiting + generic responses on enumeration-prone endpoints; short written threat model (decision doc) before features touching money, auth, or tenant data.

### A07:2025 — Authentication Failures

**Detect:** session cookies without `httpOnly`/`secure`/`sameSite`; JWTs in `localStorage`; no session rotation on login; logout that only clears client state; `===` on tokens; weak password rules; no lockout on `/login`.
**Enforce:** `httpOnly` + `secure` + `sameSite` on session cookies; rotate on auth/privilege change, invalidate server-side on logout; constant-time comparison (`crypto.timingSafeEqual`, `bcrypt.compare`); rate limit + lockout on credential endpoints.

### A08:2025 — Software or Data Integrity Failures

**Detect:** `_.merge`/spread of user JSON onto models (prototype pollution via `__proto__`); eval-based deserializers; CDN `<script>` without SRI; webhooks processed without signature verification; `curl … | sh` in CI.
**Enforce:** verify webhook signatures on the raw body before parsing; guard merges against `__proto__`/`constructor` (or `structuredClone`/`Object.create(null)`); SRI on external scripts; checksums on anything downloaded at build/runtime.

### A09:2025 — Security Logging & Alerting Failures

**Detect:** empty `catch {}` on auth/payment paths; no structured logger; auth events unlogged; `logger.info({ password, token })`; raw user input interpolated into log strings; no alerting destination.
**Enforce:** log every auth-relevant event (login success/failure, denial, privilege change) with user ID, timestamp, IP; central redaction (pino `redact`); wire high-value failures to alerting; forbid silent catches on security paths.

### A10:2025 — Mishandling of Exceptional Conditions

**Detect:** fail-open auth (`try { verify(token) } catch { /* continue */ }`, `next()` in catch, permission defaulting `true` on error); unhandled async route rejections; `err.stack` sent to clients; check-then-act on balances/inventory without a transaction (TOCTOU); `fs.existsSync` before open.
**Enforce:** fail closed — any error in an auth/permission/validation path denies the request; single error middleware, generic messages out, detail to logs; atomic conditional updates/transactions for state-changing sequences; handle every promise rejection.

---

## 2. OWASP API Security Top 10:2023

Apply to every API route handler, tRPC procedure, and server action.

### API1 — Broken Object Level Authorization (BOLA)

**Detect:** `prisma.x.findUnique({ where: { id: input.id } })` with no `userId`/`orgId` scoping; `requireAuth` middleware but no per-record check; delete/update by client ID unscoped; `[id]` route handlers never referencing `session.user.id`.
**Enforce:** every client-supplied-ID query also filters by the authenticated principal or runs `canAccess(user, resource)`; centralize in one policy layer; ID randomness (UUID/cuid) is never authorization.

### API2 — Broken Authentication

**Detect:** `jwt.verify` with unset `algorithms` or `'none'` accepted; `process.env.JWT_SECRET || 'dev-secret'` fallbacks; no rate limit on `/api/auth/*`; plaintext password comparison; tokens in query strings; cookies missing `httpOnly`/`secure`/`sameSite`.
**Enforce:** vetted auth library (Auth.js, Lucia, Clerk) or `jwt.verify` with pinned algorithm/issuer/audience/expiry; rate limiting + generic errors on all credential endpoints; argon2id/bcrypt (cost ≥ 12); re-auth for sensitive changes.

### API3 — Broken Object Property Level Authorization

**Detect:** `res.json(user)` returning raw ORM entities (leaking `passwordHash`, `role`, internal flags); `update({ data: req.body })` mass assignment; zod `.passthrough()`/`z.record(z.any())` on write inputs; admin-only fields (`isAdmin`, `credits`) in client-writable schemas.
**Enforce:** explicit `select`/DTO on every response — never raw entities; strict allowlist write schemas (`.strict()`), never spread `req.body` into a DB write; privileged properties only via separate admin-authorized endpoints.

### API4 — Unrestricted Resource Consumption

**Detect:** `findMany()` with no `take`; limit inputs without `.max()`; no rate limiter on expensive routes (upload, generation, LLM, email/SMS); `multer()` without `limits`; unbounded `Promise.all(ids.map(fetchExternal))` over client arrays.
**Enforce:** `.min(1).max(100)` bounds on every client-supplied limit/array; default pagination on lists; per-user rate + spend limits on billed operations; explicit body/upload/timeout limits.

### API5 — Broken Function Level Authorization (BFLA)

**Detect:** `/api/admin/*` behind the same `protectedProcedure` as user routes with no role check; role checks client-side only; one HTTP method checked but not others in the same route file; role from `req.body.role` or `x-user-role` header.
**Enforce:** server-side role assertion (`adminProcedure`, `requireRole('admin')`) on every privileged handler, deny by default; roles only from server-side session/DB; assert authorization per exported method, not per file.

### API6 — Unrestricted Access to Sensitive Business Flows

**Detect:** checkout/referral/coupon endpoints callable in a loop (no rate limit, no bot check); signup with no verification feeding credit-granting flows; `input.price`/`body.total` from client; no idempotency on costly flows.
**Enforce:** layered controls on business-critical flows (velocity limits, bot detection, step-up verification); recompute all amounts server-side; per-user quotas/idempotency keys where repetition damages the business.

### API7 — Server Side Request Forgery (SSRF)

**Detect:** `fetch(input.url)` on webhook registration/import-from-URL/link-preview features; `startsWith('https://')` as validation (bypass: `https://evil.com#@allowed.com`); redirects followed on user-URL fetches; renderers (puppeteer/sharp) on unvalidated URLs.
**Enforce:** scheme + host allowlist via `new URL()`; resolve DNS and reject private/link-local/metadata ranges before connecting and on every redirect; route all user-URL fetches through one hardened helper; never return raw upstream responses.

### API8 — Security Misconfiguration

**Detect:** `cors({ origin: '*', credentials: true })` or reflected `Origin`; `err.stack` in responses; missing helmet/Next headers; `X-Powered-By` on; debug routes/introspection reachable in prod.
**Enforce:** explicit CORS allowlist; global error handler with generic production messages; security headers + pinned, audited dependencies.

### API9 — Improper Inventory Management

**Detect:** `pages/api/*` and `app/api/*` both live; `/api/v1` lacking v2's auth fixes; dead-but-routable handlers (`// TODO: remove`); previews/staging hitting prod DB with `BYPASS_AUTH` flags; no generated OpenAPI/route manifest.
**Enforce:** generated endpoint inventory (OpenAPI from zod/tRPC), CI fails on undocumented routes; delete retired endpoints (410 + sunset dates, don't comment out); same auth middleware in all environments, no prod data in non-prod.

### API10 — Unsafe Consumption of APIs

**Detect:** `await res.json() as SomeType` (cast, not parsed) written to DB; webhook handlers skipping `stripe.webhooks.constructEvent`; fetching URLs found inside third-party payloads; `http://` vendor base URLs.
**Enforce:** zod-parse every third-party response at the boundary — ban `as`-casting external JSON; verify webhook signatures/timestamps on the raw body; TLS with verification for all outbound integrations; treat vendor-supplied URLs/HTML/IDs as untrusted.

---

## 3. ASVS 5.0 verification checklist (target level: L2 for SaaS)

ASVS 5.0.0 (~350 requirements, 17 chapters, IDs `chapter.section.requirement`). L1 = machine-checkable baseline, **L2 = standard for apps handling sensitive data (target this)**, L3 = high assurance. Highest-leverage requirements for a TS/React/Node app:

**Authentication (V6):** 6.2.1 passwords ≥ 8 chars (support 64+) · 6.2.4 reject breached/common passwords (HIBP k-anonymity at L2) · 6.2.7 never block paste/autofill/password managers · 6.3.1 rate limit login per-account (not just per-IP) · 6.3.3 (L2) offer MFA · 6.4.2 no password hints or security questions.

**Session (V7):** 7.2.2 dynamic session tokens, never static API keys as identity · 7.2.3 CSPRNG tokens ≥ 128 bits (`crypto.randomBytes(32)`) · 7.2.4 rotate session on login (fixation) · 7.4.1 server-side invalidation on logout · 7.4.2/7.4.3 kill all sessions on account disable + password change.

**Authorization (V8):** 8.2.1 explicit permission on every endpoint · 8.2.2 scope data to the requester's records (IDOR) · 8.3.1 backend-only enforcement — client checks are UX · 8.4.1 (L2) tenant isolation in every query and job.

**Validation & encoding (V1/V2/V3):** 1.2.4 parameterized DB access only · 1.2.5 parameterized OS commands · 1.2.2 URL protocol allowlist (block `javascript:`/`data:`) · 1.3.1 sanitize untrusted HTML with a battle-tested library · 3.2.2 render untrusted data as text, never `innerHTML` · 2.2.1 positive/allowlist validation of all input · 2.2.2 validate at the service layer even when the client validates.

**Cryptography (V11):** 11.4.2 work-factor KDF for passwords (argon2id/scrypt/bcrypt, tuned) · 11.5.1 CSPRNG for all security-relevant randomness · 11.2.1/11.3.x validated libraries, approved modes (AES-GCM; never ECB, never hand-rolled).

**Errors & logging (V16):** 16.5.1 generic client errors, no stack/SQL leakage · 16.2.5 never log credentials/tokens/payment data (pino `redact`) · 16.3.1/16.3.2 log all authn events and failed authz with metadata · 16.4.1 encode untrusted data before logging (structured JSON, not concat).

**Data protection (V14):** 14.2.1 sensitive data in body/headers only — never URLs/query strings · 14.3.3 no tokens/PII in `localStorage`/`sessionStorage`/IndexedDB · 14.3.2 `Cache-Control: no-store` on sensitive responses.

**Web/API hardening (V3/V4):** 3.5.1 CSRF protection on state-changing cross-origin requests (+ SameSite cookies) · 3.3.1 `Secure` + `__Host-` prefix cookies, `HttpOnly` sessions · 3.4.1–3.4.6 HSTS ≥ 1 year, CSP (`object-src 'none'`, `base-uri 'none'`, `frame-ancestors`), `X-Content-Type-Options: nosniff` · 3.4.2 strict CORS allowlist · 4.1.1 accurate `Content-Type` with charset · 4.3.1/4.3.2 (L2) GraphQL introspection off in prod + depth/cost limits.

---

## 4. OWASP LLM Top 10:2025 (apply to any code calling LLM APIs)

The 2026 cycle produced a _separate_ Agentic Applications list; this remains the canonical LLM Top 10. Apply when reviewing Anthropic/OpenAI SDK calls, agent frameworks, RAG pipelines, or tool use.

### LLM01 — Prompt Injection

**Detect:** untrusted input interpolated into system prompts (`` system: `...${userInput}` ``); RAG/web-fetch output passed to `messages` with no delimiting or role separation; agent loops feeding tool results back with side-effectful tools; no gate between model output and privileged actions.
**Enforce:** system instructions in the `system` parameter only, untrusted content in user-role blocks, clearly delimited; allowlist + confirmation between model output and any privileged side effect (deterministic code authorizes, model only proposes); least-privilege tool scoping.

### LLM02 — Sensitive Information Disclosure

**Detect:** `JSON.stringify(user)`/whole DB rows in prompts; `console.log(messages)` or observability SDKs without redaction; keys/connection strings in prompt templates or tool descriptions; raw prod data in fine-tuning/embedding jobs.
**Enforce:** redact/tokenize PII and secrets before prompts, embeddings, or logs — deny-by-default field allowlist; masking layer on any prompt/completion logging; DLP pass when context may hold other users' data.

### LLM03 — Supply Chain

**Detect:** unpinned agent frameworks/community MCP servers; runtime `baseURL`/model overrides from user-controllable config; models/adapters downloaded without checksums.
**Enforce:** pin exact versions + decision-doc every LLM dependency (hard rule 3); vetted registries with checksum/provenance; review third-party tool code before granting tool-use scopes.

### LLM04 — Data & Model Poisoning

**Detect:** public endpoints upserting to vector stores without authN/authZ; user feedback auto-exported into fine-tuning data; no provenance metadata or dataset versioning.
**Enforce:** gate every training-set/vector-index write behind auth + validation + provenance; quarantine/review before promoting user content into training data; version datasets for rollback.

### LLM05 — Improper Output Handling

**Detect:** model output into `dangerouslySetInnerHTML`/markdown with `html: true` unsanitized; completions into `eval`/`exec`/`db.query(completion)`; model-produced URLs fetched server-side without allowlist.
**Enforce:** treat LLM output exactly like untrusted user input — sanitize, parameterize, allowlist; no dynamic code execution on output (sandbox if code-running is the feature); zod-validate structured outputs, reject on failure.

### LLM06 — Excessive Agency

**Detect:** broad tools (`run_sql`, `execute_shell`, generic `http_request`); admin/service-role credentials in tool handlers; unbounded agent loops with no human-in-the-loop for destructive ops; handlers trusting model-supplied paths/IDs (`fs.rm(args.path)`).
**Enforce:** minimum tool set, minimum scope, per-user credentials; ownership checks inside handlers in deterministic code — never trust model-supplied IDs; human approval for irreversible actions enforced in code, not prompts; cap iterations, rate-limit and log every tool call.

### LLM07 — System Prompt Leakage

**Detect:** secrets/`process.env.X` interpolated into prompts; authorization stated in the prompt with no server-side check; prompts shipped in client bundles.
**Enforce:** no secrets in any prompt — config accessed only by tool handlers; assume the full prompt will be extracted, so all guardrails live in application code; construct prompts server-side only.

### LLM08 — Vector & Embedding Weaknesses

**Detect:** shared index queried without tenant filter/namespace, or filtered client-side after retrieval; ingestion dropping source ACLs; vector DB with default/no auth in production.
**Enforce:** tenant partitioning at the vector-store query level (server-side mandatory filters); re-check source-document permissions at retrieval time for every chunk; authenticated, encrypted vector-store access, moderated ingestion.

### LLM09 — Misinformation

**Detect:** raw completions as fact in regulated domains without citations/grounding; LLM-suggested packages auto-installed (slopsquatting); answers returned when retrieval came back empty; no accuracy evals on critical flows.
**Enforce:** ground high-stakes answers with surfaced citations and coded "I don't know" paths; verify generated code/dependencies (tests, registry-existence checks) before they enter the build; label AI-generated content.

### LLM10 — Unbounded Consumption

**Detect:** public routes calling the LLM with no rate limit or quota; missing `max_tokens`; unbounded history growth; agent loops with no step cap/timeout/budget; `usage` tokens discarded, no spend alerts.
**Enforce:** rate limits + per-user/org token budgets in middleware before any model call; always set `max_tokens`, timeouts, step caps, bounded retries; truncate/summarize history; record usage per request and alert on anomalies.

---

## Sources

Official OWASP, verified 2026-07-26:

- Top 10:2025 — https://owasp.org/Top10/ (per-category: `https://owasp.org/Top10/2025/A0X_2025-<Name>/`)
- API Security Top 10:2023 — https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- ASVS 5.0.0 — https://owasp.org/www-project-application-security-verification-standard/ · https://github.com/OWASP/ASVS/tree/v5.0.0/5.0/en
- LLM Top 10:2025 — https://genai.owasp.org/llm-top-10/ (per-risk: `https://genai.owasp.org/llmrisk/...`)
