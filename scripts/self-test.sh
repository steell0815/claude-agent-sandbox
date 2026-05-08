#!/bin/bash
set -uo pipefail

# self-test.sh — Validate a scaffolded claude-blueprint project
# Run from project root or scripts/ subdirectory. Read-only; never modifies files.
# Exit 0 if all checks pass, exit 1 if any fail.

# --- Resolve project root ---

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

if [[ -f "CLAUDE.md" ]]; then
    PROJECT_ROOT="$(pwd)"
elif [[ -f "../CLAUDE.md" ]]; then
    PROJECT_ROOT="$(cd .. && pwd)"
else
    echo "Error: run from project root or scripts/ directory" >&2
    exit 1
fi

# --- Colors (match setup.sh) ---

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

# --- Stack detection ---

detect_stack() {
    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        echo "ts-node-react"
    elif [[ -f "$PROJECT_ROOT/pom.xml" ]]; then
        echo "java-spring-angular"
    else
        echo "unknown"
    fi
}

STACK=$(detect_stack)

# --- Dependency checks ---

HAS_JQ=false
if command -v jq &>/dev/null; then
    HAS_JQ=true
fi

HAS_GIT=false
if command -v git &>/dev/null; then
    HAS_GIT=true
fi

# ============================================================
# CRITICAL CHECKS (security / correctness)
# ============================================================

echo ""
echo -e "${BOLD}Critical checks${NC}"
echo ""

# 1. No unreplaced {{...}} placeholders in any text file
check_placeholders() {
    local found
    found=$(find "$PROJECT_ROOT" -type f \
        -not -path "*/.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/target/*" \
        -not -path "$SELF" \
        -print0 2>/dev/null \
        | xargs -0 grep -l '{{[A-Z_]*}}' 2>/dev/null \
        | head -20 || true)

    if [[ -n "$found" ]]; then
        fail "Unreplaced {{...}} placeholders found:"
        echo "$found" | while read -r f; do
            echo "         $f"
        done
        return 1
    else
        pass "No unreplaced {{...}} placeholders"
        return 0
    fi
}
check_placeholders

# 2. validate-bash.sh uses dynamic PROJECT_DIR (not a hardcoded placeholder)
check_validate_bash() {
    local hook="$PROJECT_ROOT/.claude/hooks/validate-bash.sh"
    if [[ ! -f "$hook" ]]; then
        fail "validate-bash.sh not found at .claude/hooks/validate-bash.sh"
        return 1
    fi

    if grep -q '/Users/steell/dev/claude-agent-sandbox' "$hook"; then
        fail "validate-bash.sh still contains /Users/steell/dev/claude-agent-sandbox placeholder — security hook disabled"
        return 1
    fi

    if ! grep -q 'PROJECT_DIR=' "$hook"; then
        fail "validate-bash.sh missing PROJECT_DIR assignment"
        return 1
    fi

    # Verify dynamic resolution (git rev-parse or pwd fallback)
    if grep -q 'git rev-parse --show-toplevel' "$hook"; then
        pass "validate-bash.sh uses dynamic PROJECT_DIR (git rev-parse)"
    elif grep -q '^PROJECT_DIR="/' "$hook"; then
        # Fallback: accept hardcoded absolute path (legacy scaffolds)
        pass "validate-bash.sh has absolute PROJECT_DIR"
    else
        fail "validate-bash.sh PROJECT_DIR is not dynamic or absolute"
        return 1
    fi
    return 0
}
check_validate_bash

# 3. settings.json is valid JSON with required structure
check_settings() {
    local settings="$PROJECT_ROOT/.claude/settings.json"
    if [[ ! -f "$settings" ]]; then
        fail "settings.json not found at .claude/settings.json"
        return 1
    fi

    if [[ "$HAS_JQ" == "false" ]]; then
        warn "settings.json — skipped (jq not available)"
        return 0
    fi

    if ! jq empty "$settings" 2>/dev/null; then
        fail "settings.json is not valid JSON"
        return 1
    fi

    local errors=0

    # Check hooks configured
    local hook_count
    hook_count=$(jq '.hooks.PreToolUse | length' "$settings" 2>/dev/null)
    if [[ "$hook_count" == "null" ]] || [[ "$hook_count" -lt 1 ]]; then
        fail "settings.json missing hooks.PreToolUse configuration"
        errors=1
    fi

    # Check permissions.allow exists and is non-empty
    local allow_count
    allow_count=$(jq '.permissions.allow | length' "$settings" 2>/dev/null)
    if [[ "$allow_count" == "null" ]] || [[ "$allow_count" -lt 1 ]]; then
        fail "settings.json missing or empty permissions.allow"
        errors=1
    fi

    # Check permissions.deny exists and is non-empty
    local deny_count
    deny_count=$(jq '.permissions.deny | length' "$settings" 2>/dev/null)
    if [[ "$deny_count" == "null" ]] || [[ "$deny_count" -lt 1 ]]; then
        fail "settings.json missing or empty permissions.deny"
        errors=1
    fi

    if [[ "$errors" -eq 0 ]]; then
        pass "settings.json is valid with hooks and permissions"
    fi
    return "$errors"
}
check_settings

# 4. plans/index.json is valid JSON with required keys
check_plan_index() {
    local index="$PROJECT_ROOT/plans/index.json"
    if [[ ! -f "$index" ]]; then
        fail "plans/index.json not found"
        return 1
    fi

    if [[ "$HAS_JQ" == "false" ]]; then
        warn "plans/index.json — skipped (jq not available)"
        return 0
    fi

    if ! jq empty "$index" 2>/dev/null; then
        fail "plans/index.json is not valid JSON"
        return 1
    fi

    local has_version has_plans
    has_version=$(jq 'has("version")' "$index" 2>/dev/null)
    has_plans=$(jq 'has("plans")' "$index" 2>/dev/null)

    if [[ "$has_version" != "true" ]] || [[ "$has_plans" != "true" ]]; then
        fail "plans/index.json missing 'version' or 'plans' key"
        return 1
    fi

    pass "plans/index.json is valid with version and plans"
    return 0
}
check_plan_index

# ============================================================
# IMPORTANT CHECKS (functionality)
# ============================================================

echo ""
echo -e "${BOLD}Functionality checks${NC}"
echo ""

# 5. Directory structure — all required dirs exist
check_directories() {
    local dirs=(
        ".claude/skills"
        ".claude/hooks"
        ".agents/tools"
        ".agents/config"
        ".agents/workflows"
        "plans/results"
        "scripts"
        "docs"
        ".github/workflows"
        ".github/prompts"
    )
    local missing=()
    for d in "${dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$d" ]]; then
            missing+=("$d")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing directories (${#missing[@]}):"
        for m in "${missing[@]}"; do
            echo "         $m"
        done
        return 1
    fi

    pass "All 10 required directories present"
    return 0
}
check_directories

# 6. All skills present — 7 core + 4 stack-specific
check_skills() {
    local core_skills=(commit push plan plan-status complete-plan implement-feature review-pr add-adr add-guardrail check-guardrails harvest-knowledge analyze-repo assess-readiness decompose init sync-jira agents dashboard capabilities)
    local stack_skills=()

    if [[ "$STACK" == "ts-node-react" ]]; then
        stack_skills=(init-ddd-project setup-ci setup-husky test-server)
    elif [[ "$STACK" == "java-spring-angular" ]]; then
        stack_skills=(init-ddd-project setup-ci setup-pre-commit test-server)
    fi

    local missing=()
    for s in "${core_skills[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/.claude/skills/$s/SKILL.md" ]]; then
            missing+=("$s")
        fi
    done
    if [[ ${#stack_skills[@]} -gt 0 ]]; then
        for s in "${stack_skills[@]}"; do
            if [[ ! -f "$PROJECT_ROOT/.claude/skills/$s/SKILL.md" ]]; then
                missing+=("$s (stack)")
            fi
        done
    fi

    local expected_count=$((${#core_skills[@]} + ${#stack_skills[@]}))

    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing skills (${#missing[@]} of $expected_count):"
        for m in "${missing[@]}"; do
            echo "         $m"
        done
        return 1
    fi

    if [[ "$STACK" == "unknown" ]]; then
        pass "All ${#core_skills[@]} core skills present (stack not detected — stack skills not checked)"
    else
        pass "All $expected_count skills present (${#core_skills[@]} core + ${#stack_skills[@]} stack)"
    fi
    return 0
}
check_skills

# 7. All *.sh files executable
check_sh_executable() {
    local non_exec
    non_exec=$(find "$PROJECT_ROOT" -name "*.sh" -not -path "*/.git/*" -not -perm -u+x 2>/dev/null || true)

    if [[ -n "$non_exec" ]]; then
        local count
        count=$(echo "$non_exec" | wc -l | tr -d ' ')
        fail "$count .sh files not executable:"
        echo "$non_exec" | head -5 | while read -r f; do
            echo "         $f"
        done
        return 1
    fi

    pass "All .sh files are executable"
    return 0
}
check_sh_executable

# 8. Agent tools present and executable
check_agent_tools() {
    local tools=(commit-preparer.sh plan-tracker.sh spawn-task.sh worktree-manager.sh)
    local missing=()
    local non_exec=()

    for t in "${tools[@]}"; do
        local path="$PROJECT_ROOT/.agents/tools/$t"
        if [[ ! -f "$path" ]]; then
            missing+=("$t")
        elif [[ ! -x "$path" ]]; then
            non_exec+=("$t")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing agent tools: ${missing[*]}"
        return 1
    fi

    if [[ ${#non_exec[@]} -gt 0 ]]; then
        fail "Agent tools not executable: ${non_exec[*]}"
        return 1
    fi

    pass "All 4 agent tools present and executable"
    return 0
}
check_agent_tools

# 9. CI workflows exist, no placeholders
check_ci_workflows() {
    local workflows=(ci.yml sast.yml dast.yml git-integrity.yml)
    local missing=()
    local placeholder_errors=()

    for w in "${workflows[@]}"; do
        local path="$PROJECT_ROOT/.github/workflows/$w"
        if [[ ! -f "$path" ]]; then
            missing+=("$w")
        elif grep -q '{{[A-Z_]*}}' "$path"; then
            placeholder_errors+=("$w")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing workflows: ${missing[*]}"
        return 1
    fi

    if [[ ${#placeholder_errors[@]} -gt 0 ]]; then
        fail "Workflows with unreplaced placeholders: ${placeholder_errors[*]}"
        return 1
    fi

    pass "All ${#workflows[@]} CI workflows present with no placeholders"
    return 0
}
check_ci_workflows

# 10. Documentation files present
check_docs() {
    local docs=(CLAUDE.md CONTRIBUTING.md SECURITY.md docs/glossary.md)
    local missing=()

    for d in "${docs[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$d" ]]; then
            missing+=("$d")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        fail "Missing documentation (${#missing[@]}):"
        for m in "${missing[@]}"; do
            echo "         $m"
        done
        return 1
    fi

    pass "All documentation files present"
    return 0
}
check_docs

# 10b. Guardrail pattern files present
check_guardrail_patterns() {
    local patterns_dir="$PROJECT_ROOT/scripts/guardrails/patterns"
    if [[ ! -d "$patterns_dir" ]]; then
        fail "Guardrail patterns directory not found at scripts/guardrails/patterns"
        return 1
    fi
    if [[ ! -f "$patterns_dir/common.patterns" ]]; then
        fail "common.patterns not found in guardrail patterns directory"
        return 1
    fi
    # Stack-specific check
    if [[ "$STACK" == "ts-node-react" ]] && [[ ! -f "$patterns_dir/ts-node.patterns" ]]; then
        fail "ts-node.patterns not found for $STACK stack"
        return 1
    fi
    if [[ "$STACK" == "java-spring-angular" ]] && [[ ! -f "$patterns_dir/java-spring.patterns" ]]; then
        fail "java-spring.patterns not found for $STACK stack"
        return 1
    fi
    # Check v2 engine exists and is executable
    if [[ ! -x "$PROJECT_ROOT/scripts/guardrails/guardrails-check-v2.sh" ]]; then
        fail "guardrails-check-v2.sh not found or not executable"
        return 1
    fi
    pass "Guardrail pattern files present"
    return 0
}
check_guardrail_patterns

# ============================================================
# ENVIRONMENT CHECKS
# ============================================================

echo ""
echo -e "${BOLD}Environment checks${NC}"
echo ""

# 11. Runtime dependencies
check_dependencies() {
    local all_ok=true

    if [[ "$HAS_JQ" == "true" ]]; then
        pass "jq available"
    else
        fail "jq not found — required for plan-index.sh and hooks"
        all_ok=false
    fi

    if [[ "$HAS_GIT" == "true" ]]; then
        pass "git available"
    else
        fail "git not found — required for version control"
        all_ok=false
    fi

    if command -v uuidgen &>/dev/null; then
        pass "uuidgen available"
    else
        warn "uuidgen not found — plan-index.sh will fall back to random ID"
    fi

    if [[ "$all_ok" == "false" ]]; then
        return 1
    fi
    return 0
}
check_dependencies

# 12. Git state
check_git_state() {
    if [[ "$HAS_GIT" == "false" ]]; then
        warn "Git state — skipped (git not available)"
        return 0
    fi

    if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        fail "Git repository not initialized"
        return 1
    fi

    local commit_count
    commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
    if [[ "$commit_count" -lt 1 ]]; then
        fail "No commits found in git repository"
        return 1
    fi

    pass "Git repository initialized with $commit_count commit(s)"

    # Warn if working tree is dirty (non-blocking)
    if ! git -C "$PROJECT_ROOT" diff --quiet 2>/dev/null || \
       ! git -C "$PROJECT_ROOT" diff --cached --quiet 2>/dev/null; then
        warn "Working tree has uncommitted changes"
    fi

    return 0
}
check_git_state

# 13. Git hooks installed
check_git_hooks() {
    if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        warn "Git hooks — skipped (.git not found)"
        return 0
    fi

    local errors=0

    if [[ -x "$PROJECT_ROOT/.git/hooks/pre-commit" ]]; then
        pass "Git pre-commit hook installed and executable"
    else
        fail "Git pre-commit hook not installed at .git/hooks/pre-commit"
        errors=1
    fi

    if [[ -x "$PROJECT_ROOT/.git/hooks/commit-msg" ]]; then
        pass "Git commit-msg hook installed and executable"
    else
        fail "Git commit-msg hook not installed at .git/hooks/commit-msg"
        errors=1
    fi

    return "$errors"
}
check_git_hooks

# ============================================================
# SUMMARY
# ============================================================

echo ""
echo "────────────────────────────────────"
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
echo -e "  ${GREEN}$PASS_COUNT passed${NC}  ${RED}$FAIL_COUNT failed${NC}  ${YELLOW}$WARN_COUNT warnings${NC}  ($TOTAL checks)"

if [[ "$STACK" != "unknown" ]]; then
    echo -e "  Stack: $STACK"
fi
echo "────────────────────────────────────"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
exit 0
