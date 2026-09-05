--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/diffview/workspace/layout_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.m.diffview.workspace.layout")
local null_bufnr = vim.api.nvim_create_buf(false, true)
local render_calls = {} ---@type table[]
local metadata_widths = { insertion = 3, deletion = 2 }
local panel_width = 40

t:patch_global("dot", {
  context = {
    diffview = {
      flag_untracked = {
        snapshot = function()
          return true
        end,
      },
      panel_width = {
        snapshot = function()
          return panel_width
        end,
      },
    },
  },
})

t:patch_table(package.loaded, "era.m.diffview.config", { FILETREE_WIDTH = 40, COMMITS_HEIGHT = 12 })
t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
  apply_to_buffer = function(bufnr, result)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)
  end,
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
  render = function(entries, opts)
    render_calls[#render_calls + 1] = opts
    local lines = {} ---@type string[]
    local line_map = {} ---@type era.m.diffview.IFiletreeLineMap[]
    for _, entry in ipairs(entries) do
      if entry.stage_type == opts.stage_type then
        lines[#lines + 1] = entry.filepath
        line_map[#line_map + 1] = { type = "file", entry = entry, stage_type = opts.stage_type }
      end
    end
    return { lines = lines, highlights = {}, line_map = line_map }
  end,
})
t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {
  apply_sbs_winopts = function() end,
  get_null_buffer = function()
    return null_bufnr
  end,
  restore_winopts = function() end,
})
t:patch_table(package.loaded, "era.m.diffview.pane.commits", {
  apply_winopts = function() end,
  create_buffer = function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    return bufnr
  end,
})
t:patch_table(package.loaded, "era.m.diffview.view.workspace.winline", {
  render_changes = function() end,
})

local view = assert(loadfile("lua/era/m/diffview/view/workspace/view.lua"))()

---@param lyt era.m.diffview.view.workspace.ILayout
---@param message string
local function assert_changes_balanced(lyt, message)
  local staged_height = vim.api.nvim_win_get_height(lyt.changes.staged.winnr) ---@type integer
  local unstaged_height = vim.api.nvim_win_get_height(lyt.changes.unstaged.winnr) ---@type integer
  local difference = unstaged_height - staged_height ---@type integer
  t.assert_true(difference >= 0 and difference <= 1, message)
end

local function with_changes_layout(callback)
  local original_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(original_winnr) ---@type integer
  local lyt = view.__create_layout_changes_only__(vim.api.nvim_get_current_tabpage())

  local ok, err = xpcall(function()
    callback(lyt)
  end, debug.traceback)

  local staged = lyt.changes.staged
  local unstaged = lyt.changes.unstaged
  local history = lyt.history
  if history.commits_winnr and vim.api.nvim_win_is_valid(history.commits_winnr) then
    vim.api.nvim_win_close(history.commits_winnr, true)
  end
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
  if history.commits_bufnr and vim.api.nvim_buf_is_valid(history.commits_bufnr) then
    vim.api.nvim_buf_delete(history.commits_bufnr, { force = true })
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
    local history_row = vim.api.nvim_win_get_position(lyt.history.commits_winnr)[1]
    t.assert_true(staged_row < unstaged_row, "staged is above unstaged")
    t.assert_true(unstaged_row < history_row, "History is below Changes")
    t.assert_eq(
      "no",
      vim.api.nvim_get_option_value("signcolumn", { win = lyt.history.commits_winnr }),
      "History hides signs"
    )
    t.assert_eq(
      " ",
      vim.api.nvim_get_option_value("statuscolumn", { win = lyt.history.commits_winnr }),
      "History keeps one leading screen column"
    )

    view.focus_changes(lyt)
    t.assert_eq(unstaged.winnr, vim.api.nvim_get_current_win(), "default focus is unstaged")
    view.cycle_focus(lyt)
    t.assert_eq(lyt.history.commits_winnr, vim.api.nvim_get_current_win(), "cycle reaches History")
    view.cycle_focus(lyt)
    t.assert_eq(staged.winnr, vim.api.nvim_get_current_win(), "cycle wraps to staged")
  end)
end)

t:test("History toggles at the bottom and shares preview ownership", function()
  with_changes_layout(function(lyt)
    local history_bufnr = lyt.history.commits_bufnr
    vim.api.nvim_buf_set_lines(lyt.changes.staged.bufnr, 0, -1, false, {
      "staged-1",
      "staged-2",
      "staged-3",
      "staged-4",
      "staged-5",
      "staged-6",
      "staged-7",
      "staged-8",
    })
    vim.api.nvim_buf_set_lines(lyt.changes.unstaged.bufnr, 0, -1, false, { "unstaged-header", "unstaged-1" })
    view.hide_history(lyt)
    t.assert_nil(lyt.history.commits_winnr, "History hidden")
    t.assert_true(vim.api.nvim_buf_is_valid(history_bufnr), "History buffer preserved")
    assert_changes_balanced(lyt, "hidden History leaves balanced Changes")

    view.show_history(lyt)
    t.assert_eq(history_bufnr, lyt.history.commits_bufnr, "History buffer reused")
    t.assert_eq(
      "no",
      vim.api.nvim_get_option_value("signcolumn", { win = lyt.history.commits_winnr }),
      "restored History hides signs"
    )
    t.assert_eq(
      " ",
      vim.api.nvim_get_option_value("statuscolumn", { win = lyt.history.commits_winnr }),
      "restored History window options"
    )
    t.assert_eq(2, vim.api.nvim_win_get_height(lyt.history.commits_winnr), "History restores one content row")
    assert_changes_balanced(lyt, "restored Changes remain balanced")
    local unstaged_row = vim.api.nvim_win_get_position(lyt.changes.unstaged.winnr)[1]
    local history_row = vim.api.nvim_win_get_position(lyt.history.commits_winnr)[1]
    t.assert_true(unstaged_row < history_row, "History restored below Changes")

    local history_ctx = view.history_context(lyt, {
      is_disposed = function()
        return false
      end,
    }, {
      is_disposed = function()
        return false
      end,
    })
    local history_is_current = assert(history_ctx.begin_preview)()
    t.assert_true(history_is_current(), "History owns preview")
    view.begin_preview(lyt, "changes")
    t.assert_false(history_is_current(), "Changes supersedes History preview")
  end)
end)

t:test("sidebar toggles Changes and History as one unit", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local lyt = view.__create_layout_full__(tabnr)
  local staged_bufnr = assert(lyt.changes.staged.bufnr) ---@type integer
  local unstaged_bufnr = assert(lyt.changes.unstaged.bufnr) ---@type integer
  local history_bufnr = assert(lyt.history.commits_bufnr) ---@type integer

  local _, visible = view.toggle_sidebar(lyt)
  t.assert_false(visible, "sidebar hidden")
  t.assert_nil(lyt.changes.staged.winnr, "Staged hidden")
  t.assert_nil(lyt.changes.unstaged.winnr, "Unstaged hidden")
  t.assert_nil(lyt.history.commits_winnr, "History hidden")

  _, visible = view.toggle_sidebar(lyt)
  t.assert_true(visible, "sidebar restored")
  t.assert_true(staged_bufnr ~= lyt.changes.staged.bufnr, "Staged buffer recreated")
  t.assert_true(unstaged_bufnr ~= lyt.changes.unstaged.bufnr, "Unstaged buffer recreated")
  t.assert_eq(history_bufnr, lyt.history.commits_bufnr, "History buffer reused")
  t.assert_true(vim.api.nvim_win_is_valid(assert(lyt.changes.staged.winnr)), "Staged restored")
  t.assert_true(vim.api.nvim_win_is_valid(assert(lyt.changes.unstaged.winnr)), "Unstaged restored")
  t.assert_true(vim.api.nvim_win_is_valid(assert(lyt.history.commits_winnr)), "History restored")

  view.destroy(lyt)
  t.assert_eq(original_tabnr, vim.api.nvim_get_current_tabpage(), "workspace tab closed")
end)

t:test("Changes restores the last focused sibling across SBS navigation and panel recreation", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local lyt = view.__create_layout_full__(tabnr)
  local staged_winnr = assert(lyt.changes.staged.winnr) ---@type integer
  local unstaged_winnr = assert(lyt.changes.unstaged.winnr) ---@type integer
  local left_winnr = assert(lyt.sbs_left_winnr) ---@type integer
  local right_winnr = assert(lyt.sbs_right_winnr) ---@type integer

  vim.api.nvim_set_current_win(staged_winnr)
  vim.api.nvim_set_current_win(left_winnr)
  view.focus_changes(lyt)
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "staged restored")

  vim.api.nvim_set_current_win(unstaged_winnr)
  vim.api.nvim_set_current_win(left_winnr)
  view.focus_changes(lyt)
  t.assert_eq(unstaged_winnr, vim.api.nvim_get_current_win(), "unstaged restored")

  vim.api.nvim_set_current_win(staged_winnr)
  vim.api.nvim_set_current_win(right_winnr)
  view.cycle_focus(lyt)
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "cycle restores staged")

  vim.api.nvim_set_current_win(unstaged_winnr)
  vim.api.nvim_set_current_win(left_winnr)
  view.hide_changes(lyt)
  view.show_changes(lyt)
  view.focus_changes(lyt)
  t.assert_eq(lyt.changes.unstaged.winnr, vim.api.nvim_get_current_win(), "recreated panel restores unstaged")
  t.assert_eq(2, vim.api.nvim_win_get_height(assert(lyt.history.commits_winnr)), "History content row restored")
  assert_changes_balanced(lyt, "recreated Changes remain balanced")

  view.destroy(lyt)
  t.assert_eq(original_tabnr, vim.api.nvim_get_current_tabpage(), "workspace tab closed")
end)

t:test("direct tab close releases the hidden History buffer and workspace layout", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local lyt = view.__create_layout_full__(tabnr)
  local history_bufnr = assert(lyt.history.commits_bufnr) ---@type integer
  view.set_layout(tabnr, lyt)

  vim.cmd.tabclose()

  t.assert_eq(original_tabnr, vim.api.nvim_get_current_tabpage(), "previous tab restored")
  t.assert_false(vim.api.nvim_buf_is_valid(history_bufnr), "History buffer deleted")
  t.assert_nil(view.get_layout(tabnr), "closed layout removed")
  t.assert_nil(view.__layout_cleanup_autocmds__[tabnr], "layout cleanup released")
end)

t:test("height allocation keeps one History content row and balances Changes", function()
  local even_changes = view.__allocate_changes_heights__(30, true)
  t.assert_eq(14, even_changes.staged, "Staged receives equal half")
  t.assert_eq(14, even_changes.unstaged, "Unstaged receives equal half")
  t.assert_eq(2, even_changes.history, "History owns winline and one content row")

  local odd_changes = view.__allocate_changes_heights__(29, true)
  t.assert_eq(13, odd_changes.staged, "Staged receives lower half")
  t.assert_eq(14, odd_changes.unstaged, "Unstaged receives odd remainder")
  t.assert_eq(2, odd_changes.history, "History remains one content row")

  local hidden_history = view.__allocate_changes_heights__(30, false)
  t.assert_eq(15, hidden_history.staged, "hidden History Staged half")
  t.assert_eq(15, hidden_history.unstaged, "hidden History Unstaged half")
  t.assert_eq(0, hidden_history.history, "hidden History has no allocation")
end)

t:test("render shares metadata widths without changing balanced pane heights", function()
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
    local history_winnr = lyt.history.commits_winnr
    assert_changes_balanced(lyt, "initial Changes heights")
    t.assert_eq(2, vim.api.nvim_win_get_height(history_winnr), "History shows one content row")
    vim.api.nvim_win_set_height(staged_winnr, 2)
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "render restores balanced Changes")
    entries = { entries[2] }
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "content does not bias Changes heights")
    local rendered = #render_calls
    vim.api.nvim_win_set_height(staged_winnr, 2)
    view.sync_changes_heights(lyt)
    assert_changes_balanced(lyt, "height-only drift corrected")
    t.assert_eq(rendered, #render_calls, "height sync does not rebuild pane buffers")

    entries = {
      { filepath = "a.lua", stage_type = "staged", status = "M" },
      { filepath = "b.lua", stage_type = "unstaged", status = "M" },
    }
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "refilled panes remain balanced")

    entries = { entries[1] }
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "empty Unstaged does not change proportions")
  end)
end)

t:test("hide and show recreate both wiped sibling buffers as one panel", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local lyt = view.__create_layout_full__(tabnr)
  local staged_bufnr = lyt.changes.staged.bufnr
  local unstaged_bufnr = lyt.changes.unstaged.bufnr
  t.assert_eq(panel_width, vim.api.nvim_win_get_width(lyt.changes.staged.winnr), "initial panel width")

  view.hide_changes(lyt)
  t.assert_nil(lyt.changes.staged.winnr, "staged hidden")
  t.assert_nil(lyt.changes.unstaged.winnr, "unstaged hidden")
  t.assert_false(vim.api.nvim_buf_is_valid(staged_bufnr), "staged buffer wiped")
  t.assert_false(vim.api.nvim_buf_is_valid(unstaged_bufnr), "unstaged buffer wiped")

  panel_width = 32
  view.show_changes(lyt)
  t.assert_true(vim.api.nvim_win_is_valid(lyt.changes.staged.winnr), "staged shown")
  t.assert_true(vim.api.nvim_win_is_valid(lyt.changes.unstaged.winnr), "unstaged shown")
  t.assert_true(vim.api.nvim_buf_is_valid(lyt.changes.staged.bufnr), "staged buffer recreated")
  t.assert_true(vim.api.nvim_buf_is_valid(lyt.changes.unstaged.bufnr), "unstaged buffer recreated")
  t.assert_true(lyt.changes.staged.bufnr ~= lyt.changes.unstaged.bufnr, "distinct recreated buffers")
  t.assert_eq(panel_width, vim.api.nvim_win_get_width(lyt.changes.staged.winnr), "restored panel width")

  view.destroy(lyt)
  t.assert_eq(original_tabnr, vim.api.nvim_get_current_tabpage(), "workspace tab closed")
end)

t:run()
