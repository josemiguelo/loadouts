#!/bin/sh
# Global git identity (only when unset) + delta/merge config.
set -eu

DESIRED_EMAIL="josemiguelo.ochoa@gmail.com"
DESIRED_NAME="Jose Miguel Ochoa"

if [ -z "$(git config --global user.email 2>/dev/null || true)" ]; then
  git config --global user.email "$DESIRED_EMAIL"
fi
if [ -z "$(git config --global user.name 2>/dev/null || true)" ]; then
  git config --global user.name "$DESIRED_NAME"
fi

git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global merge.conflictStyle zdiff3
