#!/bin/sh
# Bar widgets drawing SVG icons instead of Nerd Font glyphs, from the
# machine's opt-in, one built-in widget id per word ("omarchy.monitor").
# Each is rebuilt from Omarchy's current copy, the way `omarchy plugin clone`
# copies it, as josemiguelo.<name> with clonedFrom set (so its IPC routes stay
# the built-in's), then omarchy-bar-icons/patches/<id>.patch is applied and
# the shared bar-icon files are added (omarchy-bar-icons-lib.sh). Enabling the
# clone puts it in the built-in's place on the bar, settings included.
# The check rebuilds every clone in a temporary folder and compares it with the
# installed one, so an Omarchy update that changes a widget's source shows up
# as not done; install then rebuilds it from the new source. When a patch no
# longer applies, install fails and disables that clone, which puts the
# built-in back on the bar.
# usage: omarchy-bar-icons.sh [check] <widget-id>...
#        omarchy-bar-icons.sh pristine <widget-id> <dir>  (the unpatched clone,
#        to write a patch against)
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/omarchy-bar-icons-lib.sh"
PATCHES=$BAR_ICONS/patches
PLUGINS=$HOME/.config/omarchy/plugins
TMP=${TMPDIR:-/tmp}

clone_id() {
  echo "josemiguelo.${1#omarchy.}"
}

enabled() {
  omarchy plugin list --json 2>/dev/null | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null
}

# copy_source <widget-id> <dir>: the built-in's files and manifest into <dir>,
# as omarchy-plugin-clone copies them: the whole folder for a plugin with its
# own manifest.json, else the manifest, its entry points and clonePaths.
copy_source() {
  info=$(omarchy-plugin-catalog | jq -r --arg id "$1" \
    '.[] | select(.firstParty and .id == $id) | [.sourceDir, .manifestPath, (.name // .id)] | @tsv')
  [ -n "$info" ] || { echo "$1: no built-in Omarchy plugin by that id" >&2; return 1; }
  src=$(printf '%s\n' "$info" | cut -f1)
  manifest=$(printf '%s\n' "$info" | cut -f2)
  name=$(printf '%s\n' "$info" | cut -f3)
  if [ "${manifest##*/}" = manifest.json ]; then
    cp -RL "$src/." "$2/"
  else
    cp -L "$manifest" "$2/manifest.json"
    jq -r '[(.entryPoints[] | {source: ., target: .}), (.omarchy.clonePaths[]? | {source, target})]
      | unique_by(.target)[] | [.source, .target] | @tsv' "$manifest" |
      while IFS="$(printf '\t')" read -r from to; do
        mkdir -p "$(dirname "$2/$to")"
        if [ -d "$src/$from" ]; then
          mkdir -p "$2/$to"
          cp -RL "$src/$from/." "$2/$to/"
        else
          cp -L "$src/$from" "$2/$to"
        fi
        if [ "$from" != "$to" ]; then
          grep -rlF "$from" "$2" | while read -r file; do
            sed "s|$(printf '%s' "$from" | sed 's/\./\\./g')|$to|g" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
          done
        fi
      done
  fi
  jq --arg id "$(clone_id "$1")" --arg name "My $name" --arg from "$1" '
    .id = $id | .name = $name
    | if (.barWidget | type) == "object" then .barWidget.displayName = $name else . end
    | .omarchy = ((if (.omarchy | type) == "object" then .omarchy else {} end) + { clonedFrom: $from })
    | del(.omarchy.clonePaths)' "$2/manifest.json" > "$2/manifest.json.tmp"
  mv "$2/manifest.json.tmp" "$2/manifest.json"
}

# build <widget-id> <dir>: the patched clone, with the shared icon files.
build() {
  patch_file=$PATCHES/$1.patch
  [ -f "$patch_file" ] || { echo "$1: no patch at $patch_file" >&2; return 1; }
  copy_source "$1" "$2" || return 1
  patch -s -p1 -F 0 -d "$2" < "$patch_file" >/dev/null ||
    { echo "$1: $patch_file no longer applies to Omarchy's current source" >&2; return 1; }
  bar_icons_copy "$2"
}

WORK=$(mktemp -d "$TMP/omarchy-bar-icons.XXXXXX")
cleanup() {
  case "$WORK" in "$TMP"/omarchy-bar-icons.?*) rm -rf -- "$WORK" ;; esac
}
trap cleanup EXIT

MODE=install
case "${1:-}" in
check) MODE=check; shift ;;
pristine)
  [ $# -eq 3 ] || { echo "usage: $0 pristine <widget-id> <dir>" >&2; exit 2; }
  mkdir -p "$3"
  copy_source "$2" "$3"
  exit 0
  ;;
esac
[ $# -gt 0 ] || { echo "usage: $0 [check] <widget-id>..." >&2; exit 2; }

# in_place <widget-id>: the installed clone is today's build and on the bar.
in_place() {
  id=$(clone_id "$1")
  [ -d "$WORK/$id" ] && [ -d "$PLUGINS/$id" ] && diff -r "$WORK/$id" "$PLUGINS/$id" >/dev/null &&
    enabled "$id" && ! enabled "$1"
}

failed=0
changed=no
for widget in "$@"; do
  id=$(clone_id "$widget")
  mkdir -p "$WORK/$id"
  if ! build "$widget" "$WORK/$id"; then
    failed=1
    if [ "$MODE" = install ] && enabled "$id"; then
      omarchy plugin disable "$id" >/dev/null && echo "$widget: $id disabled, the built-in is back on the bar" >&2
    fi
    rm -rf -- "${WORK:?}/${id:?}"
    continue
  fi
  [ "$MODE" = install ] || continue
  if [ ! -d "$PLUGINS/$id" ] || ! diff -r "$WORK/$id" "$PLUGINS/$id" >/dev/null; then
    # Swap the folder in whole; the old one goes once the new one is there.
    stage=$(mktemp -d "$PLUGINS/.josemiguelo-build.XXXXXX")
    cp -R "$WORK/$id/." "$stage/"
    old=""
    if [ -d "$PLUGINS/$id" ]; then
      old=$(mktemp -d "$PLUGINS/.josemiguelo-old.XXXXXX")
      mv "$PLUGINS/$id" "$old/"
    fi
    mv "$stage" "$PLUGINS/$id"
    case "$old" in "$PLUGINS"/.josemiguelo-old.?*) rm -rf -- "$old" ;; esac
    changed=yes
  fi
  omarchy-shell shell rescanPlugins >/dev/null
  tries=0
  until enabled "$id" || omarchy plugin enable "$id" >/dev/null 2>&1; do
    tries=$((tries + 1))
    [ "$tries" -lt 20 ] || { echo "couldn't enable $id (is omarchy-shell running?)" >&2; failed=1; break; }
    sleep 0.5
  done
done

if [ "$MODE" = install ] && [ "$changed" = yes ]; then
  # A loaded plugin keeps its old QML until the shell restarts.
  restart_shell_settled "bar icons"
fi

for widget in "$@"; do
  [ -d "$WORK/$(clone_id "$widget")" ] || continue
  tries=0
  until in_place "$widget"; do
    tries=$((tries + 1))
    if [ "$MODE" = check ] || [ "$tries" -ge 20 ]; then
      [ "$MODE" = check ] || echo "$widget: $(clone_id "$widget") isn't in place after install" >&2
      failed=1
      break
    fi
    sleep 0.5
  done
done
exit "$failed"
