#!/usr/bin/env bash
# install.sh — drop the ecosystem-update skill into your Claude Code home.
#
# Usage:
#   ./install.sh                                    # install to ~/.claude/skills/ecosystem-update
#   CLAUDE_HOME=/custom/path ./install.sh           # override Claude home
#   ./install.sh --link                             # symlink instead of copy (for dev)
#
# Idempotent: re-running just refreshes the skill files and leaves your
# sources.yaml / config.yaml / state file alone.

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SKILL_DIR="$CLAUDE_HOME/skills/ecosystem-update"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE="copy"
if [[ "${1:-}" == "--link" ]]; then
  MODE="link"
fi

mkdir -p "$SKILL_DIR"

install_file() {
  local src="$1"
  local dst="$2"
  if [[ "$MODE" == "link" ]]; then
    ln -sf "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
}

# Always-overwrite files (the skill body and example configs).
install_file "$REPO_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
install_file "$REPO_DIR/sources.example.yaml" "$SKILL_DIR/sources.example.yaml"
install_file "$REPO_DIR/config.example.yaml" "$SKILL_DIR/config.example.yaml"

# First-run scaffolding: only create user configs if they don't exist.
if [[ ! -f "$SKILL_DIR/sources.yaml" ]]; then
  cp "$REPO_DIR/sources.example.yaml" "$SKILL_DIR/sources.yaml"
  echo "created $SKILL_DIR/sources.yaml — edit it to point at the URLs you care about"
fi

if [[ ! -f "$SKILL_DIR/config.yaml" ]]; then
  cp "$REPO_DIR/config.example.yaml" "$SKILL_DIR/config.yaml"
  echo "created $SKILL_DIR/config.yaml — edit paths and limits as needed"
fi

# Ensure the runtime directories exist so the first run can write to them.
mkdir -p "$CLAUDE_HOME/state"
mkdir -p "$CLAUDE_HOME/reports/ecosystem"
mkdir -p "$CLAUDE_HOME/backups"
mkdir -p "$CLAUDE_HOME/logs"

echo
echo "ecosystem-update installed at $SKILL_DIR ($MODE mode)"
echo
echo "next steps:"
echo "  1. edit $SKILL_DIR/sources.yaml — add the URLs you want tracked"
echo "  2. edit $SKILL_DIR/config.yaml — adjust paths/limits if needed"
echo "  3. in Claude Code, run: /ecosystem-update --dry-run"
