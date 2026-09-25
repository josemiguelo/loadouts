#!/bin/sh
# macOS: every JDK the mise config pins, registered with macOS in
# /Library/Java/JavaVirtualMachines — what asdf-java's
# java_macos_integration_enable did. That directory is where
# /usr/libexec/java_home, the /usr/bin/java stub, GUI apps and Gradle's
# toolchain detection look; mise alone only reaches the shell's PATH.
#
# Each JDK gets `mise-<version>.jdk/Contents` linked to its mise install. The
# script only ever touches entries whose link points into mise's or asdf's
# installs — never a JDK some vendor installer put there — and removes those
# that no longer match the config (asdf's, once ~/.asdf is gone, point at
# nothing).
# Modes: `check` / `install` (default).
set -eu

JVM="${JVM_DIR:-/Library/Java/JavaVirtualMachines}"
MISE_JAVA="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/installs/java"
command -v mise >/dev/null 2>&1 || { echo "mise not found" >&2; exit 1; }
cd "$HOME"

# "<entry> <Contents target>" for every JDK the config pins that mise has
# installed. A build without Contents/ (not a macOS bundle) can't register.
# If mise can't answer, stop: an empty answer would make every registration
# look stale, and install would remove them all.
LISTED=$(mise ls --global java 2>&1) || {
  echo "mise couldn't list the configured java versions:" >&2
  printf '%s\n' "$LISTED" >&2
  exit 1
}
wanted() {
  printf '%s\n' "$LISTED" | awk '$1 == "java" && $3 != "(missing)" { print $2 }' | while read -r v; do
    dir=$(mise where "java@$v" 2>/dev/null) || continue
    if [ -d "$dir/Contents" ]; then
      printf '%s %s\n' "$JVM/mise-$v.jdk" "$dir/Contents"
    else
      echo "java $v has no Contents/ to register ($dir)" >&2
    fi
  done
}

# Entries in $JVM that are ours: the entry itself, its Contents, or its
# Contents/Home links into mise's or asdf's installs. Every entry, not only
# *.jdk: asdf-java's are stubs named without the suffix
# (adoptopenjdk-21.0.6+7.0.LTS/Contents/{Info.plist,MacOS,Home ->
# ~/.asdf/installs/java/…}), which break once ~/.asdf is gone.
ours() {
  for e in "$JVM"/*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    t=$(readlink "$e" 2>/dev/null || readlink "$e/Contents" 2>/dev/null ||
      readlink "$e/Contents/Home" 2>/dev/null || true)
    case "$t" in "$MISE_JAVA"/* | "$HOME/.asdf/"*) echo "$e" ;; esac
  done
}

WANTED=$(wanted)
stale() {
  ours | while read -r e; do
    printf '%s\n' "$WANTED" | grep -q "^$e " || echo "$e"
  done
}
wrong() {
  printf '%s\n' "$WANTED" | while read -r e target; do
    [ -n "$e" ] || continue
    [ "$(readlink "$e/Contents" 2>/dev/null)" = "$target" ] || echo "$e"
  done
}

case "${1:-install}" in
check)
  s=$(stale); w=$(wrong)
  [ -z "$s" ] && [ -z "$w" ] && exit 0
  for e in $s; do echo "stale: $e"; done
  for e in $w; do echo "missing: $e"; done
  exit 1
  ;;
install)
  for e in $(stale); do
    echo "removing $e"
    sudo rm -rf "$e"
  done
  printf '%s\n' "$WANTED" | while read -r e target; do
    [ -n "$e" ] || continue
    [ "$(readlink "$e/Contents" 2>/dev/null)" = "$target" ] && continue
    echo "registering $e"
    sudo mkdir -p "$e"
    sudo ln -sfn "$target" "$e/Contents"
  done
  /usr/libexec/java_home -V 2>&1 || true
  ;;
*) echo "usage: $0 [check|install]" >&2; exit 2 ;;
esac
