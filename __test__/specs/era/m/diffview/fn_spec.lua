--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/diffview/fn_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.diffview.fn module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

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

local Fn = assert(loadfile("lua/era/m/diffview/fn.lua"))()

t:test("open_file_history uses Git separators for Windows paths", function()
  local filepath = [[C:\repo\lua\era\m\im\wsl.lua]]

  ---@diagnostic disable-next-line: assign-type-mismatch
  Fn.open_file_history({ filepath = filepath, layout = 3 })

  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq([[C:\repo]], relative_args.from, "relative path root")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(filepath, relative_args.to, "relative path target")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("lua/era/m/im/wsl.lua", log_opts.path, "Git path filter")
  ---@diagnostic disable-next-line: need-check-nil
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
    history_context = function()
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

t:test("workspace toggle_files restores the complete sidebar", function()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local calls = {} ---@type string[]
  local layout = { history = {} }
  local history = {}
  local state = {
    get_current_entry = function()
      return { stage_type = "unstaged" }
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {
    get = function()
      return state
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    get_layout = function()
      return layout
    end,
    history_context = function()
      return history
    end,
    toggle_sidebar = function()
      calls[#calls + 1] = "toggle"
      return layout, true
    end,
    render_changes = function()
      calls[#calls + 1] = "render_changes"
    end,
    focus_changes = function(_, stage_type)
      calls[#calls + 1] = "focus_" .. stage_type
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.keymap", {
    setup_changes = function()
      calls[#calls + 1] = "setup_changes"
    end,
    setup_history = function()
      calls[#calls + 1] = "setup_history"
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {
    get = function()
      return {}
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.view", {
    render_commits = function(actual_history)
      t.assert_eq(history, actual_history, "History context")
      calls[#calls + 1] = "render_history"
    end,
  })

  vim.t[tabnr].tabtype = enums.TabTypeEnum.DIFFVIEW_WORKSPACE
  Fn.toggle_files()
  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL

  t.assert_eq(
    "toggle,setup_changes,render_changes,setup_history,render_history,focus_unstaged",
    table.concat(calls, ","),
    "sidebar restore pipeline"
  )
end)

t:run()
