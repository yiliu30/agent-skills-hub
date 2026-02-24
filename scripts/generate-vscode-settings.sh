#!/usr/bin/env bash
set -euo pipefail

# Generate VS Code settings snippet for chat.agentSkillsLocations.
# Scans the hub for all skill directories and outputs JSON ready to paste into settings.json.
#
# Usage:
#   ./scripts/generate-vscode-settings.sh
#   ./scripts/generate-vscode-settings.sh --hub-path ~/workspace/agent-skills-hub

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_HUB_PATH="$(dirname "$SCRIPT_DIR")"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

# Parse args
HUB_PATH="$DEFAULT_HUB_PATH"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hub-path) HUB_PATH="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--hub-path <path>]"
            echo "  Generates VS Code chat.agentSkillsLocations settings snippet."
            echo "  --hub-path  Path to agent-skills-hub repo (default: auto-detected)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Convert absolute path to ~/ relative
to_tilde_path() {
    echo "$1" | sed "s|^$HOME|~|"
}

# Collect all skill directories (folders that directly contain SKILL.md files)
locations=()

# Custom skills: point to custom/ so all subdirs are discovered
if [ -d "$HUB_PATH/custom" ]; then
    locations+=("$(to_tilde_path "$HUB_PATH/custom")")
fi

# Third-party: find the parent directory that contains skill subdirectories
for submodule_dir in "$HUB_PATH"/third-party/*/; do
    [ -d "$submodule_dir" ] || continue
    # Look for a skills/ subdirectory (common pattern)
    if [ -d "${submodule_dir}skills" ]; then
        locations+=("$(to_tilde_path "${submodule_dir}skills")")
    else
        # Fallback: point to the submodule root if skills are at top level
        locations+=("$(to_tilde_path "$submodule_dir")")
    fi
done

# Generate JSON
echo ""
echo -e "${CYAN}Add the following to your VS Code settings.json:${NC}"
echo ""
echo -e "${GREEN}// --- agent-skills-hub: skill search paths ---${NC}"
echo '"chat.agentSkillsLocations": ['

last_idx=$(( ${#locations[@]} - 1 ))
for i in "${!locations[@]}"; do
    if [ "$i" -eq "$last_idx" ]; then
        echo "    \"${locations[$i]}\""
    else
        echo "    \"${locations[$i]}\","
    fi
done

echo ']'
echo ""
echo -e "${CYAN}Tip: Place this inside the top-level {} of your settings.json file.${NC}"
echo -e "${CYAN}     User settings:  Ctrl+Shift+P → 'Preferences: Open User Settings (JSON)'${NC}"
echo -e "${CYAN}     Workspace:      .vscode/settings.json${NC}"
