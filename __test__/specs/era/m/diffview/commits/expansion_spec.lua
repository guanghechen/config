require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local treeview = require("__test__.support.treeview")
local panels = require("era.m.diffview.pane.tree")
local commits = require("era.m.diffview.pane.commits")
local commits_view = require("era.m.diffview.view.commits.view")
local commits_action = require("era.m.diffview.view.commits.action")

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
  local ctx, owner = diffview.review_pane(t, files)
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
  diffview.await_rows(t, owner, 302)
  t.assert_eq(1, imports, "the first expansion materializes cached files once")
  imports = 0
  local source = owner.source
  treeview.await(owner.view:set_cursor(assert(owner:retrieve_lnum(panels.key("commit:review", "src", true)))))
  commits_action.collapse(ctx)
  diffview.await_rows(t, owner, 2)
  commits_action.expand(ctx)
  diffview.await_rows(t, owner, 302)
  commits_action.sbs_collapse(ctx)
  diffview.await_rows(t, owner, 1)
  commits_action.sbs_expand(ctx)
  diffview.await_rows(t, owner, 302)
  commits_action.collapse_all(ctx)
  diffview.await_rows(t, owner, 1)
  commits_action.expand_all(ctx)
  diffview.await_rows(t, owner, 302)
  t.assert_eq(0, imports, "pure expansion never imports records")
  t.assert_true(source == owner.source, "the producer is retained across expansion")
end)

t:test("standalone file loading defers inline records until the first inline expansion", function()
  local ctx, owner = diffview.review_pane(t)
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
  t.await(stl.async.run_future(function()
    commits_action.__load_commit_files_and_render_filetree__(ctx, ctx.state:get_current_commit())
  end))
  treeview.await(owner:ready())
  t.assert_eq(1, owner:linecount(), "loading records preserves the collapsed commit")
  t.assert_eq(2, owner._data:source():len(), "the standalone pane does not prepare unused inline files")
  commits_action.expand(ctx)
  diffview.await_rows(t, owner, 3)
  t.assert_eq("src/loaded.lua", commits.get_item_at_line(ctx.layout.commits_bufnr, 3).entry.filepath)
end)

t:test("a failed first inline import stays collapsed and can be retried", function()
  local ctx, owner = diffview.review_pane(t, { { filepath = "src/one.lua", status = "M" } })
  local fail, import = true, owner._import
  t:patch_table(owner, "_import", function(self, ...)
    if fail then
      fail = false
      return stl.c.Future.reject("injected inline import failure")
    end
    return import(self, ...)
  end)
  t:patch_table(stl.reporter, "error", function() end)
  local succeeded = t.settle(stl.async.run_future(function()
    commits_action.__expand_commit__(ctx, ctx.state:get_current_commit())
  end))
  t.assert_false(succeeded)
  t.assert_false(ctx.state:is_commit_expanded("review"))
  t.assert_eq(1, owner:linecount())
  commits_action.sbs_expand(ctx)
  diffview.await_rows(t, owner, 3)
  t.assert_eq("src/one.lua", commits.get_item_at_line(ctx.layout.commits_bufnr, 3).entry.filepath)
end)

t:test("a hidden Commits pane can materialize and restore its logical expansion", function()
  local ctx, owner = diffview.review_pane(t, { { filepath = "src/hidden.lua", status = "M" } })
  vim.api.nvim_win_close(ctx.layout.commits_winnr, true)
  ctx.layout.commits_winnr, ctx.layout.commits_bufnr = nil, nil
  t.await(stl.async.run_future(function()
    commits_action.__expand_commit__(ctx, ctx.state:get_current_commit())
  end))
  t.assert_true(ctx.state:is_commit_expanded("review"))
  t.assert_true(owner:data("commit:review").files_loaded)
  local bufnr = commits.create_buffer()
  ctx.layout.commits_bufnr, ctx.layout.commits_winnr = bufnr, diffview.panel_window(t, bufnr)
  treeview.await(commits_view.render_commits(ctx))
  diffview.await_rows(t, owner, 3)
  t.assert_eq("src/hidden.lua", commits.get_item_at_line(bufnr, 3).entry.filepath)
end)

for _, all in ipairs({ false, true }) do
  t:test((all and "expand all" or "single expansion") .. " abandons an older content generation", function()
    local ctx, owner = diffview.review_pane(t)
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
    treeview.await(owner:ready())
    t.assert_eq(1, owner:linecount())
    t.assert_false(ctx.state:is_commit_expanded("review"))
    t.assert_false(owner:data("commit:review").files_loaded)
  end)
end

t:run()
