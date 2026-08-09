---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_layout.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_layout")
local null_bufnr = vim.api.nvim_create_buf(false, true)
local render_calls = {} ---@type table[]
local metadata_widths = { insertion = 3, deletion = 2 }

t:patch_table(package.loaded, "era.m.diffview.config", { FILETREE_WIDTH = 40 })
t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
  apply_to_buffer = function() end,
  apply_winopts = function() end,
  create_buffer = function(stage_type)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.b[bufnr].stage_type = stage_type
    return bufnr
  end,
  measure_metadata = function()
    return metadata_widths
  end,
  render = function(_, opts)
    render_calls[#render_calls + 1] = opts
    return { lines = {}, highlights = {}, line_map = {} }
  end,
})
t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {
  apply_sbs_winopts = function() end,
  get_null_buffer = function()
    return null_bufnr
  end,
  restore_winopts = function() end,
})

local view = assert(loadfile("lua/era/m/diffview/view/workspace/view.lua"))()

local function with_changes_layout(callback)
  local original_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(original_winnr) ---@type integer
  local lyt = view.__create_layout_changes_only__(vim.api.nvim_get_current_tabpage())

  local ok, err = xpcall(function()
    callback(lyt)
  end, debug.traceback)

  local staged = lyt.changes.staged
  local unstaged = lyt.changes.unstaged
  if unstaged.winnr and vim.api.nvim_win_is_valid(unstaged.winnr) then
    vim.api.nvim_win_close(unstaged.winnr, true)
  end
  vim.api.nvim_set_current_win(original_winnr)
  vim.api.nvim_win_set_buf(original_winnr, original_bufnr)
  for _, pane in ipairs({ staged, unstaged }) do
    if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
      vim.api.nvim_buf_delete(pane.bufnr, { force = true })
    end
  end
  if not ok then
    error(err)
  end
end

t:test("layout creates staged above unstaged with independent buffers and focus", function()
  with_changes_layout(function(lyt)
    local staged = lyt.changes.staged
    local unstaged = lyt.changes.unstaged

    t.assert_true(staged.winnr ~= unstaged.winnr, "distinct windows")
    t.assert_true(staged.bufnr ~= unstaged.bufnr, "distinct buffers")
    t.assert_eq("staged", vim.b[staged.bufnr].stage_type, "staged buffer")
    t.assert_eq("unstaged", vim.b[unstaged.bufnr].stage_type, "unstaged buffer")

    local staged_row = vim.api.nvim_win_get_position(staged.winnr)[1]
    local unstaged_row = vim.api.nvim_win_get_position(unstaged.winnr)[1]
    t.assert_true(staged_row < unstaged_row, "staged is above unstaged")

    view.focus_changes(lyt)
    t.assert_eq(unstaged.winnr, vim.api.nvim_get_current_win(), "default focus is unstaged")
    view.cycle_focus(lyt)
    t.assert_eq(staged.winnr, vim.api.nvim_get_current_win(), "changes-only cycle wraps to staged")
    view.cycle_focus(lyt)
    t.assert_eq(unstaged.winnr, vim.api.nvim_get_current_win(), "cycle reaches unstaged")
  end)
end)

t:test("render shares metadata widths and restores the split after an empty pane", function()
  with_changes_layout(function(lyt)
    local entries = {
      { filepath = "a.lua", stage_type = "staged", status = "M" },
      { filepath = "b.lua", stage_type = "unstaged", status = "M" },
    }
    local state = {
      get_collapsed_dirs = function(_, stage_type)
        return { [stage_type] = true }
      end,
      get_entries = function()
        return entries
      end,
    }
    local ctx = { layout = lyt, state = state }

    render_calls = {}
    view.render_changes(ctx)
    t.assert_eq(2, #render_calls, "both panes rendered")
    t.assert_eq("staged", render_calls[1].stage_type, "staged render")
    t.assert_eq("unstaged", render_calls[2].stage_type, "unstaged render")
    t.assert_true(render_calls[1].metadata_widths == metadata_widths, "staged shared widths")
    t.assert_true(render_calls[2].metadata_widths == metadata_widths, "unstaged shared widths")
    t.assert_true(render_calls[1].collapsed_dirs.staged, "staged tree state")
    t.assert_true(render_calls[2].collapsed_dirs.unstaged, "unstaged tree state")

    local staged_winnr = lyt.changes.staged.winnr
    local unstaged_winnr = lyt.changes.unstaged.winnr
    vim.api.nvim_win_set_height(staged_winnr, 2)
    view.render_changes(ctx)
    entries = { entries[2] }
    view.render_changes(ctx)
    t.assert_eq(1, vim.api.nvim_win_get_height(staged_winnr), "empty staged header")
    local rendered = #render_calls
    vim.api.nvim_win_set_height(staged_winnr, 2)
    view.sync_changes_heights(ctx)
    t.assert_eq(1, vim.api.nvim_win_get_height(staged_winnr), "height-only drift corrected")
    t.assert_eq(rendered, #render_calls, "height sync does not rebuild pane buffers")

    entries = {
      { filepath = "a.lua", stage_type = "staged", status = "M" },
      { filepath = "b.lua", stage_type = "unstaged", status = "M" },
    }
    view.render_changes(ctx)
    t.assert_eq(2, vim.api.nvim_win_get_height(staged_winnr), "restored staged height")

    entries = { entries[1] }
    view.render_changes(ctx)
    t.assert_eq(1, vim.api.nvim_win_get_height(unstaged_winnr), "empty unstaged header")
  end)
end)

t:test("hide and show recreate both wiped sibling buffers as one panel", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local lyt = view.__create_layout_full__(tabnr)
  local staged_bufnr = lyt.changes.staged.bufnr
  local unstaged_bufnr = lyt.changes.unstaged.bufnr

  view.hide_changes(lyt)
  t.assert_nil(lyt.changes.staged.winnr, "staged hidden")
  t.assert_nil(lyt.changes.unstaged.winnr, "unstaged hidden")
  t.assert_false(vim.api.nvim_buf_is_valid(staged_bufnr), "staged buffer wiped")
  t.assert_false(vim.api.nvim_buf_is_valid(unstaged_bufnr), "unstaged buffer wiped")

  view.show_changes(lyt)
  t.assert_true(vim.api.nvim_win_is_valid(lyt.changes.staged.winnr), "staged shown")
  t.assert_true(vim.api.nvim_win_is_valid(lyt.changes.unstaged.winnr), "unstaged shown")
  t.assert_true(vim.api.nvim_buf_is_valid(lyt.changes.staged.bufnr), "staged buffer recreated")
  t.assert_true(vim.api.nvim_buf_is_valid(lyt.changes.unstaged.bufnr), "unstaged buffer recreated")
  t.assert_true(lyt.changes.staged.bufnr ~= lyt.changes.unstaged.bufnr, "distinct recreated buffers")

  view.destroy(lyt)
  t.assert_eq(original_tabnr, vim.api.nvim_get_current_tabpage(), "workspace tab closed")
end)

t:run()
