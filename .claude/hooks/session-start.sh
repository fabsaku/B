#!/bin/bash
# Installs the Agent Reach CLI (https://github.com/Panniantong/agent-reach)
# and its zero-config upstream tools in Claude Code cloud sessions.
# The matching skill lives in .claude/skills/agent-reach/.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

AGENT_REACH_REV="94f06c1969dfc1834001269d79d3ad0972d9dee6"
VENV="$HOME/.agent-reach-venv"
BIN="$HOME/.local/bin"

# Agent Reach CLI (+ yt-dlp, feedparser) in a dedicated venv, pinned to a commit.
# Note: the "agent-reach" package on PyPI is a different project.
if [ "$(cat "$VENV/.installed-rev" 2>/dev/null)" != "$AGENT_REACH_REV" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check \
    "git+https://github.com/Panniantong/agent-reach.git@$AGENT_REACH_REV"
  echo "$AGENT_REACH_REV" > "$VENV/.installed-rev"
fi

mkdir -p "$BIN"
ln -sf "$VENV/bin/agent-reach" "$BIN/agent-reach"
ln -sf "$VENV/bin/yt-dlp" "$BIN/yt-dlp"

# mcporter (Exa web search over MCP) and undici (Node.js proxy support).
command -v mcporter >/dev/null 2>&1 || npm install -g --silent mcporter
[ -e "$(npm root -g)/undici/index.js" ] || npm install -g --silent undici
if ! grep -q '"exa"' "$HOME/.mcporter/mcporter.json" 2>/dev/null; then
  mcporter config add exa https://mcp.exa.ai/mcp --scope home >/dev/null
fi

# Let yt-dlp use Node.js as its JS runtime for YouTube.
YTDLP_CONFIG="$HOME/.config/yt-dlp/config"
if ! grep -q -- '--js-runtimes' "$YTDLP_CONFIG" 2>/dev/null; then
  mkdir -p "$(dirname "$YTDLP_CONFIG")"
  echo "--js-runtimes node" >> "$YTDLP_CONFIG"
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
