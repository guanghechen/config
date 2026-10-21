local bootstrap = require("__test__.support.bootstrap")
local Future = require("stl.c.future")
local harness = require("__test__.support.harness")
local staging = require("era.m.git.staging")

local t = harness.new()
local errors = {} ---@type string[]

bootstrap.with_global(t, "stl", {
  env = { PATH_SEP = "/" },
  async = require("stl.async"),
  c = { Future = Future },
  nvim = { buf = {
    locate_bufnr = function()
      return nil
    end,
  } },
  reporter = {
    error = function(report)
      errors[#errors + 1] = report.message
    end,
    warn = function(report)
      errors[#errors + 1] = report.message
    end,
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
    workspace = function()
      return "/repo"
    end,
  },
})
bootstrap.with_global(t, "era", { m = { diffview = {}, git = { staging = staging } } })

local config = {
  BUFOPTS_PANEL = {},
  BUFOPTS_SBS = {},
  FT = { SBS = "diffview-test" },
  TRACKED_WINOPTS = {},
  WINOPTS_SBS = { foldlevel = 0 },
}
bootstrap.with_global(t, "yoz", {})
t:patch_table(package.loaded, "era.m.diffview.config", config)
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return "/repo/" .. filepath
  end,
})

t:test("workspace action forwards the right-buffer index snapshot", function()
  local captured = nil ---@type table|nil
  local opened = false ---@type boolean
  local refreshed = false ---@type boolean
  local workspace_view = {
    open_entry = function()
      opened = true
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", workspace_view)

  t:patch_table(package.loaded["era.m.diffview.util"], "gen_index_bufname", function(filepath)
    return "diffview://index/" .. filepath
  end)
  era.m.git.buffer = {
    unstage_range = function(opts)
      captured = opts
      return Future.resolve({ ok = true })
    end,
  }

  local action = assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()

  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, "diffview://index/f.txt")
  staging.replace_buffer_text(bufnr, "INDEX\n")
  vim.b[bufnr].git_object_name = "abc123"
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  local entry = { filepath = "f.txt", stage_type = "staged", status = "M" }
  local ctx = {
    layout = { sbs_right_winnr = winnr },
    state = {
      request_refresh = function()
        refreshed = true
      end,
      get_current_entry = function()
        return entry
      end,
    },
  }

  local future = action.unstage_hunk(ctx, { 2, 3 })

  t.assert_true(future ~= nil, "unstage future")
  t.assert_true(captured ~= nil, "unstage called")
  local unstage_opts = assert(captured)
  t.assert_eq("abc123", unstage_opts.expected_index.object_name, "object snapshot")
  t.assert_eq("INDEX\n", unstage_opts.expected_index.document.text, "document snapshot")
  t.assert_eq(2, unstage_opts.range[1], "range start")
  t.assert_eq(3, unstage_opts.range[2], "range end")
  t.assert_true(refreshed, "view refreshed")
  t.assert_false(opened, "refresh owns reopening")
  t.assert_eq(0, #errors, "no errors")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("workspace view binds keymaps after replacing null buffers", function()
  local mapped = {} ---@type integer[]
  local pane = {
    open_diff_entry = function(opts)
      local left_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      local right_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      vim.api.nvim_win_set_buf(opts.left_winnr, left_bufnr)
      vim.api.nvim_win_set_buf(opts.right_winnr, right_bufnr)
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", pane)

  vim.cmd("vnew")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vnew")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  local view = assert(loadfile("lua/era/m/diffview/view/workspace/view.lua"))()
  view.open_entry({
    layout = { sbs_left_winnr = left_winnr, sbs_right_winnr = right_winnr },
    state = {
      get_fold_unchanged = function()
        return true
      end,
      is_disposed = function()
        return false
      end,
    },
    setup_sbs = function(_, bufnr)
      mapped[#mapped + 1] = bufnr
    end,
  }, {})

  t.assert_eq(2, #mapped, "mapped buffers")
  t.assert_eq(vim.api.nvim_win_get_buf(left_winnr), mapped[1], "left replacement")
  t.assert_eq(vim.api.nvim_win_get_buf(right_winnr), mapped[2], "right replacement")
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_close(left_winnr, true)
end)

t:run()
