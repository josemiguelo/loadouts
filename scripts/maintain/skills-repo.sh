#!/bin/sh
# Keeps ~/Repos/gh/josemiguelo/skills cloned (bare + worktree) and symlinks
# each skill it contains into ~/.claude/skills/<name> -- individually, not
# as one directory-level symlink over ~/.claude/skills itself: tools like
# `workmux setup --skills` write their own regenerable skills directly into
# ~/.claude/skills, and a blanket symlink would redirect that regenerable
# content into this tracked repo.
#
# Modes: `check` / `install` (default).
set -eu

REPO_URL="git@github.com:josemiguelo/skills.git"
REPO="$HOME/Repos/gh/josemiguelo/skills"
SKILLS_DIR="$HOME/.claude/skills"

# clone_repo: bare clone + initial worktree, matching gclone --bare's own
# logic (repos.plugin.zsh) for the interactive path. `git clone --bare`
# leaves remote.origin.fetch unconfigured, unlike a plain clone -- without
# setting it explicitly, a later `git fetch` would silently fetch nothing.
clone_repo() {
  git clone --quiet --bare -- "$REPO_URL" "$REPO"
  git -C "$REPO" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git -C "$REPO" fetch --quiet --prune origin || true

  default_branch=$(git -C "$REPO" symbolic-ref --quiet --short HEAD)
  if [ -z "$default_branch" ]; then
    echo "skills-repo: couldn't determine the default branch" >&2
    return 1
  fi

  worktree="$REPO/all_worktrees/$default_branch"
  git -C "$REPO" worktree add --quiet "$worktree" "$default_branch"
  git -C "$worktree" branch --quiet --set-upstream-to="origin/$default_branch" "$default_branch" || true
}

# The one worktree this repo has (its default branch's checkout).
worktree_path() {
  git -C "$REPO" worktree list --porcelain 2>/dev/null |
    awk '/^worktree /{p=$2} /^branch /{print p; exit}'
}

# Every top-level skill directory the worktree currently has.
skill_names() {
  wt=$(worktree_path)
  [ -n "$wt" ] && [ -d "$wt" ] || return 0
  find "$wt" -mindepth 1 -maxdepth 1 -type d ! -name '.git' -exec basename {} \;
}

check_all() {
  [ -d "$REPO" ] || return 1
  wt=$(worktree_path)
  [ -n "$wt" ] || return 1

  names=$(skill_names)
  [ -z "$names" ] && return 0
  while IFS= read -r name; do
    link="$SKILLS_DIR/$name"
    [ -L "$link" ] || return 1
    [ "$(readlink "$link")" = "$wt/$name" ] || return 1
  done <<EOF
$names
EOF
}

install_all() {
  if [ ! -d "$REPO" ]; then
    echo "skills-repo: cloning $REPO_URL"
    clone_repo
  fi

  wt=$(worktree_path)
  if [ -z "$wt" ]; then
    echo "skills-repo: $REPO has no worktree -- clone it manually first" >&2
    return 1
  fi

  mkdir -p "$SKILLS_DIR"
  names=$(skill_names)
  [ -z "$names" ] && return 0
  while IFS= read -r name; do
    link="$SKILLS_DIR/$name"
    target="$wt/$name"
    if [ -L "$link" ]; then
      [ "$(readlink "$link")" = "$target" ] || { rm "$link"; ln -s "$target" "$link"; echo "skills-repo: relinked $name"; }
    elif [ -e "$link" ]; then
      echo "skills-repo: $link exists and isn't a symlink; leaving it" >&2
    else
      ln -s "$target" "$link"
      echo "skills-repo: linked $name"
    fi
  done <<EOF
$names
EOF
}

case "${1:-install}" in
check) check_all ;;
install) install_all ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
