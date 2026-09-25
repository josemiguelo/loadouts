# loadouts

My [loadout](https://github.com/josemiguelo/loadout) config repo: each
machine's loadout — what it should have installed, how to install it, and
(in `state/`) what it actually has.

Requires loadout >= 0.12.0 (`min-tool-version` in `manifest.toml`).

## Daily use

```console
$ loadout status              # observe programs + script drift (with detail), write state
$ loadout setup-new-machine --dry-run     # what a converge would do
$ loadout setup-new-machine               # install what's missing + run opted-in scripts
$ loadout install <names>     # just those programs (+ their deps)
$ loadout outdated            # ask dnf/brew/flathub for newer versions of my programs
$ loadout maintain            # pick scripts and run them, watching output live
$ loadout explain <name>         # a program as the engine sees it, fully resolved
$ loadout diff                # compare all machines' states
$ loadout sync                # pull --rebase, refresh, commit + push my state
```

Both `manifest.d/` and `scripts/` are split by responsibility:

- `manifest.d/install/` — `[programs.*]` fragments (by category); `install/00_setup-dnf.toml`
  sorts first so dnf is configured before anything installs. `manifest.d/maintain/` —
  `[scripts.*]` fragments, one per maintenance concern. `manifest.d/oracles/` —
  `[outdated.*]` custom oracles, one per concern: repo-global questions about the
  outside world, not part of any machine's loadout. Install *mechanics* (dnf,
  brew, brew-cask, flatpak) are not here at all: they ship with loadout — see
  `loadout installers`, and `loadout installers --eject` to take them over.
- `scripts/install/` — files run by program install variants (their check is the pm
  database or a version command); `scripts/install/repos/` holds vendor `.repo`
  files, data rather than code, fed to loadout's `dnf-repo` installer via
  `with.repofile`. `scripts/maintain/` — the opt-in `[scripts.*]` files
  (each has its own check, inline or two-mode). `scripts/outdated/` — oracle
  implementations.

## New machine

This repo declares `min-tool-version = "0.12.0"` (it leans on loadout's
built-in installers and the home screen's pane), so the binary comes first —
an older one refuses the whole repo with `run: loadout self-upgrade`.

```console
$ curl -fsSL https://raw.githubusercontent.com/josemiguelo/loadout/master/install.sh | sh
$ loadout upgrade                       # if loadout is already installed
$ git clone <this repo> ~/.config/loadouts
$ cp machines/linux/t2-macbook-omarchy.toml machines/linux/$(hostname).toml   # then edit:
#   - map every program this machine should have to one of its install keys
#   - opt into the scripts it needs (top-level scripts = [...] list)
$ loadout --repo ~/.config/loadouts setup-new-machine
$ loadout --repo ~/.config/loadouts sync
```

