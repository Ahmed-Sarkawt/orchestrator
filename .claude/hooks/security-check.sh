#!/usr/bin/env bash
# PostToolUse for Write/Edit/MultiEdit — deterministic OWASP-aligned security scan
# of the file just saved. Non-blocking (always exit 0): findings are injected as
# additionalContext so Claude fixes them immediately, and the code-reviewer +
# owasp-security skill remain the thorough gate at /review time.
# Each check maps to an OWASP Top 10 2021 category (stable IDs used for grep-ability).
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Only scan source files; skip vendored/config/doc locations
case "$FILE_PATH" in
  */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*) exit 0 ;;
  */.claude/*|*/docs/*|*.md|*.txt|*.lock|*.log|*.example) exit 0 ;;
esac
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rb|*.java|*.php|*.sql|*.prisma|*.graphql|*.env|*.yml|*.yaml|*.json) ;;
  *) exit 0 ;;
esac

FINDINGS=""
add_finding() { FINDINGS="${FINDINGS}• [$1] $2"$'\n'; }

# Helper: grep the file, capture first matching line number for the report
check() {
  local id="$1" msg="$2" pattern="$3"
  local line
  line=$(grep -nE "$pattern" "$FILE_PATH" 2>/dev/null | head -1 | cut -d: -f1)
  [[ -n "$line" ]] && add_finding "$id" "$msg (line $line)"
}

# A02:2021 Cryptographic Failures — hardcoded secrets & keys
check "A02 secrets" "Possible hardcoded credential/API key" \
  "(AKIA[0-9A-Z]{16}|sk-ant-[A-Za-z0-9_-]{10,}|sk-[A-Za-z0-9]{32,}|ghp_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)"
check "A02 secrets" "Secret-looking assignment with a literal value" \
  "(password|passwd|secret|api_?key|auth_?token|private_?key)['\"]?[[:space:]]*[:=][[:space:]]*['\"][^'\"[:space:]]{8,}['\"]"
# A02 — weak crypto primitives for security purposes
check "A02 crypto" "Weak hash (md5/sha1) — do not use for passwords or signatures" \
  "createHash\(['\"](md5|sha1)['\"]\)|hashlib\.(md5|sha1)\("
check "A02 crypto" "Math.random() is not cryptographically secure — use crypto.randomUUID/randomBytes for tokens" \
  "(token|secret|nonce|otp|session[A-Za-z]*)[^=]{0,20}=[^=].{0,40}Math\.random"
check "A02 tls" "TLS verification disabled" \
  "rejectUnauthorized[[:space:]]*:[[:space:]]*false|NODE_TLS_REJECT_UNAUTHORIZED[[:space:]]*=[[:space:]]*['\"]?0"

# A03:2021 Injection — SQL built from interpolation/concatenation
check "A03 sqli" "SQL built with template interpolation — parameterize instead (CLAUDE.md hard rule 5)" \
  "[\"'\`][[:space:]]*(SELECT|INSERT|UPDATE|DELETE)[[:space:]][^\"'\`]*\\\$\{"
check "A03 sqli" "SQL built with string concatenation — parameterize instead" \
  "[\"'\`](SELECT |INSERT |UPDATE |DELETE )[^\"'\`]*[\"'\`][[:space:]]*\+[[:space:]]*[A-Za-z_]"
# A03 — command injection
check "A03 cmd" "Shell exec with interpolated input — use execFile/spawn with arg arrays" \
  "(exec|execSync)\([\"'\`][^\"'\`]*\\\$\{"
# A03 — code injection / XSS sinks
check "A03 eval" "eval()/new Function() — code injection sink" \
  "\beval\(|new Function\("
check "A03 xss" "Raw HTML sink (dangerouslySetInnerHTML/innerHTML/document.write) — sanitize or use JSX text" \
  "dangerouslySetInnerHTML|\.innerHTML[[:space:]]*=|document\.write\("

# A05:2021 Security Misconfiguration
check "A05 cors" "CORS wildcard origin — scope to known origins" \
  "(origin|Access-Control-Allow-Origin)[\"']?[[:space:]]*[:=][[:space:]]*[\"']\*[\"']"
# A07:2021 Identification & Authentication Failures
check "A07 jwt" "JWT decoded without verification or with 'none' algorithm" \
  "jwt\.decode\(|algorithms?[\"']?[[:space:]]*[:=][[:space:]]*\[?[\"']none[\"']"

[[ -z "$FINDINGS" ]] && exit 0

# Log findings count to the session log
if [[ -f ".claude/.current-session-id" ]]; then
  COUNT=$(printf '%s' "$FINDINGS" | grep -c "^•" 2>/dev/null || echo "0")
  DATA=$(jq -n --arg fp "$FILE_PATH" --argjson n "${COUNT:-0}" \
    '{file_path: $fp, findings: $n}' 2>/dev/null) || DATA="{}"
  bash .claude/hooks/session-logger.sh "security_warning" "$DATA" 2>/dev/null || true
fi

jq -n --arg fp "$FILE_PATH" --arg findings "$FINDINGS" '{
  "additionalContext": ("⚠ SECURITY (OWASP) — `" + $fp + "` matched deterministic risk patterns:\n" + $findings + "Fix each finding now, or state explicitly why it is a false positive. Consult the `owasp-security` skill for remediation guidance. These are heuristics — absence of warnings is NOT a clean bill of health; /review runs the full check.")
}'
exit 0
