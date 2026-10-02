# Sourced, not run. The shared bar-icon files every icon-drawing bar widget
# carries at its root: omarchy-bar-icons/BarSvgIcon.qml and the SVGs in
# omarchy-bar-icons/icons/ (Material Design Icons, Apache-2.0, plus the
# Omarchy logo), white-filled for BarSvgIcon to tint.
# Callers set HERE to the scripts/maintain directory.

BAR_ICONS=$HERE/omarchy-bar-icons

# The shared files, relative to omarchy-bar-icons/, one per line.
bar_icons_files() {
  echo BarSvgIcon.qml
  for f in "$BAR_ICONS"/icons/*.svg; do echo "icons/${f##*/}"; done
}

# bar_icons_copy <plugin-dir>: put the shared files into a plugin folder.
bar_icons_copy() {
  mkdir -p "$1/icons"
  for f in $(bar_icons_files); do cp "$BAR_ICONS/$f" "$1/$f"; done
}

# bar_icons_same <plugin-dir>: the plugin folder has the current shared files.
bar_icons_same() {
  for f in $(bar_icons_files); do
    [ -f "$1/$f" ] && cmp -s "$BAR_ICONS/$f" "$1/$f" || return 1
  done
}
