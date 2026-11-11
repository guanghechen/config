require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local treeview = require("__test__.support.treeview")
local tree = require("era.m.diffview.pane.tree")
local changes = require("era.m.diffview.pane.changes")
local action = require("era.m.diffview.view.workspace.action")
local view = require("era.m.diffview.view.workspace.view")

---@param stage                         string
---@param entries                       table[]
---@param options                       ?table
---@return era.view.ResultTree
---@return table
---@return table
local function pane(stage, entries, options)
  local defaults = { stage_type = stage, viewtype = "tree", foldempty = true }
  return diffview.changes_pane(t, entries, vim.tbl_extend("force", defaults, options or {}), true)
end

---@param panes                         table[]
---@param current                       ?table
---@return table
local function context(panes, current)
  local layout = { changes = { staged = { stage_type = "staged" }, unstaged = { stage_type = "unstaged" } } }
  for _, item in ipairs(panes) do
    layout.changes[item.stage_type] = item
  end
  t:patch_table(view, "open_entry", function() end)
  return {
    layout = layout,
    state = {
      get_entries = function()
        error("navigation must not collect or sort the producer")
      end,
      get_current_entry = function()
        return current
      end,
      set_current_entry = function(_, entry)
        current = entry
      end,
      get_tree = function(_, stage)
        return tree.owner(layout.changes[stage].bufnr)
      end,
    },
  }
end

t:test("adjacent navigation reads only its target after a metadata publication", function()
  local entries = {}
  for index = 1, 5000 do
    entries[index] = { filepath = string.format("file%05d.lua", index), stage_type = "unstaged", status = "M" }
  end
  local owner, panel, plan = pane("unstaged", entries, { viewtype = "list" })
  local frame = owner:frame()
  t.assert_eq(1, frame:adjacent_leaf(nil, true))
  t.assert_eq(5000, frame:adjacent_leaf(nil, false))
  t.assert_nil(frame:adjacent_leaf(0, true))
  t.assert_nil(frame:adjacent_leaf(5001, false))
  local ctx = context({ panel })
  local reads, item = 0, tree.item
  t:patch_table(tree, "item", function(...)
    reads = reads + 1
    return item(...)
  end)
  local writes, set_lines = 0, vim.api.nvim_buf_set_lines
  t:patch_table(vim.api, "nvim_buf_set_lines", function(bufnr, ...)
    if bufnr == panel.bufnr then
      writes = writes + 1
    end
    return set_lines(bufnr, ...)
  end)
  action.next_entry(ctx)
  t.assert_eq(2, vim.api.nvim_win_get_cursor(panel.winnr)[1])
  t.assert_eq(entries[2].filepath, ctx.state:get_current_entry().filepath)
  t.assert_true(reads <= 3, "cold navigation must not materialize every row")
  t.assert_eq(0, writes, "cursor movement does not rewrite body text")

  plan.source:get(tree.key(nil, entries[1].filepath, false)).presentation.right_text = "changed"
  treeview.await(tree.apply(panel.bufnr, plan, owner))
  reads, writes = 0, 0
  vim.api.nvim_win_set_cursor(panel.winnr, { 1, 0 })
  action.next_entry(ctx)
  t.assert_true(reads <= 3, "metadata changes must not restore a full-row export")
  t.assert_eq(0, writes)
end)

t:test("cross-pane navigation resolves duplicate paths by stage and wraps", function()
  local entry = { filepath = "same.lua", stage_type = "staged", status = "M" }
  local _, staged = pane("staged", { entry })
  local _, unstaged = pane("unstaged", { { filepath = "same.lua", stage_type = "unstaged", status = "M" } })
  local ctx = context({ staged, unstaged }, entry)
  vim.api.nvim_set_current_win(staged.winnr)
  action.goto_next_entry(ctx)
  t.assert_eq("unstaged", ctx.state:get_current_entry().stage_type)
  t.assert_eq(unstaged.winnr, vim.api.nvim_get_current_win())
  action.goto_next_entry(ctx)
  t.assert_eq("staged", ctx.state:get_current_entry().stage_type)
  t.assert_eq(staged.winnr, vim.api.nvim_get_current_win())
  action.goto_prev_entry(ctx)
  t.assert_eq("unstaged", ctx.state:get_current_entry().stage_type)
end)

t:test("a file hidden by a folded path keeps its navigation direction", function()
  local hidden = { filepath = "a/b/hidden.lua", stage_type = "unstaged", status = "M" }
  local visible = { filepath = "c/visible.lua", stage_type = "unstaged", status = "M" }
  local last = { filepath = "z.lua", stage_type = "unstaged", status = "M" }
  local owner, panel = pane("unstaged", { hidden, visible, last })
  owner:collapse(tree.key(nil, "a/b", true), "collapse", false)
  treeview.await(owner:ready())
  t.assert_nil(changes.find_entry_line(panel.bufnr, hidden))
  local anchor = changes.find_entry_anchor(panel.bufnr, hidden)
  t.assert_eq("a/b", changes.get_item_at_line(panel.bufnr, anchor).uuid)
  local ctx = context({ panel }, hidden)
  action.goto_next_entry(ctx)
  t.assert_eq(visible.filepath, ctx.state:get_current_entry().filepath)
  ctx.state:set_current_entry(hidden)
  action.goto_prev_entry(ctx)
  t.assert_eq(last.filepath, ctx.state:get_current_entry().filepath)
end)

t:test("directory transfers skip the native subtree when choosing the next file", function()
  local entries = {}
  for index = 1, 5000 do
    entries[index] = { filepath = string.format("src/file%05d.lua", index), stage_type = "unstaged", status = "M" }
  end
  local tail = { filepath = "z.lua", stage_type = "unstaged", status = "M" }
  entries[#entries + 1] = tail
  local _, panel = pane("unstaged", entries)
  local ctx = context({ panel }, entries[1])
  ctx.state.get_entries = function()
    return entries
  end
  local refreshed = false
  ctx.state.request_refresh = function(_, callback)
    refreshed = true
    callback()
  end
  t:patch_table(era.m.git.index, "run", function(_, callback)
    return stl.c.Future.new(callback)
  end)
  t:patch_table(stl.git.exec, "exec_async", function(_, _, callback)
    callback({}, 0, "")
  end)
  local reads, item = 0, tree.item
  t:patch_table(tree, "item", function(...)
    reads = reads + 1
    return item(...)
  end)
  vim.api.nvim_win_set_cursor(panel.winnr, { 1, 0 })
  action.stage(ctx)
  t.wait_until(function()
    return refreshed
  end, 5000)
  t.assert_eq(tail.filepath, ctx.state:get_current_entry().filepath)
  t.assert_true(reads <= 5, "choosing a fallback must not read every transferred file")
end)

t:test("navigation across collapsed directories exports only the destination", function()
  local entries = {}
  for index = 1, 5000 do
    entries[index] = { filepath = string.format("dir%05d/file.lua", index), stage_type = "unstaged", status = "M" }
  end
  local target = { filepath = "z.lua", stage_type = "unstaged", status = "M" }
  entries[#entries + 1] = target
  local owner, panel = pane("unstaged", entries)
  owner:set_expansion(tree.root, false, true)
  treeview.await(owner:ready())
  t.assert_eq(5001, owner:linecount())
  local ctx = context({ panel })
  local reads, item = 0, tree.item
  t:patch_table(tree, "item", function(...)
    reads = reads + 1
    return item(...)
  end)
  vim.api.nvim_win_set_cursor(panel.winnr, { 1, 0 })
  action.next_entry(ctx)
  t.assert_eq(target.filepath, ctx.state:get_current_entry().filepath)
  t.assert_true(reads <= 3, "skipped directories must stay native; item reads: " .. reads)
end)

t:test("Changes actions update expansion without rebuilding either pane's records", function()
  t:patch_table(dot.context.diffview.flag_panel_viewtype, "snapshot", function()
    return "tree"
  end)
  t:patch_table(dot.context.diffview.flag_foldempty, "snapshot", function()
    return false
  end)
  local bufnr = changes.create_buffer("staged")
  local winnr = diffview.panel_window(t, bufnr)
  local state = require("era.m.diffview.view.workspace.state").State.new(vim.api.nvim_get_current_tabpage(), false)
  t:defer(function()
    state:dispose()
  end)
  local files = {
    { filepath = "src/a.lua", stage_type = "staged", status = "M" },
    { filepath = "src/b.lua", stage_type = "staged", status = "M" },
  }
  state:set_entries(files)
  state:set_current_entry(files[1])
  local ctx = diffview.workspace_context({
    state = state,
    layout = {
      tabnr = state.tabnr,
      changes = {
        staged = { stage_type = "staged", bufnr = bufnr, winnr = winnr },
        unstaged = { stage_type = "unstaged" },
      },
    },
  })
  treeview.await(view.render_changes(ctx))
  local owner = state:get_tree("staged")
  local imports, import = 0, owner._import
  t:patch_table(owner, "_import", function(self, ...)
    imports = imports + 1
    return import(self, ...)
  end)
  action.toggle_collapse(ctx)
  diffview.await_rows(t, owner, 1)
  action.toggle_collapse(ctx)
  diffview.await_rows(t, owner, 3)
  action.sbs_collapse(ctx)
  diffview.await_rows(t, owner, 1)
  action.sbs_expand(ctx)
  diffview.await_rows(t, owner, 3)
  action.sbs_collapse_all(ctx)
  diffview.await_rows(t, owner, 1)
  action.sbs_expand_all(ctx)
  diffview.await_rows(t, owner, 3)
  t.assert_eq(0, imports)
  local frame = owner:frame()
  local id = frame:source():id(tree.key(nil, "src/a.lua", false))
  t.assert_eq("a.lua", frame:node(id).fields.file_icon, "metadata overlays retain lazy icons")
end)

t:run()
