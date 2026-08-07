---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_preview.lua

local bootstrap = require("__test__.bootstrap")
local Future = require("stl.c.future")
local harness = require("__test__.harness")
local staging = require("era.m.git.staging")

local t = harness.new("era.m.diffview.workspace_preview")

bootstrap.with_global(t, "stl", {
  async = require("stl.async"),
  git = { info = {} },
  nvim = { buf = {
    locate_bufnr = function()
      return nil
    end,
  } },
  reporter = {
    error = function() end,
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
  WINOPTS_SBS = {
    cursorbind = true,
    diff = true,
    foldcolumn = "0",
    foldenable = true,
    foldlevel = 0,
    foldmethod = "diff",
    scrollbind = true,
  },
}
t:patch_table(package.loaded, "era.m.diffview.config", config)

---@param predicate                     fun(): boolean
local function wait(predicate)
  t.wait_until(predicate, 5000, "async preview operation")
end

---@return integer left_winnr
---@return integer right_winnr
local function create_windows()
  vim.cmd("new")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("new")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  return left_winnr, right_winnr
end

---@param left_winnr                    integer
---@param right_winnr                   integer
local function close_windows(left_winnr, right_winnr)
  if vim.api.nvim_win_is_valid(right_winnr) then
    vim.api.nvim_win_close(right_winnr, true)
  end
  if vim.api.nvim_win_is_valid(left_winnr) then
    vim.api.nvim_win_close(left_winnr, true)
  end
end

t:test("workspace preview generation makes the latest request the sole writer", function()
  local requests = {} ---@type era.m.diffview.pane.sbs.IOpenDiffOpts[]
  local clear_is_current = nil ---@type (fun(): boolean)|nil
  t:patch_table(package.loaded, "era.m.diffview.layout", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {
    clear = function(_, _, is_current)
      clear_is_current = is_current
    end,
    open_diff_entry = function(opts)
      requests[#requests + 1] = opts
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.keymap", {
    setup_sbs = function() end,
  })

  local view = assert(loadfile("lua/era/m/diffview/view/workspace/view.lua"))()
  local left_winnr, right_winnr = create_windows()
  local ctx = {
    layout = {
      tabnr = vim.api.nvim_get_current_tabpage(),
      layout_type = 1,
      sbs_left_winnr = left_winnr,
      sbs_right_winnr = right_winnr,
      preview_generation = 0,
    },
    state = {},
  }

  view.open_entry(ctx, { filepath = "a.lua", stage_type = "staged", status = "M" }, nil, {
    preserve_view = true,
  })
  view.open_entry(ctx, { filepath = "b.lua", stage_type = "staged", status = "M" })

  t.assert_false(requests[1].is_current(), "older request invalidated")
  t.assert_true(requests[2].is_current(), "latest request current")
  t.assert_true(requests[1].preserve_view, "preserve option forwarded")

  view.clear_sbs(ctx)
  t.assert_false(requests[2].is_current(), "clear invalidates open request")
  t.assert_true(assert(clear_is_current)(), "clear owns latest generation")
  close_windows(left_winnr, right_winnr)
end)

t:test("stale async load cannot overwrite a shared preview buffer", function()
  t:patch_table(stl.git.info, "get_show_blob", function()
    return Future.resolve({ ok = true, bytes = "NEW\n" })
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "OLD" })
  local current = true
  local outcome = nil ---@type boolean|nil

  stl.async.run(function()
    outcome = pane.load_git_content("HEAD:f.txt", bufnr, nil, function()
      return current
    end)
  end)
  current = false
  wait(function()
    return outcome ~= nil
  end)

  t.assert_false(outcome, "stale load aborted")
  t.assert_eq("OLD", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "buffer unchanged")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("matching refresh preserves view without resetting diff folds", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local left_winnr, right_winnr = create_windows()
  local left_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local right_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local stale_left_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local stale_right_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
  vim.api.nvim_win_set_buf(right_winnr, right_bufnr)

  pane.__apply_buffers__(left_winnr, right_winnr, stale_left_bufnr, stale_right_bufnr, {
    is_current = function()
      return false
    end,
  })
  t.assert_eq(left_bufnr, vim.api.nvim_win_get_buf(left_winnr), "stale left commit rejected")
  t.assert_eq(right_bufnr, vim.api.nvim_win_get_buf(right_winnr), "stale right commit rejected")

  local fold_resets = 0
  local restored = {} ---@type table[]
  t:patch_table(pane, "apply_sbs_diff_winopts", function()
    fold_resets = fold_resets + 1
  end)
  t:patch_table(vim.fn, "winrestview", function(view)
    restored[#restored + 1] = view
  end)

  pane.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr, {
    is_current = function()
      return true
    end,
    preserve_view = true,
    left_view = { lnum = 7, topline = 3 },
    right_view = { lnum = 9, topline = 4 },
  })
  wait(function()
    return #restored == 2
  end)

  t.assert_eq(0, fold_resets, "diff folds retained")
  t.assert_eq(7, restored[1].lnum, "left view restored")
  t.assert_eq(9, restored[2].lnum, "right view restored")

  close_windows(left_winnr, right_winnr)
  for _, bufnr in ipairs({ left_bufnr, right_bufnr, stale_left_bufnr, stale_right_bufnr }) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end)

t:run()
