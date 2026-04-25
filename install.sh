#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"
CONFIG_DIR="$HOME/.config/catch-me-up"

echo "Installing catch-me-up..."

# Copy command file
mkdir -p "$COMMANDS_DIR"
cp "$SCRIPT_DIR/commands/catch-me-up.md" "$COMMANDS_DIR/catch-me-up.md"
echo "  Installed command to $COMMANDS_DIR/catch-me-up.md"

# Copy example config if no config exists yet
if [[ ! -f "$CONFIG_DIR/config.yaml" && ! -f "$HOME/.catch-me-up.yaml" ]]; then
    mkdir -p "$CONFIG_DIR"
    cp "$SCRIPT_DIR/catch-me-up.example.yaml" "$CONFIG_DIR/config.yaml"
    echo "  Created config at $CONFIG_DIR/config.yaml — edit it with your repos, channels, and page IDs"
else
    echo "  Config already exists, skipping"
fi

echo ""
echo "Done! Restart Claude Code, then use:"
echo "  /catch-me-up        # last 24 hours"
echo "  /catch-me-up 4d     # last 4 days"
echo "  /catch-me-up 1w     # last week"
echo ""
echo "Prerequisites:"
echo "  - gh auth login     (GitHub CLI)"
echo "  - acli auth login   (Atlassian CLI)"
echo "  - Slack MCP plugin  (installed via Claude Code)"
