-- Omarchy's Hyprland defaults alone, without the personal overrides: the
-- first half of ~/.config/hypr/hyprland.lua. Handed to hypr-option.lua as
-- the config, it answers what Omarchy itself binds or sets.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")
require("default.hypr.omarchy")
