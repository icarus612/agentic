#!/usr/bin/env bash
# common-helpers.sh - Shared utilities for Claude Code hooks
#
# This file provides common functions, colors, and patterns used across
# multiple hooks to ensure consistency and reduce duplication.

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_debug() {
    [[ "${CLAUDE_HOOKS_DEBUG:-0}" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*" >&2
}

# ============================================================================
# PERFORMANCE TIMING
# ============================================================================

time_start() {
    if [[ "${CLAUDE_HOOKS_DEBUG:-0}" == "1" ]]; then
        echo $(($(date +%s%N)/1000000))
    fi
}

time_end() {
    if [[ "${CLAUDE_HOOKS_DEBUG:-0}" == "1" ]]; then
        local start=$1
        local end=$(($(date +%s%N)/1000000))
        local duration=$((end - start))
        log_debug "Execution time: ${duration}ms"
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Load project configuration
load_project_config() {
    # User-level config
    [[ -f "$HOME/.claude-hooks.conf" ]] && source "$HOME/.claude-hooks.conf"
    
    # Project-level config (highest priority)
    [[ -f ".claude-hooks-config.sh" ]] && source ".claude-hooks-config.sh"
    
    # Always return success
    return 0
}

# ============================================================================
# ERROR TRACKING
# ============================================================================

declare -a CLAUDE_HOOKS_ERRORS=()
declare -i CLAUDE_HOOKS_ERROR_COUNT=0

add_error() {
    local message="$1"
    CLAUDE_HOOKS_ERROR_COUNT+=1
    CLAUDE_HOOKS_ERRORS+=("${RED}❌${NC} $message")
}

print_error_summary() {
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        # Only show failures when there are errors
        echo -e "\n${BLUE}═══ Summary ═══${NC}" >&2
        for item in "${CLAUDE_HOOKS_ERRORS[@]}"; do
            echo -e "$item" >&2
        done
        
        echo -e "\n${RED}Found $CLAUDE_HOOKS_ERROR_COUNT issue(s) that MUST be fixed!${NC}" >&2
        echo -e "${RED}════════════════════════════════════════════${NC}" >&2
        echo -e "${RED}❌ ALL ISSUES ARE BLOCKING ❌${NC}" >&2
        echo -e "${RED}════════════════════════════════════════════${NC}" >&2
        echo -e "${RED}Fix EVERYTHING above until all checks are ✅ GREEN${NC}" >&2
    fi
}

# ============================================================================
# STANDARD HEADERS
# ============================================================================

print_style_header() {
    echo "" >&2
    echo "🔍 Style Check - Validating code formatting..." >&2
    echo "────────────────────────────────────────────" >&2
}

print_test_header() {
    echo "" >&2
    echo "🧪 Test Check - Running tests for edited file..." >&2
    echo "────────────────────────────────────────────" >&2
}

# ============================================================================
# STANDARD EXIT HANDLERS
# ============================================================================

exit_with_success_message() {
    local message="${1:-Continue with your task.}"
    echo -e "\n${GREEN}✅ $message${NC}" >&2
    exit 0
}

exit_with_style_failure() {
    echo -e "\n${RED}🛑 FAILED - Fix all issues above! 🛑${NC}" >&2
    echo -e "${YELLOW}📋 NEXT STEPS:${NC}" >&2
    echo -e "${YELLOW}  1. Fix the issues listed above${NC}" >&2
    echo -e "${YELLOW}  2. Verify the fix by running the lint command again${NC}" >&2
    echo -e "${YELLOW}  3. Continue with your original task${NC}" >&2
    exit 2
}

exit_with_test_failure() {
    local file_path="$1"
    echo -e "\n${RED}════════════════════════════════════════════${NC}" >&2
    echo -e "${RED}❌ TESTS FAILED - BLOCKING ❌${NC}" >&2
    echo -e "${RED}════════════════════════════════════════════${NC}" >&2
    echo -e "${RED}Tests are FAILING after your changes to $file_path${NC}" >&2
    echo -e "\n${RED}🛑 FAILED - Fix all failing tests above! 🛑${NC}" >&2
    echo -e "${YELLOW}📋 NEXT STEPS:${NC}" >&2
    echo -e "${YELLOW}  1. Review the test failures above${NC}" >&2
    echo -e "${YELLOW}  2. Fix the code to make tests pass${NC}" >&2
    echo -e "${YELLOW}  3. Or revert your changes if the tests are correct${NC}" >&2
    echo -e "${YELLOW}  4. Continue ONLY after all tests are ✅ GREEN${NC}" >&2
    exit 2
}

# ============================================================================
# PROJECT TYPE DETECTION
# ============================================================================

detect_project_type() {
    local project_type="unknown"
    local types=()
    
    # Go project
    if [[ -f "go.mod" ]] || [[ -f "go.sum" ]] || [[ -n "$(find . -maxdepth 3 -name "*.go" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("go")
    fi
    
    # Python project
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]] || [[ -n "$(find . -maxdepth 3 -name "*.py" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("python")
    fi
    
    # JavaScript/TypeScript project
    if [[ -f "package.json" ]] || [[ -f "tsconfig.json" ]] || [[ -n "$(find . -maxdepth 3 \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) -type f -print -quit 2>/dev/null)" ]]; then
        types+=("javascript")
    fi
    
    # Rust project
    if [[ -f "Cargo.toml" ]] || [[ -n "$(find . -maxdepth 3 -name "*.rs" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("rust")
    fi
    
    # Nix project
    if [[ -f "flake.nix" ]] || [[ -f "default.nix" ]] || [[ -f "shell.nix" ]]; then
        types+=("nix")
    fi
    
    # Return primary type or "mixed" if multiple
    if [[ ${#types[@]} -eq 1 ]]; then
        project_type="${types[0]}"
    elif [[ ${#types[@]} -gt 1 ]]; then
        project_type="mixed:$(IFS=,; echo "${types[*]}")"
    fi
    
    log_debug "Detected project type: $project_type"
    echo "$project_type"
}