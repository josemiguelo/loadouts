-- Per-app keys on Hyper (SUPER+CTRL+ALT+SHIFT, sent by the keyboard): see
-- ~/.config/hypr/harpoon.lua for the modes
-- (scripts/maintain/omarchy-harpoon.sh rewrites this block).
local harpoon = require("hypr.harpoon")
local hyper = "SUPER + CTRL + ALT + SHIFT + "
harpoon.bind(hyper .. "T", { name = "Terminal", class = "^kitty$", launch = "omarchy-launch-terminal", mode = "jump" })
harpoon.bind(hyper .. "B", { name = "Browser", class = "^brave%-browser$", launch = "omarchy-launch-browser", mode = "jump" })
harpoon.bind(hyper .. "O", { name = "Obsidian", class = "^obsidian$", launch = o.launch("obsidian"), mode = "jump" })
harpoon.bind(hyper .. "M", { name = "Spotify", class = "^[Ss]potify$", launch = "omarchy-launch-spotify", mode = "overlay" })
harpoon.bind(hyper .. "P", { name = "1Password", class = { "^com%.onepassword%.OnePassword$", "^1[Pp]assword$" }, launch = "omarchy-launch-1password", mode = "overlay" })
