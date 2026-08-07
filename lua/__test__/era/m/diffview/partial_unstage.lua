---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/partial_unstage.lua

local bootstrap = require("__test__.bootstrap")
local Future = require("stl.c.future")
local harness = require("__test__.harness")
local staging = require("era.m.git.staging")

local t = harness.new("era.m.diffview.partial_unstage")
local errors = {} ---@type string[]

bootstrap.with_global(t, "stl", {
  async = require("stl.async"),
  c = { Future = Future },
  git = { info = {} },
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
bootstrap.with_global(t, "era", { m = { git = { staging = staging } } })

local config = {
  BUFOPTS_PANEL = {},
  BUFOPTS_SBS = {},
  FT = { SBS = "diffview-test" },
  TRACKED_WINOPTS = {},
  WINOPTS_SBS = { foldlevel = 0 },
}
bootstrap.with_global(t, "yoz", {})
t:patch_table(package.loaded, "era.m.diffview.config", config)

---@param predicate                     fun(): boolean
local function wait(predicate)
  t.wait_until(predicate, 5000, "async operation")
end

t:test("pane loader binds index bytes to the captured object hash", function()
  local blob_object = nil ---@type string|nil
  stl.git.info.get_file_info = function()
    return Future.resolve({
      ok = true,
      missing = false,
      info = {
        has_conflicts = false,
        mode_bits = "100644",
        object_name = "abc123",
        relpath = "f.txt",
      },
    })
  end
  stl.git.info.get_show_blob = function(_, object)
    blob_object = object
    return Future.resolve({ ok = true, missing = false, bytes = "index\n" })
  end

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = pane.load_git_content(":f.txt", bufnr)
  end)
  wait(function()
    return outcome ~= nil
  end)

  t.assert_true(outcome, "loaded")
  t.assert_eq("abc123", blob_object, "blob read by captured hash")
  t.assert_eq("abc123", vim.b[bufnr].git_object_name, "buffer snapshot")
  t.assert_eq("index\n", staging.from_buffer(bufnr).text, "buffer document")
  t.assert_eq(0, #errors, "no errors")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("workspace action forwards the right-buffer index snapshot", function()
  local captured = nil ---@type table|nil
  local opened = false ---@type boolean
  local refreshed = false ---@type boolean
  local workspace_view = {
    open_entry = function()
      opened = true
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.data", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", workspace_view)

  era.m.diffview = {
    util = {
      gen_index_bufname = function(filepath)
        return "diffview://index/" .. filepath
      end,
    },
  }
  era.m.git.buffer = {
    unstage_range = function(opts)
      captured = opts
      return Future.resolve({ ok = true })
    end,
  }

  local action = assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()
  action.refresh = function()
    refreshed = true
  end

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
      get_current_entry = function()
        return entry
      end,
    },
  }

  action.unstage_hunk(ctx, { 2, 3 })

  t.assert_true(captured ~= nil, "unstage called")
  t.assert_eq("abc123", captured.expected_index.object_name, "object snapshot")
  t.assert_eq("INDEX\n", captured.expected_index.document.text, "document snapshot")
  t.assert_eq(2, captured.range[1], "range start")
  t.assert_eq(3, captured.range[2], "range end")
  t.assert_true(refreshed, "view refreshed")
  t.assert_false(opened, "refresh owns reopening")
  t.assert_eq(0, #errors, "no errors")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("workspace keymaps route normal and visual ghu", function()
  local calls = {} ---@type table[]
  local action = {
    unstage_hunk = function(_, range)
      calls[#calls + 1] = range or {}
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", action)
  stl.nvim.buf.retrieve_visual_lnum_range = function()
    return 4, 6
  end

  local keymap = assert(loadfile("lua/era/m/diffview/view/workspace/keymap.lua"))()
  local normal = nil ---@type table|nil
  local visual = nil ---@type table|nil
  for _, mapping in ipairs(keymap.gen_sbs({})) do
    if mapping.key == "ghu" and mapping.modes[1] == "n" then
      normal = mapping
    elseif mapping.key == "ghu" and mapping.modes[1] == "x" then
      visual = mapping
    end
  end

  t.assert_true(normal ~= nil, "normal mapping")
  t.assert_true(visual ~= nil, "visual mapping")
  normal.callback()
  visual.callback()
  t.assert_eq(0, #calls[1], "normal cursor range")
  t.assert_eq(4, calls[2][1], "visual start")
  t.assert_eq(6, calls[2][2], "visual end")
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
  local keymap = {
    setup_sbs = function(_, bufnr)
      mapped[#mapped + 1] = bufnr
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.config", {})
  t:patch_table(package.loaded, "era.m.diffview.layout", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", pane)
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.keymap", keymap)

  vim.cmd("vnew")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vnew")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  local view = assert(loadfile("lua/era/m/diffview/view/workspace/view.lua"))()
  view.open_entry({ layout = { sbs_left_winnr = left_winnr, sbs_right_winnr = right_winnr } }, {})

  t.assert_eq(2, #mapped, "mapped buffers")
  t.assert_eq(vim.api.nvim_win_get_buf(left_winnr), mapped[1], "left replacement")
  t.assert_eq(vim.api.nvim_win_get_buf(right_winnr), mapped[2], "right replacement")
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_close(left_winnr, true)
end)

t:run()
