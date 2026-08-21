# machines

My [loadout](https://github.com/josemiguelo/loadout) config repo: what every
one of my machines should have installed, how to install it, and (in `state/`)
what each machine actually has.

Requires loadout >= 0.2.0 (`min-tool-version` in `manifest.toml`).

## Daily use

```console
$ loadout status              # observe this machine, write state/<name>.json
$ loadout install --dry-run   # what a converge would do
$ loadout install             # install what's missing + run opted-in scripts
$ loadout outdated            # ask dnf/brew/flathub for newer versions of my programs
$ loadout show <name>         # a program as the engine sees it, fully resolved
$ loadout diff                # compare all machines' states
$ loadout sync                # pull --rebase, refresh, commit + push my state
```

## New machine

```console
$ git clone <this repo> ~/.config/machines
$ cp machines/macbook-fedora-kde.toml machines/$(hostname).toml   # then edit:
#   - map every program this machine should have to one of its install keys
#   - opt into the scripts it needs (top-level scripts = [...] list)
$ loadout --repo ~/.config/machines install
$ loadout --repo ~/.config/machines sync
```

