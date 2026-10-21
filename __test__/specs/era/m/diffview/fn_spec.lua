require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Fn = require("era.m.diffview.fn")
local Session = require("era.m.diffview.session")

t:test("open_file_history opens the log of the file's path relative to the workspace", function()
  local log_opts = nil ---@type { layout: integer|nil, path: string|nil }|nil
  local relative_args = nil ---@type { from: string, to: string }|nil
  t:patch_table(dot.path, "workspace", function()
    return [[C:\repo]]
  end)
  t:patch_table(stl.os.path, "relative", function(from, to)
    relative_args = { from = from, to = to }
    return "lua/era/m/im/wsl.lua"
  end)
  t:patch_table(Session, "open_log", function(opts)
    log_opts = opts
  end)
  local filepath = [[C:\repo\lua\era\m\im\wsl.lua]]

  Fn.open_file_history({ filepath = filepath, layout = 3 })

  t.assert_same({ from = [[C:\repo]], to = filepath }, relative_args, "relative path")
  t.assert_same({ layout = 3, path = "lua/era/m/im/wsl.lua" }, log_opts, "Git path filter")
end)

t:test("entry points dispatch to the current tab's session and do nothing without one", function()
  local current = nil ---@type table|nil
  t:patch_table(Session, "current", function()
    return current
  end)
  local calls = {} ---@type string[]
  local session = {}
  for _, name in ipairs({ "close", "refresh", "reveal", "toggle_commits", "toggle_files" }) do
    session[name] = function(self)
      t.assert_true(self == session, name .. " receives its session")
      calls[#calls + 1] = name
    end
  end
  session.navigate_window = function(_, direction)
    calls[#calls + 1] = "navigate_" .. direction
    return direction == "h"
  end

  Fn.close()
  Fn.refresh()
  Fn.reveal()
  Fn.toggle_commits()
  Fn.toggle_files()
  t.assert_false(Fn.navigate_window("h"), "no session leaves navigation native")
  t.assert_eq(0, #calls, "no session")

  current = session
  Fn.close()
  Fn.refresh()
  Fn.reveal()
  Fn.toggle_commits()
  Fn.toggle_files()
  t.assert_true(Fn.navigate_window("h"), "handled navigation")
  t.assert_false(Fn.navigate_window("l"), "native navigation")
  t.assert_eq(
    "close,refresh,reveal,toggle_commits,toggle_files,navigate_h,navigate_l",
    table.concat(calls, ","),
    "dispatch"
  )
end)

t:run()
