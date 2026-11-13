local t = require("__test__.support.harness").new()
local root = assert(vim.uv.cwd()) ---@type string

---Runs `init-update.lua` in a child whose plugin installer is a double that ends with `failed` failed plugins. The
---child starts outside any repository, with its state, data and cache in a temporary directory.
---@param failed                        integer
---@return vim.SystemCompleted
local function update(failed)
  local home = t:tempdir()
  local preload = string.format(
    'package.preload["era.m.plugin.action"] = function() return { install = function() return stl.c.Future.resolve(nil)'
      .. " end, get_progress = function() return { error = %d } end } end",
    failed
  )
  return vim
    .system({
      vim.v.progpath,
      "--headless",
      "-u",
      "NONE",
      "-i",
      "NONE",
      "-n",
      "--cmd",
      "set runtimepath^=" .. root,
      "--cmd",
      "lua " .. preload,
      "-c",
      "luafile " .. root .. "/init-update.lua",
    }, {
      cwd = home,
      env = { XDG_STATE_HOME = home .. "/state", XDG_DATA_HOME = home .. "/data", XDG_CACHE_HOME = home .. "/cache" },
      text = true,
      timeout = 20000,
    })
    :wait()
end

t:test("a plugin update exits non-zero when a plugin failed to install", function()
  local installed, failed = update(0), update(1)
  t.assert_eq(0, installed.code, installed.stderr)
  t.assert_eq(1, failed.code, failed.stderr)
end)

t:run()
