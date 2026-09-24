#!/bin/sh
# Omarchy's default coding agent (what its agent keybinding and menu open),
# set the native way: `omarchy default agent <name>`. The agent itself must
# already be installed — on Omarchy, mise installs it from the dotfiles'
# config — so Omarchy doesn't open its install terminal instead.
#
# Heads-up: setting it the native way also LAUNCHES the agent in a new
# terminal (the command ends in `omarchy-agent`), the same as picking one in
# Omarchy's menu. The check keeps that to the first run.
# usage: omarchy-default-agent.sh <agent>
set -eu
AGENT=${1:?usage: omarchy-default-agent.sh <agent>}
command -v "$AGENT" >/dev/null 2>&1 || { echo "$AGENT is not installed" >&2; exit 1; }
omarchy default agent "$AGENT"
