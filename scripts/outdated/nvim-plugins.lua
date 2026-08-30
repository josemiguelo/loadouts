-- Loaded by nvim-plugins.sh under `nvim --headless`. Writes one line per
-- outdated plugin ("<name> <current> <candidate> <n> commit(s)") to
-- $LOADOUT_NVIM_OUT, letting Lazy itself decide what "outdated" means:
-- lazy.manage.check fetches every plugin's remote and its git.log check task
-- sets plugin._.updates only when the resolved target (honouring
-- version/tag/commit/branch/pin) differs from what's on disk. In headless
-- mode Lazy's background checker never starts, so _.updates is nil until this
-- run populates it -- no stale positives.
--
-- Failure protocol: on success we append a lone `__LOADOUT_NVIM_OK__` sentinel
-- line. The shell wrapper treats its ABSENCE (a crash, timeout, or Lua error
-- that leaves the file empty/partial) as a failure and surfaces a loud row,
-- so a broken check can never masquerade as "all up to date". A structured
-- `__LOADOUT_NVIM_ERR__ <reason>` line carries a Lua-level reason when we have
-- one.

local OK = "__LOADOUT_NVIM_OK__"
local ERR = "__LOADOUT_NVIM_ERR__"

local out_path = vim.env.LOADOUT_NVIM_OUT
if not out_path or out_path == "" then
  return
end

local function write_all(body)
  local fd = io.open(out_path, "w")
  if not fd then
    return
  end
  fd:write(body)
  fd:close()
end

local function emit_ok(lines)
  local body = table.concat(lines, "\n")
  if #lines > 0 then
    body = body .. "\n"
  end
  write_all(body .. OK .. "\n")
end

local function emit_err(reason)
  write_all(ERR .. " " .. tostring(reason) .. "\n")
end

local function compute()
  local Config = require("lazy.core.config")
  if not Config.plugins then
    error("lazy.core.config has no plugins table")
  end
  local Git = require("lazy.manage.git")
  local Manage = require("lazy.manage")

  -- Fetch remotes and resolve targets; populates plugin._.updates. Block on it.
  local runner = Manage.check({ show = false })
  runner:wait()

  -- Prefer a human-friendly ref (semver/tag) over a bare sha.
  local function label(gi)
    if not gi then
      return "?"
    end
    if gi.version then
      return tostring(gi.version)
    end
    if gi.tag then
      return gi.tag
    end
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
      lines[#lines + 1] = string.format("%s %s %s%s", name, label(from), label(up.to), note)
    end
  end
  return lines
end

local ok, result = pcall(compute)
if ok then
  emit_ok(result)
else
  emit_err(result)
end
