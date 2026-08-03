#!/usr/bin/env bash
# claude-boilerplate setup script
#
# Interactive (human at a terminal):
#   bash setup.sh
#
# Non-interactive (Claude Code or CI):
#   bash setup.sh --mode auto --name "My App" --desc "A task manager for devs"
#   bash setup.sh --mode advanced --name "My App" --desc "..." \
#     --frontend src --backend server --test-runner vitest \
#     --push-strategy branch --model-tier balanced \
#     --format-on-save yes --session-logs yes \
#     --commit-signing no --branch-prefix feat \
#     --review-sensitivity strict --agent-teams no --research-log no \
#     --detach-git yes --fresh-git no
#
# Inspect current config:
#   bash setup.sh --print-config
#
# Preview changes without applying:
#   bash setup.sh --dry-run [other flags]
set -euo pipefail

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'

CONFIG_FILE=".claude/setup-config.json"

# ── Defaults ───────────────────────────────────────────────────────────────────
SETUP_MODE=""
PROJECT_NAME=""
PROJECT_DESC=""
SUCCESS_METRIC=""
FRONTEND_DIR="src"
BACKEND_DIR="server"
TEST_RUNNER="vitest"
PUSH_STRATEGY="branch"
MODEL_TIER="balanced"
FORMAT_ON_SAVE=true
SESSION_LOGS=true
COMMIT_SIGNING=false
BRANCH_PREFIX=""
REVIEW_SENSITIVITY="strict"
AGENT_TEAMS=true
RESEARCH_LOG=false
EXTRA_RULES=""
NON_INTERACTIVE=false
DRY_RUN=false
PRINT_CONFIG=false
DETACH_GIT="yes"
FRESH_GIT=false
# Remotes matching this pattern are the boilerplate's own repo — a new project
# must never push there. Detected and detached during setup.
BOILERPLATE_ORIGIN_PATTERN='github\.com[:/]Ahmed-Sarkawt/(orchestrator|claude-boilerplate)'

# ── Flag parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)               SETUP_MODE="$2";                                    shift 2 ;;
    --name)               PROJECT_NAME="$2";                                  shift 2 ;;
    --desc)               PROJECT_DESC="$2";                                  shift 2 ;;
    --metric)             SUCCESS_METRIC="$2";                                shift 2 ;;
    --frontend)           FRONTEND_DIR="$2";                                  shift 2 ;;
    --backend)            BACKEND_DIR="$2";                                   shift 2 ;;
    --test-runner)        TEST_RUNNER="$2";                                   shift 2 ;;
    --push-strategy)      PUSH_STRATEGY="$2";                                 shift 2 ;;
    --model-tier)         MODEL_TIER="$2";                                    shift 2 ;;
    --format-on-save)     [[ "$2" == "no" ]] && FORMAT_ON_SAVE=false;         shift 2 ;;
    --session-logs)       [[ "$2" == "no" ]] && SESSION_LOGS=false;           shift 2 ;;
    --commit-signing)     [[ "$2" == "yes" ]] && COMMIT_SIGNING=true;         shift 2 ;;
    --branch-prefix)      BRANCH_PREFIX="$2";                                 shift 2 ;;
    --review-sensitivity) REVIEW_SENSITIVITY="$2";                            shift 2 ;;
    --agent-teams)        [[ "$2" == "yes" ]] && AGENT_TEAMS=true;            shift 2 ;;
    --research-log)       [[ "$2" == "yes" ]] && RESEARCH_LOG=true;           shift 2 ;;
    --detach-git)         DETACH_GIT="$2";                                    shift 2 ;;
    --fresh-git)          [[ "$2" == "yes" ]] && FRESH_GIT=true;              shift 2 ;;
    --extra-rules)        EXTRA_RULES="$2";                                   shift 2 ;;
    --dry-run)            DRY_RUN=true;                                       shift ;;
    --print-config)       PRINT_CONFIG=true;                                  shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# If any config flag was provided, skip interactive prompts
[[ -n "$SETUP_MODE$PROJECT_NAME$PROJECT_DESC" ]] && NON_INTERACTIVE=true

# ── Helpers ────────────────────────────────────────────────────────────────────
ok()  { echo -e "${GREEN}✓${RESET} $1"; }
dr()  { echo -e "  ${DIM}[dry-run] $1${RESET}"; }
# Run an action or print it in dry-run mode
act() {
  local desc="$1"; shift
  if [[ "$DRY_RUN" == true ]]; then dr "$desc"; else "$@" && ok "$desc"; fi
}

ask() {
  local prompt="$1" default="${2:-}"
  if [[ "$NON_INTERACTIVE" == true ]]; then echo "${default}"; return; fi
  if [[ -n "$default" ]]; then
    read -rp "$(echo -e "${CYAN}${prompt}${RESET} [${default}]: ")" answer
  else
    read -rp "$(echo -e "${CYAN}${prompt}${RESET}: ")" answer
  fi
  echo "${answer:-$default}"
}

confirm() {
  [[ "$NON_INTERACTIVE" == true ]] && return 1
  read -rp "$(echo -e "${CYAN}${1}${RESET} [y/N]: ")" answer
  [[ "${answer,,}" == "y" ]]
}

section() {
  echo -e "\n${BOLD}${1}${RESET}"
  printf '%s\n' "$(echo "$1" | sed 's/./-/g')"
}

safe_replace_in_file() {
  local file="$1" search="$2" replace="$3"
  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}✗ python3 not found — required for safe file updates.${RESET}" >&2
    return 1
  fi
  python3 - "$file" "$search" "$replace" <<'PYEOF'
import sys
file, search, replace = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(file).read()
content = content.replace(search, replace, 1)
open(file, 'w').write(content)
PYEOF
}

update_settings() {
  local filter="$1"
  local tmp
  tmp=$(mktemp)
  jq "$filter" .claude/settings.json > "$tmp" && mv "$tmp" .claude/settings.json
}

# ── --print-config early exit ─────────────────────────────────────────────────
if [[ "$PRINT_CONFIG" == true ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}No config file found at ${CONFIG_FILE}.${RESET}"
    echo "Run 'bash setup.sh' first to generate it."
    exit 0
  fi
  echo -e "${BOLD}Current configuration${RESET} (from ${CONFIG_FILE}):"
  echo ""
  jq -r '
    "  --mode             " + .setup_mode,
    "  --name             \"" + .project_name + "\"",
    "  --desc             \"" + .project_desc + "\"",
    "  --metric           \"" + (.success_metric // "") + "\"",
    "  --frontend         " + .frontend_dir,
    "  --backend          " + (.backend_dir // ""),
    "  --test-runner      " + .test_runner,
    "  --push-strategy    " + .push_strategy,
    "  --model-tier       " + .model_tier,
    "  --format-on-save   " + (if .format_on_save then "yes" else "no" end),
    "  --session-logs     " + (if .session_logs then "yes" else "no" end),
    "  --commit-signing   " + (if .commit_signing then "yes" else "no" end),
    "  --branch-prefix    " + (.branch_prefix // ""),
    "  --review-sensitivity " + .review_sensitivity,
    "  --agent-teams      " + (if .agent_teams then "yes" else "no" end),
    "  --research-log     " + (if .research_log then "yes" else "no" end)
  ' "$CONFIG_FILE"
  echo ""
  echo -e "${DIM}Setup date: $(jq -r '.setup_date' "$CONFIG_FILE")${RESET}"
  exit 0
fi

# ── Read saved config for defaults ────────────────────────────────────────────
if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
  [[ -z "$PROJECT_NAME" ]]      && PROJECT_NAME=$(jq -r '.project_name // empty'      "$CONFIG_FILE")
  [[ -z "$PROJECT_DESC" ]]      && PROJECT_DESC=$(jq -r '.project_desc // empty'      "$CONFIG_FILE")
  [[ -z "$SUCCESS_METRIC" ]]    && SUCCESS_METRIC=$(jq -r '.success_metric // empty'  "$CONFIG_FILE")
  FRONTEND_DIR=$(jq -r --arg d "$FRONTEND_DIR" '.frontend_dir // $d'                  "$CONFIG_FILE")
  BACKEND_DIR=$(jq -r  --arg d "$BACKEND_DIR"  '.backend_dir // $d'                   "$CONFIG_FILE")
  TEST_RUNNER=$(jq -r  --arg d "$TEST_RUNNER"  '.test_runner // $d'                   "$CONFIG_FILE")
  PUSH_STRATEGY=$(jq -r --arg d "$PUSH_STRATEGY" '.push_strategy // $d'              "$CONFIG_FILE")
  MODEL_TIER=$(jq -r   --arg d "$MODEL_TIER"   '.model_tier // $d'                    "$CONFIG_FILE")
  FORMAT_ON_SAVE=$(jq -r '.format_on_save // true'                                    "$CONFIG_FILE")
  SESSION_LOGS=$(jq -r '.session_logs // true'                                        "$CONFIG_FILE")
  COMMIT_SIGNING=$(jq -r 'if .commit_signing then "true" else "false" end'            "$CONFIG_FILE")
  BRANCH_PREFIX=$(jq -r '.branch_prefix // empty'                                     "$CONFIG_FILE")
  REVIEW_SENSITIVITY=$(jq -r --arg d "$REVIEW_SENSITIVITY" '.review_sensitivity // $d' "$CONFIG_FILE")
  AGENT_TEAMS=$(jq -r 'if .agent_teams then "true" else "false" end'                  "$CONFIG_FILE")
  RESEARCH_LOG=$(jq -r 'if .research_log then "true" else "false" end'                "$CONFIG_FILE")
fi

# ── Header ─────────────────────────────────────────────────────────────────────
echo -e "${BOLD}claude-boilerplate setup${RESET}"
[[ "$NON_INTERACTIVE" == true ]] && echo -e "${DIM}Running in non-interactive mode.${RESET}"
[[ "$DRY_RUN" == true ]]         && echo -e "${YELLOW}Dry-run mode — no files will be changed.${RESET}"
[[ -f "$CONFIG_FILE" ]]          && echo -e "${DIM}Loaded defaults from ${CONFIG_FILE}${RESET}"
echo ""

# ── Mode selection (interactive only) ─────────────────────────────────────────
if [[ "$NON_INTERACTIVE" == false && -z "$SETUP_MODE" ]]; then
  echo -e "${BOLD}How do you want to set up?${RESET}"
  echo -e "  ${GREEN}[1]${RESET} Auto      — sensible defaults, two questions only"
  echo -e "  ${DIM}[2]${RESET} Basic     — recommended, 5 questions ${DIM}(default)${RESET}"
  echo -e "  ${DIM}[3]${RESET} Advanced  — all options: models, branches, hooks, and more"
  echo ""
  read -rp "$(echo -e "${CYAN}Mode${RESET} [2]: ")" MODE_CHOICE
  case "${MODE_CHOICE:-2}" in
    1) SETUP_MODE="auto" ;;
    3) SETUP_MODE="advanced" ;;
    *) SETUP_MODE="basic" ;;
  esac
fi
[[ -z "$SETUP_MODE" ]] && SETUP_MODE="basic"
echo -e "Running ${BOLD}${SETUP_MODE}${RESET} setup.\n"

# ── Dependency checks ──────────────────────────────────────────────────────────
section "Checking dependencies"

MISSING_DEPS=false

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}✗ jq not found${RESET} — required for all hooks. Without it, safety guards and context injection silently disable."
  echo "  Install: brew install jq (macOS) | apt install jq (Ubuntu) | https://jqlang.org"
  MISSING_DEPS=true
else
  ok "jq"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}✗ python3 not found${RESET} — required by setup.sh for safe file replacement."
  echo "  Install: brew install python3 (macOS) | apt install python3 (Ubuntu)"
  MISSING_DEPS=true
else
  ok "python3"
fi

if ! command -v claude >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠  Claude Code CLI not found${RESET} — install from https://claude.ai/code before running 'claude'"
else
  ok "claude"
fi

if [[ "$MISSING_DEPS" == true ]]; then
  echo -e "\n${RED}Install missing dependencies before using this boilerplate.${RESET}"
  echo "Setup will still write config files — hooks degrade gracefully until fixed."
fi

# ── 0. Git connection check (every mode) ─────────────────────────────────────
# A new project cloned/copied from the boilerplate must not stay connected to
# the boilerplate's GitHub repo — otherwise commits and pushes land there.
ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
IS_BOILERPLATE_ORIGIN=false
if [[ -n "$ORIGIN_URL" ]] && echo "$ORIGIN_URL" | grep -qE "$BOILERPLATE_ORIGIN_PATTERN"; then
  IS_BOILERPLATE_ORIGIN=true
fi

if [[ "$IS_BOILERPLATE_ORIGIN" == true ]]; then
  section "0. Git connection"
  echo -e "${YELLOW}This folder's git origin points at the boilerplate repo:${RESET}"
  echo -e "  ${DIM}${ORIGIN_URL}${RESET}"
  echo "A new project must not push there. Setup will detach it (git stays, remote is removed)."
  if [[ "$NON_INTERACTIVE" == false ]]; then
    DETACH_ANSWER=$(ask "Detach from the boilerplate repo? Answer no ONLY if you are developing the boilerplate itself (yes/no)" "yes")
    DETACH_ANSWER=$(echo "$DETACH_ANSWER" | tr '[:upper:]' '[:lower:]')
    [[ "$DETACH_ANSWER" == "no" || "$DETACH_ANSWER" == "n" ]] && DETACH_GIT="no"
    if [[ "$DETACH_GIT" != "no" ]] && confirm "Also start a fresh git history? Discards the boilerplate's commit history — say no if you already made your own commits"; then
      FRESH_GIT=true
    fi
  fi
fi

# ── 1. Project basics (every mode) ────────────────────────────────────────────
section "1. Project basics"

[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME=$(ask "Project name" "$(basename "$PWD")")
[[ -z "$PROJECT_DESC" ]] && PROJECT_DESC=$(ask "One sentence: what does this project do and who is it for?")

# ── 2. Basic questions ────────────────────────────────────────────────────────
if [[ "$SETUP_MODE" == "basic" || "$SETUP_MODE" == "advanced" ]]; then
  section "2. Source paths & tooling"
  FRONTEND_DIR=$(ask "Frontend source directory" "$FRONTEND_DIR")
  BACKEND_DIR=$(ask "Backend source directory (leave blank if none)" "$BACKEND_DIR")
  TEST_RUNNER=$(ask "Test runner (vitest/jest)" "$TEST_RUNNER")
  SUCCESS_METRIC=$(ask "Primary success metric (e.g. 'time to first value < 5 min')" "$SUCCESS_METRIC")

  section "3. Multi-worktree coordination"
  echo "Agent Teams lets multiple Claude instances share a task list in parallel worktrees."
  echo "It is enabled by default via settings.json."
  if [[ "$NON_INTERACTIVE" == false ]] && ! confirm "Keep Agent Teams enabled? (recommended)"; then
    AGENT_TEAMS=false
  fi

  if [[ "$NON_INTERACTIVE" == false ]]; then
    section "Docs in git"
    echo "Decision records (docs/decisions/) are always committed — they document why the code is the way it is."
    echo "Research logs (docs/research/) can stay local-only if you prefer."
    if confirm "Also commit research logs to git?"; then RESEARCH_LOG=true; fi
  fi
fi

# ── 3. Advanced questions ─────────────────────────────────────────────────────
if [[ "$SETUP_MODE" == "advanced" ]]; then

  section "4. Git push strategy"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo -e "  ${GREEN}[1]${RESET} Feature branches only ${DIM}(default, safer)${RESET}"
    echo -e "  ${DIM}[2]${RESET} Allow push to main"
    echo ""
    read -rp "$(echo -e "${CYAN}Strategy${RESET} [1]: ")" PUSH_CHOICE
    [[ "${PUSH_CHOICE:-1}" == "2" ]] && PUSH_STRATEGY="main"
  fi

  section "5. Default model tier"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo -e "  ${DIM}[1]${RESET} Economy   — haiku for all agents"
    echo -e "  ${GREEN}[2]${RESET} Balanced  — sonnet primary, haiku utility ${DIM}(default)${RESET}"
    echo -e "  ${DIM}[3]${RESET} Powerful  — opus primary, sonnet utility"
    echo ""
    read -rp "$(echo -e "${CYAN}Tier${RESET} [2]: ")" MODEL_CHOICE
    case "${MODEL_CHOICE:-2}" in
      1) MODEL_TIER="economy" ;;
      3) MODEL_TIER="powerful" ;;
      *) MODEL_TIER="balanced" ;;
    esac
  fi

  section "6. Auto-format on save"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Runs Prettier + the file's sibling test on every file save."
    if ! confirm "Enable?"; then FORMAT_ON_SAVE=false; fi
  fi

  section "7. Session logging"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Writes every prompt and summary to .claude/logs/. Used by /session-log."
    if ! confirm "Enable?"; then SESSION_LOGS=false; fi
  fi

  section "8. Commit signing"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Requires GPG. Sets git config commit.gpgsign=true and adds a CLAUDE.md rule."
    if confirm "Enforce signed commits?"; then COMMIT_SIGNING=true; fi
  fi

  section "9. Branch naming convention"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Examples: feat, fix, claude, chore"
    BRANCH_PREFIX=$(ask "Branch prefix (leave blank to skip)")
  fi

  section "10. Review sensitivity"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo -e "  ${GREEN}[1]${RESET} Strict   — Block, Recommend, and Note ${DIM}(default)${RESET}"
    echo -e "  ${DIM}[2]${RESET} Normal   — Block and Recommend only"
    echo -e "  ${DIM}[3]${RESET} Relaxed  — Block only"
    echo ""
    read -rp "$(echo -e "${CYAN}Sensitivity${RESET} [1]: ")" REVIEW_CHOICE
    case "${REVIEW_CHOICE:-1}" in
      2) REVIEW_SENSITIVITY="normal" ;;
      3) REVIEW_SENSITIVITY="relaxed" ;;
      *) REVIEW_SENSITIVITY="strict" ;;
    esac
  fi

  section "11. Project-specific rules"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    EXTRA_RULES=$(ask "Any project-specific hard rules to add? (leave blank to skip)")
  fi
fi

# ── Apply changes ──────────────────────────────────────────────────────────────
section "$([ "$DRY_RUN" = true ] && echo 'Changes preview (dry-run)' || echo 'Applying changes')"

# CLAUDE.md — project description
DESCRIPTION_LINE="${PROJECT_DESC}"
[[ -n "$SUCCESS_METRIC" ]] && DESCRIPTION_LINE="${DESCRIPTION_LINE} The primary success metric is: ${SUCCESS_METRIC}."
if [[ "$DRY_RUN" == true ]]; then
  dr "Update CLAUDE.md description"
else
  safe_replace_in_file CLAUDE.md \
    "[FILL IN: one paragraph describing the product, the persona you are building for, and the primary success metric.]" \
    "$DESCRIPTION_LINE"
  ok "Updated CLAUDE.md"
fi

# Frontend path
if [[ "$FRONTEND_DIR" != "src" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Update frontend path to ${FRONTEND_DIR}/"
  else
    safe_replace_in_file .claude/rules/frontend.md \
      '"src/**/*.tsx", "src/**/*.jsx"' \
      "\"${FRONTEND_DIR}/**/*.tsx\", \"${FRONTEND_DIR}/**/*.jsx\""
    ok "Updated frontend path to ${FRONTEND_DIR}/"
  fi
fi

# Backend path
if [[ -n "$BACKEND_DIR" && "$BACKEND_DIR" != "server" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Update backend path to ${BACKEND_DIR}/"
  else
    safe_replace_in_file .claude/rules/backend.md '"server/**/*.ts"' "\"${BACKEND_DIR}/**/*.ts\""
    ok "Updated backend path to ${BACKEND_DIR}/"
  fi
fi

# Test runner
if [[ "$TEST_RUNNER" != "vitest" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Update test runner to ${TEST_RUNNER}"
  else
    if [[ "$TEST_RUNNER" == "jest" ]]; then
      safe_replace_in_file .claude/hooks/format-and-test.sh "npx vitest run" "npx jest"
    else
      safe_replace_in_file .claude/hooks/format-and-test.sh "npx vitest run" "npx ${TEST_RUNNER} run"
    fi
    ok "Updated test runner to ${TEST_RUNNER}"
  fi
fi

# Push strategy
if [[ "$PUSH_STRATEGY" == "main" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Allow push to main (ALLOW_PUSH_MAIN=1 → .env.claude)"
  else
    grep -qxF "ALLOW_PUSH_MAIN=1" .env.claude 2>/dev/null || echo "ALLOW_PUSH_MAIN=1" >> .env.claude
    grep -qxF ".env.claude" .gitignore 2>/dev/null || echo ".env.claude" >> .gitignore
    ok "Push to main allowed (.env.claude)"
    echo -e "  ${YELLOW}Source before starting Claude: source .env.claude && claude${RESET}"
  fi
else
  [[ "$DRY_RUN" == true ]] && dr "Push strategy: feature branches only (no change)" \
                             || ok "Push strategy: feature branches only"
fi

# Model tier
if [[ "$MODEL_TIER" != "balanced" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Set model tier: ${MODEL_TIER}"
  else
    PRIMARY_AGENTS=(code-reviewer researcher test-writer ux-auditor)
    UTILITY_AGENTS=(bug-fixer research-executor doc-updater)
    if [[ "$MODEL_TIER" == "economy" ]]; then
      for a in "${PRIMARY_AGENTS[@]}"; do
        safe_replace_in_file ".claude/agents/${a}.md" "model: sonnet" "model: haiku"
      done
    elif [[ "$MODEL_TIER" == "powerful" ]]; then
      for a in "${PRIMARY_AGENTS[@]}"; do
        safe_replace_in_file ".claude/agents/${a}.md" "model: sonnet" "model: opus"
      done
      for a in "${UTILITY_AGENTS[@]}"; do
        safe_replace_in_file ".claude/agents/${a}.md" "model: haiku" "model: sonnet"
      done
    fi
    ok "Model tier: ${MODEL_TIER}"
  fi
fi

# Auto-format on save
if [[ "$FORMAT_ON_SAVE" == false ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Disable auto-format on save (remove format-and-test from settings.json)"
  else
    update_settings \
      '(.hooks.PostToolUse) |= map(select(any(.hooks[]; .command | contains("format-and-test")) | not))'
    ok "Auto-format on save disabled"
  fi
fi

# Session logging
if [[ "$SESSION_LOGS" == false ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Disable session logging (remove UserPromptSubmit + Stop hooks)"
  else
    update_settings 'del(.hooks.UserPromptSubmit) | del(.hooks.Stop)'
    ok "Session logging disabled"
  fi
fi

# Commit signing
if [[ "$COMMIT_SIGNING" == true ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Enforce commit signing (git config commit.gpgsign true + CLAUDE.md rule)"
  else
    git rev-parse --git-dir >/dev/null 2>&1 && git config commit.gpgsign true
    echo "8. **Sign all commits. Always use \`git commit -S\`. Never use \`--no-gpg-sign\`.**" >> CLAUDE.md
    ok "Commit signing enforced"
    echo -e "  ${YELLOW}Requires a GPG key: https://docs.github.com/authentication/managing-commit-signature-verification${RESET}"
  fi
fi

# Branch naming
if [[ -n "$BRANCH_PREFIX" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Add branch naming rule: ${BRANCH_PREFIX}/<description>"
  else
    echo "8. **Branch names must follow \`${BRANCH_PREFIX}/<short-description>\` (e.g. \`${BRANCH_PREFIX}/add-login\`). Never push directly to main unless ALLOW_PUSH_MAIN=1 is set.**" >> CLAUDE.md
    ok "Branch naming convention: ${BRANCH_PREFIX}/<description>"
  fi
fi

# Extra rules
if [[ -n "$EXTRA_RULES" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Add project rule: ${EXTRA_RULES}"
  else
    echo "8. **${EXTRA_RULES}**" >> CLAUDE.md
    ok "Added project-specific rule"
  fi
fi

# Review sensitivity
if [[ "$REVIEW_SENSITIVITY" == "normal" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Set review sensitivity: normal (Block + Recommend only)"
  else
    cat >> .claude/agents/code-reviewer.md <<'EOF'

## Review threshold

Report **🔴 Block** and **🟡 Recommend** findings only. Do not include **🟢 Note** findings in your output.
EOF
    ok "Review sensitivity: normal"
  fi
elif [[ "$REVIEW_SENSITIVITY" == "relaxed" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Set review sensitivity: relaxed (Block only)"
  else
    cat >> .claude/agents/code-reviewer.md <<'EOF'

## Review threshold

Report **🔴 Block** findings only. Do not include **🟡 Recommend** or **🟢 Note** findings in your output.
EOF
    ok "Review sensitivity: relaxed"
  fi
fi

# Agent Teams
if [[ "$AGENT_TEAMS" == true ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Enable Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 → .env.claude)"
  else
    grep -qxF "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" .env.claude 2>/dev/null \
      || echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" >> .env.claude
    grep -qxF ".env.claude" .gitignore 2>/dev/null || echo ".env.claude" >> .gitignore
    ok "Agent Teams enabled"
    echo -e "  ${YELLOW}Source before starting Claude: source .env.claude${RESET}"
  fi
fi

# Git detachment — cut the cord to the boilerplate repo
if [[ "$IS_BOILERPLATE_ORIGIN" == true && "$DETACH_GIT" != "no" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dr "Remove origin remote (${ORIGIN_URL}) — project keeps local git, loses boilerplate connection"
    [[ "$FRESH_GIT" == true ]] && dr "Start fresh git history (discard boilerplate commits, git init anew)"
  else
    git remote remove origin
    ok "Detached from boilerplate repo — origin removed, local git kept"
    if [[ "$FRESH_GIT" == true ]]; then
      GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
      if [[ "$GIT_COMMON_DIR" == ".git" && -d ".git" ]]; then
        rm -rf .git
        git init -q
        ok "Fresh git history started"
      else
        echo -e "  ${YELLOW}Skipped fresh history: this looks like a git worktree — run setup from the main checkout instead.${RESET}"
      fi
    fi
    echo -e "  ${DIM}Add your own remote later: git remote add origin <your-repo-url>${RESET}"
  fi
elif [[ -n "$ORIGIN_URL" ]]; then
  [[ "$DRY_RUN" == true ]] && dr "Origin is your own remote (${ORIGIN_URL}) — kept" \
                             || ok "Origin is your own remote — kept"
fi

# Docs tracking — decisions always committed; research logs opt-in.
# The boilerplate repo ships with both patterns gitignored (its own dev history
# stays local); a real project needs its decision records in the repo.
DOCS_IGNORE_COMMENT="# Project-history docs — boilerplate ships the scaffold (index.md), not this repo's own research/decision content"
if [[ "$DRY_RUN" == true ]]; then
  dr "Track docs/decisions/ in git (always)"
  [[ "$RESEARCH_LOG" == true ]] && dr "Track docs/research/ in git" || dr "Keep docs/research/ local-only (gitignored)"
elif [[ -f .gitignore ]]; then
  (grep -vxF 'docs/decisions/2*.md' .gitignore || true) > .gitignore.setup-tmp && mv .gitignore.setup-tmp .gitignore
  ok "docs/decisions/ tracked in git (always committed)"
  if [[ "$RESEARCH_LOG" == true ]]; then
    (grep -vxF 'docs/research/2*.md' .gitignore || true) > .gitignore.setup-tmp && mv .gitignore.setup-tmp .gitignore
    (grep -vxF "$DOCS_IGNORE_COMMENT" .gitignore || true) > .gitignore.setup-tmp && mv .gitignore.setup-tmp .gitignore
    ok "docs/research/ tracked in git"
  else
    ok "docs/research/ stays local-only (gitignored)"
  fi
fi

# Hooks executable + git init + docs
if [[ "$DRY_RUN" == false ]]; then
  chmod +x .claude/hooks/*.sh
  ok "Made all hooks executable"

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    git init -q
    ok "Initialized git repo"
  fi

  mkdir -p docs/decisions docs/research docs/flow

  if [[ ! -f "docs/decisions/index.md" ]]; then
    printf '# Decisions Index\n\n> One row per decision. Newest at the bottom.\n> Full rationale: `docs/decisions/YYYY-MM-DD_topic.md`\n\n| Date | Decision | Status | File |\n|------|----------|--------|------|\n' \
      > docs/decisions/index.md
    ok "Created docs/decisions/index.md"
  fi

  FIRST_DECISION="docs/decisions/$(date +%Y-%m-%d)_initial-setup.md"
  if [[ ! -f "$FIRST_DECISION" ]]; then
    cat > "$FIRST_DECISION" <<EOF
# Initial Setup

**Date:** $(date +%Y-%m-%d)
**Status:** Active

## Decision
Set up claude-boilerplate for ${PROJECT_NAME}.

## Rationale
${PROJECT_DESC}

## Alternatives considered
N/A — initial project setup.

## Consequences
Claude Code config layer active. All agents, hooks, and commands wired.
EOF
    echo "| $(date +%Y-%m-%d) | Initial setup | Active | [initial-setup.md]($(date +%Y-%m-%d)_initial-setup.md) |" \
      >> docs/decisions/index.md
    ok "Created first decision file"
  fi

  if [[ ! -f "docs/research/index.md" ]]; then
    printf '# Research Index\n\n> One row per research session. Newest at the bottom.\n> Full findings: `docs/research/YYYY-MM-DD_topic.md`\n\n| Date | Topic | Confidence | File |\n|------|-------|------------|------|\n' \
      > docs/research/index.md
    ok "Created docs/research/index.md"
  fi
fi

# ── Write setup-config.json ────────────────────────────────────────────────────
if [[ "$DRY_RUN" == false ]]; then
  jq -n \
    --arg setup_mode        "$SETUP_MODE" \
    --arg project_name      "$PROJECT_NAME" \
    --arg project_desc      "$PROJECT_DESC" \
    --arg success_metric    "$SUCCESS_METRIC" \
    --arg frontend_dir      "$FRONTEND_DIR" \
    --arg backend_dir       "$BACKEND_DIR" \
    --arg test_runner       "$TEST_RUNNER" \
    --arg push_strategy     "$PUSH_STRATEGY" \
    --arg model_tier        "$MODEL_TIER" \
    --argjson format_on_save  "$FORMAT_ON_SAVE" \
    --argjson session_logs    "$SESSION_LOGS" \
    --argjson commit_signing  "$COMMIT_SIGNING" \
    --arg branch_prefix     "$BRANCH_PREFIX" \
    --arg review_sensitivity "$REVIEW_SENSITIVITY" \
    --argjson agent_teams   "$AGENT_TEAMS" \
    --argjson research_log  "$RESEARCH_LOG" \
    --arg setup_date        "$(date +%Y-%m-%d)" \
    '{
      setup_mode:         $setup_mode,
      project_name:       $project_name,
      project_desc:       $project_desc,
      success_metric:     $success_metric,
      frontend_dir:       $frontend_dir,
      backend_dir:        $backend_dir,
      test_runner:        $test_runner,
      push_strategy:      $push_strategy,
      model_tier:         $model_tier,
      format_on_save:     $format_on_save,
      session_logs:       $session_logs,
      commit_signing:     $commit_signing,
      branch_prefix:      $branch_prefix,
      review_sensitivity: $review_sensitivity,
      agent_teams:        $agent_teams,
      research_log:       $research_log,
      setup_date:         $setup_date
    }' > "$CONFIG_FILE"
  ok "Saved config to ${CONFIG_FILE}"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
section "$([ "$DRY_RUN" = true ] && echo 'Summary (no changes made)' || echo 'Done')"
echo -e "Project:          ${BOLD}${PROJECT_NAME}${RESET}"
echo -e "Setup mode:       ${SETUP_MODE}"
echo -e "Frontend:         ${FRONTEND_DIR}/"
[[ -n "$BACKEND_DIR" ]] && echo -e "Backend:          ${BACKEND_DIR}/"
echo -e "Test runner:      ${TEST_RUNNER}"
echo -e "Push strategy:    $([ "$PUSH_STRATEGY" = "main" ] && echo 'allow push to main' || echo 'feature branches only')"
echo -e "Model tier:       ${MODEL_TIER}"
echo -e "Format on save:   $([ "$FORMAT_ON_SAVE" = true ] && echo 'enabled' || echo 'disabled')"
echo -e "Session logging:  $([ "$SESSION_LOGS" = true ] && echo 'enabled' || echo 'disabled')"
echo -e "Commit signing:   $([ "$COMMIT_SIGNING" = true ] && echo 'enabled' || echo 'disabled')"
[[ -n "$BRANCH_PREFIX" ]] && echo -e "Branch prefix:    ${BRANCH_PREFIX}/"
echo -e "Review:           ${REVIEW_SENSITIVITY}"
echo -e "Agent Teams:      $([ "$AGENT_TEAMS" = true ] && echo 'enabled' || echo 'disabled')"
echo -e "Decisions in git: always"
echo -e "Research in git:  $([ "$RESEARCH_LOG" = true ] && echo 'committed' || echo 'local-only')"
if [[ "$IS_BOILERPLATE_ORIGIN" == true ]]; then
  echo -e "Git remote:       $([ "$DETACH_GIT" != "no" ] && echo 'detached from boilerplate — add your own with: git remote add origin <url>' || echo 'kept (boilerplate development mode)')"
fi

if [[ "$DRY_RUN" == false ]]; then
  echo ""
  echo -e "Next steps:"
  echo -e "  1. Fill in ${CYAN}docs/flow/main.md${RESET} with your primary user flow"
  echo -e "  2. ${CYAN}git add .claude/ CLAUDE.md REFERENCE.md docs/ .gitignore${RESET}"
  echo -e "  3. ${CYAN}git commit -m 'chore: add Claude Code configuration'${RESET}"
  echo -e "  4. ${CYAN}claude${RESET}  (then run /init to update any option at any time)"
fi

echo ""
echo -e "${GREEN}$([ "$DRY_RUN" = true ] && echo 'Dry-run complete. No files were changed.' || echo 'Setup complete.')${RESET}"
