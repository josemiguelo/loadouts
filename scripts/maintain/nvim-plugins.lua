-- Loaded by nvim-plugins.sh under `nvim --headless`, in one of three modes
-- ($LOADOUT_NVIM_MODE), writing to $LOADOUT_NVIM_OUT and ending with a lone
-- `__LOADOUT_NVIM_OK__` sentinel — the shell treats its ABSENCE (crash,
-- timeout, Lua error) as a failure, so a broken run can never read as
-- "all good". A `__LOADOUT_NVIM_ERR__ <reason>` line carries a Lua-level
-- reason when there is one.
--
--   check     does the DISK match the lock? No fetch. One line per plugin
--             whose clone is not what lazy-lock.json locks:
--               missing <name>                       enabled, not cloned
--               off-lock <name> <installed> <locked>
--             Lazy decides membership: a `cond = false` / `enabled = false`
--             plugin stays in the lockfile but is never cloned, so the
--             lockfile alone is not the config — the spec is.
--
--   outdated  is a newer commit AVAILABLE upstream? Fetches every remote
--             (lazy.manage.check) and lets Lazy resolve each plugin's target
--             (version/tag/commit/branch/pin); one
--             "<name> <current> <candidate> <n> commit(s)" line per plugin
--             Lazy would move. In headless mode Lazy's background checker
--             never starts, so _.updates is nil until this run fills it —
--             no stale positives.
--
--   update    move ONE plugin ($LOADOUT_NVIM_ITEM) to its target, Lazy's own
--             update, which rewrites lazy-lock.json. Prints
--             "<name> <from> -> <to>". Errors unless the clone actually
--             moved: an unknown name, a plugin that is only in the lockfile,
--             a failed fetch and a pin that holds all leave the commit where
--             it was, and Lazy reports none of them as a Lua error.
local OK = "__LOADOUT_NVIM_OK__"
local ERR = "__LOADOUT_NVIM_ERR__"
local out_path = vim.env.LOADOUT_NVIM_OUT
if not out_path or out_path == "" then return end
local mode = vim.env.LOADOUT_NVIM_MODE or "check"

local function write_all(body)
  local fd = io.open(out_path, "w")
  if fd then fd:write(body) fd:close() end
end

local function check()
  local Config = require("lazy.core.config")
  local Lock = require("lazy.manage.lock")
  local Git = require("lazy.manage.git")
  local names = vim.tbl_keys(Config.plugins)
  table.sort(names)
  local lines = {}
  for _, name in ipairs(names) do
    local p = Config.plugins[name]
    -- Same rule Lazy's own install/restore applies.
    if p._.cond ~= false and p.enabled ~= false then
      local locked = Lock.get(p)
      if not p._.installed then
        lines[#lines + 1] = "missing " .. name
      elseif locked and locked.commit then
        local info = Git.info(p.dir)
        local head = info and info.commit or "?"
        if head ~= locked.commit then
          lines[#lines + 1] = string.format("off-lock %s %s %s", name, head:sub(1, 9), locked.commit:sub(1, 9))
        end
      end
    end
  end
  return lines
end

-- Prefer a human-friendly ref (semver/tag) over a bare sha.
local function label(gi)
  if not gi then return "?" end
  if gi.version then return tostring(gi.version) end
  if gi.tag then return gi.tag end
  return (gi.commit or "?"):sub(1, 9)
end

local function outdated()
  local Config = require("lazy.core.config")
  if not Config.plugins then error("lazy.core.config has no plugins table") end
  local Git = require("lazy.manage.git")
  local Manage = require("lazy.manage")
  Manage.check({ show = false }):wait()

  local names = vim.tbl_keys(Config.plugins)
  table.sort(names)
  local lines = {}
  for _, name in ipairs(names) do
    local plugin = Config.plugins[name]
    local up = plugin._ and plugin._.updates
    if up and up.to then
      -- `up.from` lacks tag/version details; re-read with details for the label.
      local from = Git.info(plugin.dir, true) or up.from
      local note = ""
      local ok_count, n = pcall(Git.count, plugin.dir, up.from.commit, up.to.commit)
      if ok_count and type(n) == "number" and n > 0 then
        note = string.format(" %d commit(s)", n)
      end
      -- The compare page for the two commits, like Lazy's own K.
      local link = ""
      local url = plugin.url or ""
      local gh = url:match("^https://github%.com/([^/]+/[^/]+)$") or url:match("^git@github%.com:([^/]+/[^/]+)$")
      if gh and up.from.commit and up.to.commit then
        link = string.format(" https://github.com/%s/compare/%s...%s", gh:gsub("%.git$", ""), up.from.commit:sub(1, 9), up.to.commit:sub(1, 9))
      end
      lines[#lines + 1] = string.format("%s %s %s%s%s", name, label(from), label(up.to), note, link)
    end
  end
  return lines
end

-- Reasons a user reads in loadout's pane: no Lua file and line in front.
local function refuse(msg)
  error(msg, 0)
end

local function update()
  local name = vim.env.LOADOUT_NVIM_ITEM
  if not name or name == "" then refuse("no plugin name given") end
  local Config = require("lazy.core.config")
  if not Config.plugins then refuse("lazy.core.config has no plugins table") end
  -- Lazy resolves a name it doesn't know to nil and then updates nothing, so
  -- ask the spec ourselves. The lockfile is not the spec: a plugin that is
  -- only locked has nothing to move.
  local plugin = Config.plugins[name]
  if not plugin then refuse("no plugin named '" .. name .. "' in the lazy spec") end
  if not plugin.url then refuse(name .. " is a local plugin; nothing to fetch") end
  if not plugin._.installed then refuse(name .. " is not cloned; run the nvim-plugins script first") end

  local Git = require("lazy.manage.git")
  local before = Git.info(plugin.dir, true)
  require("lazy.manage").update({ plugins = { name }, show = false, wait = true })

  -- Lazy logs a failed fetch or checkout on the plugin's tasks; only a Lua
  -- error reaches the pcall below.
  local errors = {}
  for _, task in ipairs(plugin._.tasks or {}) do
    if task:has_errors() then
      local out = vim.trim(task:output(vim.log.levels.ERROR))
      errors[#errors + 1] = out ~= "" and out or (task.name .. " failed")
    end
  end
  if #errors > 0 then refuse(table.concat(errors, "; ")) end

  local after = Git.info(plugin.dir, true)
  if not after then refuse("no git clone at " .. plugin.dir .. " after updating") end
  if before and before.commit == after.commit then
    refuse(string.format("%s did not move (still %s)", name, label(before)))
  end
  return { string.format("%s %s -> %s", name, label(before), label(after)) }
end

local modes = { check = check, outdated = outdated, update = update }
local ok, result = pcall(modes[mode] or check)
if ok then
  local body = table.concat(result, "\n")
  if #result > 0 then body = body .. "\n" end
  write_all(body .. OK .. "\n")
else
  write_all(ERR .. " " .. tostring(result) .. "\n")
end
