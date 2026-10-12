---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.diffview.native_expansion" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.m.diffview.native_expansion")
local native = require("__test__.support.result_tree")
local panels = require("era.m.diffview.pane.tree")
local commits = require("era.m.diffview.pane.commits")
local changes = require("era.m.diffview.pane.changes")
local commits_view = require("era.m.diffview.view.commits.view")
local commits_action = require("era.m.diffview.view.commits.action")
local workspace_view = require("era.m.diffview.view.workspace.view")
local workspace_action = require("era.m.diffview.view.workspace.action")

---@param bufnr                         integer
---@return integer
local function window(bufnr)
  local winnr = vim.api.nvim_open_win(bufnr, true, { relative = "editor", row = 0, col = 0, width = 60, height = 10 })
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return winnr
end

---@param owner                         era.view.ResultTree
---@param count                         integer
---@return nil
local function rows(owner, count)
  t.wait_until(function()
    return owner:linecount() == count
  end, 5000, "native expansion did not reach the surface")
  native.await(owner:ready())
  t.assert_eq(count, vim.api.nvim_buf_line_count(owner.view.bufnr))
end

---@param files                         ?era.m.diffview.IFileEntry[]
---@return table
---@return era.view.ResultTree
local function history(files)
  t:patch_table(dot.context.diffview.flag_panel_viewtype, "snapshot", function()
    return "tree"
  end)
  t:patch_table(dot.context.diffview.flag_foldempty, "snapshot", function()
    return false
  end)
  local bufnr = commits.create_buffer()
  local winnr = window(bufnr)
  local state = require("era.m.diffview.view.commits.state").State.new(vim.api.nvim_get_current_tabpage(), false)
  t:defer(function()
    state:dispose()
  end)
  local commit = { hash = "review", abbrev_hash = "review", author = "A", date = 0, message = "review", files = files }
  state:set_commits({ commit })
  state:set_current_commit(commit)
  local ctx = {
    state = state,
    layout = { tabnr = state.tabnr, layout_type = 2, commits_bufnr = bufnr, commits_winnr = winnr },
  }
  native.await(commits_view.render_commits(ctx))
  return ctx, state:get_tree("commits")
end

t:test("commit signs survive native attachment, resume and replacement windows", function()
  local ctx, owner = history()
  local winnr, bufnr = ctx.layout.commits_winnr, ctx.layout.commits_bufnr
  commits.update_sign_present(bufnr, 1)
  t.assert_eq("yes:1", vim.api.nvim_get_option_value("signcolumn", { win = winnr }))
  t.assert_eq(1, vim.fn.sign_getplaced(bufnr, { group = dot.var.sign.GROUP_DIFFVIEW_COMMITS })[1].signs[1].lnum)
  owner:unmount(true)
  native.await(commits_view.render_commits(ctx))
  t.assert_eq("yes:1", vim.api.nvim_get_option_value("signcolumn", { win = winnr }))
  owner:unmount(true)
  ctx.layout.commits_winnr = window(bufnr)
  local replacement = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(replacement) then
      vim.api.nvim_buf_delete(replacement, { force = true })
    end
  end)
  vim.api.nvim_win_set_buf(winnr, replacement)
  native.await(commits_view.render_commits(ctx))
  t.assert_eq("yes:1", vim.api.nvim_get_option_value("signcolumn", { win = ctx.layout.commits_winnr }))
  t.assert_eq(1, vim.fn.sign_getplaced(bufnr, { group = dot.var.sign.GROUP_DIFFVIEW_COMMITS })[1].signs[1].lnum)
end)

t:test("workspace History preserves its single spacer through native publication and reopening", function()
  local layout = workspace_view.create_layout(2)
  t:defer(function()
    workspace_view.destroy(layout)
  end)
  local state = require("era.m.diffview.view.commits.state").State.new(layout.tabnr, false)
  t:defer(function()
    state:dispose()
  end)
  state:set_commits({ { hash = "history", abbrev_hash = "history", author = "A", date = 0, message = "history" } })
  local ctx = { layout = layout.history, state = state }
  native.await(commits_view.render_commits(ctx))
  local winnr = layout.history.commits_winnr
  t.assert_eq("no", vim.api.nvim_get_option_value("signcolumn", { win = winnr }))
  t.assert_eq(" ", vim.api.nvim_get_option_value("statuscolumn", { win = winnr }))
  workspace_view.hide_history(layout)
  workspace_view.show_history(layout)
  native.await(commits_view.render_commits(ctx))
  winnr = layout.history.commits_winnr
  t.assert_eq("no", vim.api.nvim_get_option_value("signcolumn", { win = winnr }))
  t.assert_eq(" ", vim.api.nvim_get_option_value("statuscolumn", { win = winnr }))
end)

t:test("commit and directory expansion reuse imported records and publish native rows", function()
  local files = {}
  for index = 1, 300 do
    files[index] = { filepath = string.format("src/file%03d.lua", index), status = "M" }
  end
  local icons = 0
  t:patch_table(stl.fileicon, "get_file_icon", function()
    icons = icons + 1
    return "F", "Normal"
  end)
  local ctx, owner = history(files)
  t.assert_eq(0, icons, "record imports do not resolve file icons")
  t.assert_eq(2, owner._data:source():len(), "collapsed commits defer cached files")
  t.assert_nil(owner:data("commit:review").item.commit.files, "header snapshots do not copy the cached file list")
  local imports = 0
  local import = owner._import
  t:patch_table(owner, "_import", function(self, ...)
    imports = imports + 1
    return import(self, ...)
  end)
  commits_action.expand(ctx)
  rows(owner, 302)
  t.assert_eq(1, imports, "the first expansion materializes cached files once")
  imports = 0
  local source = owner.source
  native.await(owner.view:set_cursor(assert(owner:retrieve_lnum(panels.key("commit:review", "src", true)))))
  commits_action.collapse(ctx)
  rows(owner, 2)
  commits_action.expand(ctx)
  rows(owner, 302)
  commits_action.sbs_collapse(ctx)
  rows(owner, 1)
  commits_action.sbs_expand(ctx)
  rows(owner, 302)
  commits_action.collapse_all(ctx)
  rows(owner, 1)
  commits_action.expand_all(ctx)
  rows(owner, 302)
  t.assert_eq(0, imports, "pure expansion never imports records")
  t.assert_true(source == owner.source, "the producer is retained across expansion")
end)

t:test("standalone file loading defers inline records until the first inline expansion", function()
  local ctx, owner = history()
  local files = { { filepath = "src/loaded.lua", status = "M" } }
  local bufnr = require("era.m.diffview.pane.filetree").create_buffer()
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  ctx.layout.filetree_bufnr = bufnr
  t:patch_table(require("era.m.diffview.data"), "fetch_commit_files", function()
    return files
  end)
  local loaded = false
  stl.async.run(function()
    commits_action.__load_commit_files_and_render_filetree__(ctx, ctx.state:get_current_commit())
    loaded = true
  end)
  t.wait_until(function()
    return loaded
  end, 5000)
  native.await(owner:ready())
  t.assert_eq(1, owner:linecount(), "loading records preserves the collapsed commit")
  t.assert_eq(2, owner._data:source():len(), "the standalone pane does not prepare unused inline files")
  commits_action.expand(ctx)
  rows(owner, 3)
  t.assert_eq("src/loaded.lua", commits.get_item_at_line(ctx.layout.commits_bufnr, 3).entry.filepath)
end)

t:test("a failed first inline import stays collapsed and can be retried", function()
  local ctx, owner = history({ { filepath = "src/one.lua", status = "M" } })
  local fail, import = true, owner._import
  t:patch_table(owner, "_import", function(self, ...)
    if fail then
      fail = false
      return stl.c.Future.reject("injected inline import failure")
    end
    return import(self, ...)
  end)
  t:patch_table(stl.reporter, "error", function() end)
  local finished, succeeded
  stl.async.run(function()
    succeeded = pcall(commits_action.__expand_commit__, ctx, ctx.state:get_current_commit())
    finished = true
  end)
  t.wait_until(function()
    return finished
  end, 5000)
  t.assert_false(succeeded)
  t.assert_false(ctx.state:is_commit_expanded("review"))
  t.assert_eq(1, owner:linecount())
  commits_action.sbs_expand(ctx)
  rows(owner, 3)
  t.assert_eq("src/one.lua", commits.get_item_at_line(ctx.layout.commits_bufnr, 3).entry.filepath)
end)

t:test("a hidden Commits pane can materialize and restore its logical expansion", function()
  local ctx, owner = history({ { filepath = "src/hidden.lua", status = "M" } })
  vim.api.nvim_win_close(ctx.layout.commits_winnr, true)
  ctx.layout.commits_winnr, ctx.layout.commits_bufnr = nil, nil
  local done = false
  stl.async.run(function()
    commits_action.__expand_commit__(ctx, ctx.state:get_current_commit())
    done = true
  end)
  t.wait_until(function()
    return done
  end, 5000)
  t.assert_true(ctx.state:is_commit_expanded("review"))
  t.assert_true(owner:data("commit:review").files_loaded)
  local bufnr = commits.create_buffer()
  ctx.layout.commits_bufnr, ctx.layout.commits_winnr = bufnr, window(bufnr)
  native.await(commits_view.render_commits(ctx))
  rows(owner, 3)
  t.assert_eq("src/hidden.lua", commits.get_item_at_line(bufnr, 3).entry.filepath)
end)

for _, all in ipairs({ false, true }) do
  t:test((all and "expand all" or "single expansion") .. " abandons an older content generation", function()
    local ctx, owner = history()
    local replacement = { hash = "review", abbrev_hash = "review", author = "A", date = 0, message = "new request" }
    local publication
    t:patch_table(require("era.m.diffview.data"), "fetch_commit_files", function()
      ctx.state:begin_content_request()
      ctx.state:set_commits({ replacement })
      ctx.state:set_current_commit(replacement)
      publication = commits_view.render_commits(ctx)
      return { { filepath = "obsolete.lua", status = "M" } }
    end)
    if all then
      commits_action.expand_all(ctx)
    else
      commits_action.sbs_expand(ctx)
    end
    t.wait_until(function()
      return publication and publication:is_done() and ctx.state._materialization._pending == 0
    end, 5000)
    native.await(owner:ready())
    t.assert_eq(1, owner:linecount())
    t.assert_false(ctx.state:is_commit_expanded("review"))
    t.assert_false(owner:data("commit:review").files_loaded)
  end)
end

t:test("Changes actions update expansion without rebuilding either pane's records", function()
  t:patch_table(dot.context.diffview.flag_panel_viewtype, "snapshot", function()
    return "tree"
  end)
  t:patch_table(dot.context.diffview.flag_foldempty, "snapshot", function()
    return false
  end)
  local bufnr = changes.create_buffer("staged")
  local winnr = window(bufnr)
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
  local ctx = {
    state = state,
    layout = {
      tabnr = state.tabnr,
      changes = {
        staged = { stage_type = "staged", bufnr = bufnr, winnr = winnr },
        unstaged = { stage_type = "unstaged" },
      },
    },
  }
  native.await(workspace_view.render_changes(ctx))
  local owner = state:get_tree("staged")
  local imports, import = 0, owner._import
  t:patch_table(owner, "_import", function(self, ...)
    imports = imports + 1
    return import(self, ...)
  end)
  workspace_action.toggle_collapse(ctx)
  rows(owner, 1)
  workspace_action.toggle_collapse(ctx)
  rows(owner, 3)
  workspace_action.sbs_collapse(ctx)
  rows(owner, 1)
  workspace_action.sbs_expand(ctx)
  rows(owner, 3)
  workspace_action.sbs_collapse_all(ctx)
  rows(owner, 1)
  workspace_action.sbs_expand_all(ctx)
  rows(owner, 3)
  t.assert_eq(0, imports)
  local frame = owner:frame()
  local id = frame:source():id(panels.key(nil, "src/a.lua", false))
  t.assert_eq("a.lua", frame:node(id).fields.file_icon, "metadata overlays retain lazy icons")
end)

t:run()
