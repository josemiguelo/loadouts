---
name: repo-ecosystem
description: Map of jochoa's interconnected personal-tooling repos (loadout, loadouts, chezmoi dotfiles, loadout.wiki, skills, and a private local-only repo) and the rule for dispatching cross-repo work into the right one via workmux. Use when this session needs to touch any of these repos.
---

# repo-ecosystem

A map of a small set of deeply interconnected personal-tooling repos, and
the rule for where work on them actually belongs.

## The repos

- **`~/Repos/gh/josemiguelo/loadout`** (bare + worktree, `all_worktrees/<branch>`)
  — the `loadout` CLI itself (Kotlin/Native): installs programs and runs
  idempotent setup scripts from a declarative config repo. A new feature
  here often needs two follow-ups elsewhere: a version bump in `loadouts`
  (if it raises `min-tool-version`), and an update to `loadout.wiki`.
- **`~/Repos/gh/josemiguelo/loadout.wiki`** (plain clone, sibling of
  `loadout`, its own separate git repo/remote) — the user-facing wiki.
  Must be re-read and updated whenever a loadout change touches screen
  text, keys, or example output it documents.
- **`~/.config/loadouts`** (plain clone — deliberately NOT bare+worktree:
  it's a tool that continuously applies one canonical state to a shared
  external target, the live machine, which bare+worktree fits poorly) —
  the user's own declarative machine config that `loadout` reads: what's
  installed, what scripts converge, per machine. Some of its maintain
  scripts drive chezmoi (dotfiles) directly. This file lives here because
  it's knowledge about what loadouts itself governs, not a general-purpose
  agent skill.
- **`~/.local/share/chezmoi`** (plain clone — same "continuously applies
  state to `$HOME`" reason as `loadouts`) — the dotfiles source. Partly
  automated by `loadouts`' maintain scripts, partly edited directly.
- **`~/Repos/gh/josemiguelo/skills`** (bare + worktree) — personal agent
  skills meant to be genuinely general-purpose, symlinked individually
  into `~/.claude/skills/<name>` by `loadouts`' `skills-repo` maintain
  script on every machine.
- **A private, local-only repo** also exists on at least one machine,
  outside this general convention (not cloned by any shared script),
  which depends on `loadouts`, chezmoi, and the skills repo.

## The rule

When a task's real home is one of these repos, don't do the work in
whatever scratch/dispatch session you're currently in. Create a workmux
worktree **in that repo** instead, from its own default worktree:

```bash
cd ~/Repos/gh/josemiguelo/<loadout|skills>/all_worktrees/<default-branch>
workmux add <branch-name>
```

(`loadouts` and chezmoi stay plain clones — just edit them directly, no
worktree needed, per the "continuously applies state" exception above.)

If a change has a known follow-up in a related repo (a loadout feature
needing a `loadouts` version bump, or a wiki update), treat that as its
own separate task in that repo — don't try to make one worktree carry
changes meant for two different repos.
