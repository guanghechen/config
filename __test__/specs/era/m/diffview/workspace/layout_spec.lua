require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local WorkspaceState = require("era.m.diffview.view.workspace.state").State
local pane_changes = require("era.m.diffview.pane.changes")
local view = require("era.m.diffview.view.workspace.view")

---Sets the remembered Changes width for the rest of the case.
---@param width                         integer
---@return nil
local function remember_panel_width(width)
  local panel_width = dot.context.diffview.panel_width
  local initial = panel_width:snapshot()
  t:defer(function()
    panel_width:next(initial)
  end)
  panel_width:next(width)
end

---Writes `lines` into a read-only panel buffer.
---@param bufnr                         integer
---@param lines                         string[]
---@return nil
local function fill(bufnr, lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

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
    t.assert_eq("staged", pane_changes.get_stage_type(staged.bufnr), "staged buffer")
    t.assert_eq("unstaged", pane_changes.get_stage_type(unstaged.bufnr), "unstaged buffer")

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
    fill(lyt.changes.staged.bufnr, {
      "staged-1",
      "staged-2",
      "staged-3",
      "staged-4",
      "staged-5",
      "staged-6",
      "staged-7",
      "staged-8",
    })
    fill(lyt.changes.unstaged.bufnr, { "unstaged-header", "unstaged-1" })
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

    local history_generation = view.begin_preview(lyt, "history")
    t.assert_true(view.owns_preview(lyt, history_generation), "History owns preview")
    view.begin_preview(lyt, "changes")
    t.assert_false(view.owns_preview(lyt, history_generation), "Changes supersedes History preview")
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

t:test("changes resize renders width changes and remembers only widths the user chose", function()
  ---@return era.m.diffview.view.workspace.IChangesSize
  local function size(winnrs, width, columns, lines)
    return {
      winnrs = winnrs,
      widths = width and (width .. "|" .. width) or "",
      width = width,
      columns = columns,
      lines = lines,
    }
  end
  local previous = size("42|43", 40, 200, 60)
  for _, step in ipairs({
    { size("42|43", 40, 200, 60), false, nil, false, "same width" },
    { size("42|43", 40, 200, 70), false, nil, true, "terminal height resyncs heights" },
    { size("42|43", 40, 200, 70), false, nil, false, "unchanged height" },
    { size("42|43", 5, 200, 70), true, 5, false, "a width the user chose" },
    { size("42|43", 40, 240, 70), true, nil, false, "terminal width resize" },
    { size("44|45", 24, 240, 70), true, nil, false, "recreated panes inherit the preference" },
    { size("44|45", 18, 240, 70), true, 18, false, "recreated panes resized by the user" },
    { size("", nil, 240, 70), false, nil, false, "hidden Changes" },
  }) do
    local current, render, remember, sync, label = unpack(step)
    local resize = view.changes_resize(previous, current)
    t.assert_eq(render, resize.render, label .. ": render")
    t.assert_eq(remember, resize.remember_width, label .. ": remembered width")
    t.assert_eq(sync, resize.sync_heights, label .. ": height sync")
    previous = current
  end
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
    local state = WorkspaceState.new(lyt.tabnr or vim.api.nvim_get_current_tabpage(), true)
    t:defer(function()
      state:dispose()
    end)
    state:set_entries(entries)
    local requested_trees = {} ---@type string[]
    local get_tree = state.get_tree
    t:patch_table(state, "get_tree", function(self, stage_type)
      requested_trees[#requested_trees + 1] = stage_type
      return get_tree(self, stage_type)
    end)
    local metadata_widths = { insertion = 3, deletion = 2 }
    t:patch_table(pane_changes, "measure_metadata", function()
      return metadata_widths
    end)
    local render_calls = {} ---@type table[]
    local render = pane_changes.render
    t:patch_table(pane_changes, "render", function(items, opts)
      render_calls[#render_calls + 1] = opts
      return render(items, opts)
    end)
    local ctx = { layout = lyt, state = state }

    view.render_changes(ctx)
    t.assert_eq(2, #render_calls, "both panes rendered")
    t.assert_eq("staged", render_calls[1].stage_type, "staged render")
    t.assert_eq("unstaged", render_calls[2].stage_type, "unstaged render")
    t.assert_true(render_calls[1].metadata_widths == metadata_widths, "staged shared widths")
    t.assert_true(render_calls[2].metadata_widths == metadata_widths, "unstaged shared widths")
    t.assert_eq("staged", requested_trees[1], "staged tree owner")
    t.assert_eq("unstaged", requested_trees[2], "unstaged tree owner")

    local staged_winnr = lyt.changes.staged.winnr
    local history_winnr = lyt.history.commits_winnr
    assert_changes_balanced(lyt, "initial Changes heights")
    t.assert_eq(2, vim.api.nvim_win_get_height(history_winnr), "History shows one content row")
    vim.api.nvim_win_set_height(staged_winnr, 2)
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "render restores balanced Changes")
    state:set_entries({ entries[2] })
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "content does not bias Changes heights")
    local rendered = #render_calls
    vim.api.nvim_win_set_height(staged_winnr, 2)
    view.sync_changes_heights(lyt)
    assert_changes_balanced(lyt, "height-only drift corrected")
    t.assert_eq(rendered, #render_calls, "height sync does not rebuild pane buffers")

    state:set_entries(entries)
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "refilled panes remain balanced")

    state:set_entries({ entries[1] })
    view.render_changes(ctx)
    assert_changes_balanced(lyt, "empty Unstaged does not change proportions")
  end)
end)

t:test("hide and show recreate both wiped sibling buffers as one panel", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  remember_panel_width(40)
  local lyt = view.__create_layout_full__(tabnr)
  local staged_bufnr = lyt.changes.staged.bufnr
  local unstaged_bufnr = lyt.changes.unstaged.bufnr
  t.assert_eq(40, vim.api.nvim_win_get_width(lyt.changes.staged.winnr), "initial panel width")

  view.hide_changes(lyt)
  t.assert_nil(lyt.changes.staged.winnr, "staged hidden")
  t.assert_nil(lyt.changes.unstaged.winnr, "unstaged hidden")
  t.assert_false(vim.api.nvim_buf_is_valid(staged_bufnr), "staged buffer wiped")
  t.assert_false(vim.api.nvim_buf_is_valid(unstaged_bufnr), "unstaged buffer wiped")

  dot.context.diffview.panel_width:next(32)
  view.show_changes(lyt)
  t.assert_true(vim.api.nvim_win_is_valid(lyt.changes.staged.winnr), "staged shown")
  t.assert_true(vim.api.nvim_win_is_valid(lyt.changes.unstaged.winnr), "unstaged shown")
  t.assert_true(vim.api.nvim_buf_is_valid(lyt.changes.staged.bufnr), "staged buffer recreated")
  t.assert_true(vim.api.nvim_buf_is_valid(lyt.changes.unstaged.bufnr), "unstaged buffer recreated")
  t.assert_true(lyt.changes.staged.bufnr ~= lyt.changes.unstaged.bufnr, "distinct recreated buffers")
  t.assert_eq(32, vim.api.nvim_win_get_width(lyt.changes.staged.winnr), "restored panel width")

  view.destroy(lyt)
  t.assert_eq(original_tabnr, vim.api.nvim_get_current_tabpage(), "workspace tab closed")
end)

t:run()
