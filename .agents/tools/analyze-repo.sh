#!/usr/bin/env bash
set -euo pipefail

# analyze-repo.sh - Initialize analysis of an external repository for blueprint evolution
#
# Usage: ./analyze-repo.sh --target <repo-path> [--drift] [--categories adr,testing,cicd,architecture,workflow,stack]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")"

TARGET=""
DRIFT=false
CATEGORIES=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Analyze a git repository for practices to adopt into the blueprint.

Options:
    --target <path>       Path to the git repository to analyze (required)
    --drift               Drift mode — detect evolved practices in a blueprint-derived repo
    --categories <list>   Comma-separated category filter (default: all)
                          Valid categories: adr, testing, cicd, architecture, workflow, stack
    -h, --help            Show this help message

Modes:
    Discover (default)    Analyze any repo for practices worth adopting
    Drift (--drift)       Analyze a blueprint-derived repo for upstream improvements

Examples:
    $(basename "$0") --target ~/projects/my-spring-app
    $(basename "$0") --target ~/projects/my-app --drift
    $(basename "$0") --target ~/projects/my-app --categories adr,testing

Output:
    Creates a task directory at .agents/playgrounds/ANALYSIS-{timestamp}/
    Dispatches analyst agents and produces findings in that directory.
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --target) TARGET="$2"; shift 2 ;;
        --drift) DRIFT=true; shift ;;
        --categories) CATEGORIES="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Error: Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Error: --target is required"
    echo ""
    usage
fi

# Resolve to absolute path
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || {
    echo "Error: Target path does not exist: $TARGET"
    exit 1
}

# Validate target is a git repository
if [[ ! -d "$TARGET/.git" ]]; then
    echo "Error: Target is not a git repository: $TARGET"
    echo "  Expected to find .git/ directory at $TARGET/.git"
    exit 1
fi

# Validate categories if provided
VALID_CATEGORIES="adr testing cicd architecture workflow stack"
if [[ -n "$CATEGORIES" ]]; then
    IFS=',' read -ra CAT_ARRAY <<< "$CATEGORIES"
    for cat in "${CAT_ARRAY[@]}"; do
        if ! echo "$VALID_CATEGORIES" | grep -qw "$cat"; then
            echo "Error: Invalid category: $cat"
            echo "  Valid categories: $VALID_CATEGORIES"
            exit 1
        fi
    done
fi

REPO_NAME=$(basename "$TARGET")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TASK_ID="ANALYSIS-${TIMESTAMP}"

echo "=== Repository Analysis ==="
echo "Target:     $TARGET"
echo "Repo name:  $REPO_NAME"
echo "Mode:       $(if $DRIFT; then echo "drift"; else echo "discover"; fi)"
if [[ -n "$CATEGORIES" ]]; then
    echo "Categories: $CATEGORIES"
else
    echo "Categories: all"
fi
echo ""

# Detect languages
echo "--- Language Detection ---"
LANG_COUNTS=$(find "$TARGET" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/target/*' -not -path '*/build/*' -not -path '*/.gradle/*' -not -path '*/dist/*' -not -path '*/vendor/*' | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15)
echo "$LANG_COUNTS"
echo ""

# Detect frameworks
echo "--- Framework Detection ---"
FRAMEWORKS=""
[[ -f "$TARGET/pom.xml" ]] && FRAMEWORKS="${FRAMEWORKS}Maven/Java, "
[[ -f "$TARGET/build.gradle" || -f "$TARGET/build.gradle.kts" ]] && FRAMEWORKS="${FRAMEWORKS}Gradle/Java, "
[[ -f "$TARGET/package.json" ]] && FRAMEWORKS="${FRAMEWORKS}Node.js, "
[[ -f "$TARGET/requirements.txt" || -f "$TARGET/pyproject.toml" ]] && FRAMEWORKS="${FRAMEWORKS}Python, "
[[ -f "$TARGET/go.mod" ]] && FRAMEWORKS="${FRAMEWORKS}Go, "
[[ -f "$TARGET/Cargo.toml" ]] && FRAMEWORKS="${FRAMEWORKS}Rust, "
[[ -f "$TARGET/Gemfile" ]] && FRAMEWORKS="${FRAMEWORKS}Ruby, "
[[ -f "$TARGET/mix.exs" ]] && FRAMEWORKS="${FRAMEWORKS}Elixir, "
[[ -f "$TARGET/composer.json" ]] && FRAMEWORKS="${FRAMEWORKS}PHP, "

if [[ -f "$TARGET/package.json" ]]; then
    grep -q '"next"' "$TARGET/package.json" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Next.js, "
    grep -q '"react"' "$TARGET/package.json" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}React, "
    grep -q '"@angular/core"' "$TARGET/package.json" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Angular, "
    grep -q '"vue"' "$TARGET/package.json" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Vue, "
    grep -q '"express"' "$TARGET/package.json" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Express, "
    grep -q '"@nestjs/core"' "$TARGET/package.json" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}NestJS, "
fi

if [[ -f "$TARGET/pom.xml" ]]; then
    grep -q "spring-boot" "$TARGET/pom.xml" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Spring Boot, "
    grep -q "quarkus" "$TARGET/pom.xml" 2>/dev/null && FRAMEWORKS="${FRAMEWORKS}Quarkus, "
fi

FRAMEWORKS="${FRAMEWORKS%, }"
if [[ -n "$FRAMEWORKS" ]]; then
    echo "Detected: $FRAMEWORKS"
else
    echo "No known frameworks detected"
fi
echo ""

# Detect if blueprint-derived (for drift mode suggestion)
BLUEPRINT_DERIVED=false
if [[ -d "$TARGET/.claude" && -d "$TARGET/docs/adr" ]]; then
    if ls "$TARGET/docs/adr"/adr-*.md 1>/dev/null 2>&1; then
        BLUEPRINT_DERIVED=true
    fi
fi

if $BLUEPRINT_DERIVED && ! $DRIFT; then
    echo "--- Blueprint Detection ---"
    echo "This repository appears to be blueprint-derived (.claude/ + docs/adr/ structure detected)."
    echo "Consider using --drift mode to detect evolved practices:"
    echo "  $(basename "$0") --target $TARGET --drift"
    echo ""
fi

if $DRIFT && ! $BLUEPRINT_DERIVED; then
    echo "Warning: --drift mode specified but repository does not appear to be blueprint-derived."
    echo "  Expected .claude/ directory and docs/adr/ with ADR files."
    echo "  Proceeding in drift mode anyway, but results may be limited."
    echo ""
fi

# Create task directory
TASK_DIR="$AGENTS_DIR/playgrounds/$TASK_ID"
mkdir -p "$TASK_DIR"

# Write task metadata
cat > "$TASK_DIR/metadata.md" <<EOF
# Analysis Task: $TASK_ID

- **Target**: $TARGET
- **Repo name**: $REPO_NAME
- **Mode**: $(if $DRIFT; then echo "drift"; else echo "discover"; fi)
- **Categories**: ${CATEGORIES:-all}
- **Blueprint-derived**: $BLUEPRINT_DERIVED
- **Frameworks**: ${FRAMEWORKS:-none detected}
- **Created**: $(date -Iseconds)
EOF

echo "=== Task Setup Complete ==="
echo ""
echo "Task ID:    $TASK_ID"
echo "Task dir:   $TASK_DIR"
echo ""
echo "Next steps:"
echo "  1. The analysis-coordinator will load the blueprint baseline"
echo "  2. Specialist analysts will scan the target repo in parallel"
echo "  3. Findings will be ranked, filtered, and written to PRs"
echo "  4. Results will be saved to $TASK_DIR/results.md"
