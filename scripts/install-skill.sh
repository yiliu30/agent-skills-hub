#!/usr/bin/env bash
set -euo pipefail

# Install a skill from the hub to a target directory.
#
# Usage:
#   ./scripts/install-skill.sh --list                    # list all skills
#   ./scripts/install-skill.sh <skill-name> <target-dir> # install a skill
#   ./scripts/install-skill.sh git-commit ~/.config/skills/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

usage() {
    echo "Usage:"
    echo "  $0 --list                      List all available skills"
    echo "  $0 <skill-name> <target-dir>   Install a skill to target directory"
    echo ""
    echo "Examples:"
    echo "  $0 --list"
    echo "  $0 git-commit ~/.config/skills/"
    echo "  $0 pdf ./my-project/skills/"
}

list_skills() {
    echo -e "${CYAN}Available skills:${NC}"
    echo ""

    # Custom skills
    if [ -d "$REPO_ROOT/custom" ]; then
        echo -e "${GREEN}── Custom ──${NC}"
        find "$REPO_ROOT/custom" -name "SKILL.md" -type f | sort | while read -r skill_md; do
            skill_dir="$(dirname "$skill_md")"
            skill_name="$(basename "$skill_dir")"
            desc=$(grep -A1 "^description:" "$skill_md" | head -1 | sed 's/^description:\s*//' | sed "s/^['\"]//;s/['\"]$//" | cut -c1-80)
            printf "  %-30s %s\n" "$skill_name" "$desc"
        done
        echo ""
    fi

    # Third-party skills
    if [ -d "$REPO_ROOT/third-party" ]; then
        for source_dir in "$REPO_ROOT"/third-party/*/; do
            source_name="$(basename "$source_dir")"
            echo -e "${YELLOW}── $source_name ──${NC}"
            find "$source_dir" -name "SKILL.md" -type f | sort | while read -r skill_md; do
                skill_dir="$(dirname "$skill_md")"
                skill_name="$(basename "$skill_dir")"
                desc=$(grep -A1 "^description:" "$skill_md" | head -1 | sed 's/^description:\s*//' | sed "s/^['\"]//;s/['\"]$//" | cut -c1-80)
                printf "  %-30s %s\n" "$skill_name" "$desc"
            done
            echo ""
        done
    fi
}

find_skill() {
    local name="$1"
    # Search custom first, then third-party
    for search_dir in "$REPO_ROOT/custom" "$REPO_ROOT/third-party"; do
        if [ -d "$search_dir" ]; then
            result=$(find "$search_dir" -type d -name "$name" | head -1)
            if [ -n "$result" ] && [ -f "$result/SKILL.md" ]; then
                echo "$result"
                return 0
            fi
        fi
    done
    return 1
}

install_skill() {
    local skill_name="$1"
    local target_dir="$2"

    skill_path=$(find_skill "$skill_name") || {
        echo -e "${RED}Error: Skill '$skill_name' not found.${NC}"
        echo "Run '$0 --list' to see available skills."
        exit 1
    }

    mkdir -p "$target_dir/$skill_name"
    cp -r "$skill_path"/* "$target_dir/$skill_name/"

    echo -e "${GREEN}✅ Installed '$skill_name' to $target_dir/$skill_name/${NC}"
    echo "   Source: $skill_path"
}

# Main
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

case "$1" in
    --list|-l)
        list_skills
        ;;
    --help|-h)
        usage
        ;;
    *)
        if [ $# -lt 2 ]; then
            echo -e "${RED}Error: Missing target directory.${NC}"
            usage
            exit 1
        fi
        install_skill "$1" "$2"
        ;;
esac
