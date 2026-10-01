-- Per-app hotkeys, like Raycast's: one key per app, in one of two modes.
--   jump     go to the app: on this workspace first, else the next
--            workspace to the right that has it. Pressed while the app is
--            focused, its next window, workspace by workspace and left to
--            right, wrapping. A key only ever lands on its own app.
--   overlay  the app lives in its own special workspace, shown over the
--            current one and hidden by the same key
-- No window yet: the key launches the app. Jump never moves windows, so
-- layouts stay as they are. Windows on special workspaces (overlays, the
-- scratchpad) are never jumped to. The workspace card that shows after a
-- jump to another workspace is plugin/Toast.qml, an Omarchy shell plugin that
-- follows every workspace change, not only these keys.
--
-- usage, from ~/.config/hypr/bindings.lua:
--   local harpoon = require("hypr.harpoon")
--   harpoon.bind("SUPER + CTRL + ALT + SHIFT + B",
--     { name = "Browser", class = "^brave%-browser$", launch = "omarchy-launch-browser", mode = "jump" })
-- class is a Lua pattern on the window class, or a list of them.

local M = {}

local MODES = { jump = true, overlay = true }

local apps = {}

local function dispatch(dsp)
  hl.dispatch(dsp)
end

local function overlay_name(app)
  return "harpoon-" .. app.name:lower():gsub("[^%w]+", "-")
end

local function ws_name(window)
  return window.workspace and window.workspace.name or ""
end

local function is_special(window)
  return ws_name(window):sub(1, 8) == "special:"
end

-- Most recently focused first; never focused (-1) last.
local function by_recency(a, b)
  local fa, fb = a.focus_history_id, b.focus_history_id
  if fa < 0 then fa = math.huge end
  if fb < 0 then fb = math.huge end
  return fa < fb
end

local function matches(app, class)
  local patterns = type(app.class) == "table" and app.class or { app.class }
  for _, pattern in ipairs(patterns) do
    if (class or ""):match(pattern) then return true end
  end
  return false
end

local function windows_of(app)
  local list = {}
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped ~= false and matches(app, w.class) then
      table.insert(list, w)
    end
  end
  table.sort(list, by_recency)
  return list
end

local function focus(window)
  dispatch(hl.dsp.focus({ window = window }))
end

local function launch(app)
  hl.exec_cmd(app.launch)
end

local function special_visible(name)
  local monitor = hl.get_active_monitor()
  local special = monitor and monitor.active_special_workspace
  return special ~= nil and special.name == "special:" .. name
end

local modes = {}

-- A window's place, for the left-to-right order: its scrolling column (and
-- place in it), else its position on screen.
local function place(window)
  local layout = type(window.layout) == "table" and window.layout or {}
  if type(layout.column) == "table" then
    return layout.column.index, layout.index_in_column or 0
  end
  local at = type(window.at) == "table" and window.at or {}
  return at.x or 0, at.y or 0
end

-- Workspace by workspace in number order, left to right in each.
local function by_place(a, b)
  local wa, wb = a.workspace.id, b.workspace.id
  if wa ~= wb then return wa < wb end
  local xa, ya = place(a)
  local xb, yb = place(b)
  if xa ~= xb then return xa < xb end
  if ya ~= yb then return ya < yb end
  return a.stable_id < b.stable_id
end

-- The first press goes to the app on this workspace (the window last used
-- here), else to the next workspace to the right that has it, wrapping.
-- Pressed on one of the app's windows, the next one in place order,
-- wrapping; never another app.
function modes.jump(app)
  local list = {}
  for _, w in ipairs(windows_of(app)) do
    if not is_special(w) and w.workspace then table.insert(list, w) end
  end
  if #list == 0 then return launch(app) end
  local active = hl.get_active_window()
  local here = hl.get_active_workspace()
  table.sort(list, by_place)
  for i, w in ipairs(list) do
    if active and w.address == active.address then
      return focus(list[i % #list + 1])
    end
  end
  local here_id = here and not here.special and here.id
  if here_id then
    local recent
    for _, w in ipairs(list) do
      if w.workspace.id == here_id and (not recent or by_recency(w, recent)) then recent = w end
    end
    if recent then return focus(recent) end
    for _, w in ipairs(list) do
      if w.workspace.id > here_id then return focus(w) end
    end
  end
  focus(list[1])
end

-- Moves the app's windows into its overlay, so a window opened another way
-- (the launcher, a restart) joins it.
local function adopt(app)
  local name = "special:" .. overlay_name(app)
  for _, w in ipairs(windows_of(app)) do
    if ws_name(w) ~= name then
      dispatch(hl.dsp.window.move({ workspace = name, follow = false, window = w }))
    end
  end
end

function modes.overlay(app)
  local name = overlay_name(app)
  local list = windows_of(app)
  if #list == 0 then
    app.pending = true
    return launch(app)
  end
  if special_visible(name) then
    return dispatch(hl.dsp.workspace.toggle_special(name))
  end
  adopt(app)
  dispatch(hl.dsp.workspace.toggle_special(name))
  focus(windows_of(app)[1])
end

-- An overlay app's new window opens in its overlay when the key launched it.
-- Some apps (Spotify) set their class after opening, so both events count.
local function on_window(window)
  if not window then return end
  for _, app in pairs(apps) do
    if app.mode == "overlay" and app.pending and matches(app, window.class) then
      app.pending = false
      local name = overlay_name(app)
      dispatch(hl.dsp.window.move({ workspace = "special:" .. name, follow = false, window = window }))
      if not special_visible(name) then dispatch(hl.dsp.workspace.toggle_special(name)) end
      focus(window)
      return
    end
  end
end

function M.press(name)
  local app = apps[name]
  if app then modes[app.mode](app) end
end

function M.bind(keys, app)
  assert(MODES[app.mode], "harpoon: unknown mode " .. tostring(app.mode))
  apps[app.name] = app
  hl.bind(keys, function() M.press(app.name) end, { description = app.name .. " (" .. app.mode .. ")" })
end

hl.on("window.open", on_window)
hl.on("window.class", on_window)

return M
