---@diagnostic disable: undefined-global
--- Test for era.m.diffview.fn module
--- Run with: nvim -l lua/__test__/era/m/diffview/fn.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.fn")
local enums = require("stl.e")

local relative_args = nil ---@type { from: string, to: string }|nil
local log_opts = nil ---@type { layout: integer|nil, path: string|nil }|nil

bootstrap.with_runtime(t, {
  dot = {
    path = {
      workspace = function()
        return [[C:\repo]]
      end,
    },
  },
  era = {
    m = {
      diffview = {
        cmd = {
          log = function(opts)
            log_opts = opts
          end,
        },
      },
    },
  },
  stl = {
    e = enums,
    os = {
      path = {
        relative = function(from, to)
          relative_args = { from = from, to = to }
          return "lua/era/m/im/wsl.lua"
        end,
      },
    },
    reporter = { warn = function() end },
  },
})

local Fn = require("era.m.diffview.fn")

t:test("open_file_history uses Git separators for Windows paths", function()
  local filepath = [[C:\repo\lua\era\m\im\wsl.lua]]

  Fn.open_file_history({ filepath = filepath, layout = 3 })

  t.assert_eq([[C:\repo]], relative_args.from, "relative path root")
  t.assert_eq(filepath, relative_args.to, "relative path target")
  t.assert_eq("lua/era/m/im/wsl.lua", log_opts.path, "Git path filter")
  t.assert_eq(3, log_opts.layout, "layout")
end)

t:test("reveal dispatches to the active Diffview action", function()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local calls = {} ---@type string[]

  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", {
    reveal = function()
      calls[#calls + 1] = "workspace"
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {
    get = function()
      return {}
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    get_layout = function()
      return {}
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.action", {
    reveal = function()
      calls[#calls + 1] = "commits"
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {
    get = function()
      return {}
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.view", {
    get_layout = function()
      return {}
    end,
  })

  vim.t[tabnr].tabtype = enums.TabTypeEnum.DIFFVIEW_WORKSPACE
  Fn.reveal()
  vim.t[tabnr].tabtype = enums.TabTypeEnum.DIFFVIEW_COMMITS
  Fn.reveal()
  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL

  t.assert_eq("workspace,commits", table.concat(calls, ","), "action dispatch")
end)

t:test("left navigation from Workspace SBS restores the remembered Changes pane", function()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  local calls = 0
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    focus_changes = function()
      calls = calls + 1
      return true
    end,
    get_layout = function()
      return { sbs_left_winnr = left_winnr }
    end,
  })

  vim.t[tabnr].tabtype = enums.TabTypeEnum.DIFFVIEW_WORKSPACE
  t.assert_true(Fn.navigate_window("h"), "workspace left handled")
  t.assert_eq(1, calls, "Changes focus")
  t.assert_false(Fn.navigate_window("l"), "workspace right native")

  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL
  t.assert_false(Fn.navigate_window("h"), "normal tab native")
end)

t:run()
