-- Loaded by nvim-plugins.sh under `nvim --headless`, in one of two modes
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

local function outdated()
  local Config = require("lazy.core.config")
  if not Config.plugins then error("lazy.core.config has no plugins table") end
  local Git = require("lazy.manage.git")
  local Manage = require("lazy.manage")
  Manage.check({ show = false }):wait()

  -- Prefer a human-friendly ref (semver/tag) over a bare sha.
  local function label(gi)
    if not gi then return "?" end
    if gi.version then return tostring(gi.version) end
    if gi.tag then return gi.tag end
    return (gi.commit or "?"):sub(1, 9)
  end

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

local ok, result = pcall(mode == "outdated" and outdated or check)
if ok then
  local body = table.concat(result, "\n")
  if #result > 0 then body = body .. "\n" end
  write_all(body .. OK .. "\n")
else
  write_all(ERR .. " " .. tostring(result) .. "\n")
end
