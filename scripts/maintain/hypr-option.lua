-- The value a Hyprland option gets from the user's Lua config, without a
-- running Hyprland: runs ~/.config/hypr/hyprland.lua (Omarchy's defaults,
-- then the personal overrides, in Hyprland's own load order) with a
-- stand-in `hl` whose config() merges every call the way Hyprland applies
-- them — later calls win, key by key — and whose bind()/unbind() keep the
-- key bindings the way Hyprland does: a bind adds to the key (two binds on
-- one key both fire), an unbind clears it. Every other hl.* / o.* use is a
-- no-op. Hyprland embeds Lua 5.5 and depends on the `lua` package, so plain
-- `lua` runs the same language.
--
-- usage: lua hypr-option.lua <option.path> [config]
--   prints the value (true, 0.4, "us", …) or nil when nothing sets it;
--        lua hypr-option.lua "bind:SUPER + SHIFT + E" [config]
--   prints the command each bind on that key runs, one per line (a
--   dispatcher that isn't a command prints as <dispatcher>), or nil;
--   exits 2 when the config itself fails to load.
-- Limits: this RUNS the config (Omarchy's does read-only probes at load:
-- `find`, command-exists checks), and anything the stand-in returns is a
-- placeholder — a setting under `if hl.<query>() then` sees a fake answer.

local path, config = arg[1], arg[2] or (os.getenv("HOME") .. "/.config/hypr/hyprland.lua")
if not path then
  io.stderr:write("usage: lua hypr-option.lua <option.path> [config]\n")
  os.exit(2)
end

local merged = {}

local function merge(into, from)
  for k, v in pairs(from) do
    if type(v) == "table" then
      if type(into[k]) ~= "table" then into[k] = {} end
      merge(into[k], v)
    else
      into[k] = v
    end
  end
end

-- Absorbs anything: indexing, calls, concatenation, comparison, arithmetic.
local sink
local absorb = {
  __index = function() return sink end,
  __newindex = function() end,
  __call = function() return sink end,
  __concat = function() return "" end,
  __tostring = function() return "" end,
  __len = function() return 0 end,
  __eq = function() return false end,
  __lt = function() return false end,
  __le = function() return false end,
  __unm = function() return 0 end,
  __add = function() return 0 end,
  __sub = function() return 0 end,
  __mul = function() return 0 end,
  __div = function() return 0 end,
}
sink = setmetatable({}, absorb)

-- "SUPER + SHIFT + E" and "super+shift+e" are the same key.
local function key_of(keys)
  return tostring(keys):upper():gsub("%s+", "")
end

local binds = {}

hl = setmetatable({
  config = function(t)
    if type(t) == "table" then merge(merged, t) end
  end,
  bind = function(keys, dispatcher)
    local key = key_of(keys)
    local exec = type(dispatcher) == "table" and rawget(dispatcher, "exec") or "<dispatcher>"
    binds[key] = binds[key] or {}
    table.insert(binds[key], exec)
  end,
  unbind = function(keys)
    binds[key_of(keys)] = nil
  end,
  -- o.bind turns a command into hl.dsp.exec_cmd(command): keep the command.
  dsp = setmetatable({
    exec_cmd = function(command) return { exec = command } end,
  }, { __index = function() return sink end }),
}, { __index = function() return sink end })

local ok, err = pcall(dofile, config)
if not ok then
  -- A missing module appends Lua's whole search path: keep the first line,
  -- and the second when the first only introduces it ("…from file 'x':").
  local first, second = tostring(err):match("([^\n]*)\n?%s*([^\n]*)")
  local why = first:sub(-1) == ":" and first .. " " .. second or first
  io.stderr:write("hypr-option: " .. config .. " failed to load: " .. why .. "\n")
  os.exit(2)
end

if path:sub(1, 5) == "bind:" then
  local list = binds[key_of(path:sub(6))]
  print(list and table.concat(list, "\n") or "nil")
  os.exit(0)
end

local value = merged
for part in path:gmatch("[^.]+") do
  -- Not `and value[part] or nil`: that turns a set `false` into nil.
  if type(value) == "table" then value = value[part] else value = nil end
end
print(tostring(value))
