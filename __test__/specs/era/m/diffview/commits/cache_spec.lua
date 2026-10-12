---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.diffview.commits.cache" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.m.diffview.commits.cache")
local native = require("__test__.support.result_tree")
local Cache = require("era.m.diffview.view.commits.cache")
local State = require("era.m.diffview.view.commits.state").State
local view = require("era.m.diffview.view.commits.view")
local action = require("era.m.diffview.view.commits.action")
local pane = require("era.m.diffview.pane.commits")
local tree = require("era.m.diffview.pane.tree")

---@return table
---@return era.view.ResultTree
---@return era.m.diffview.ICommit[]
local function fixture()
  t:patch_table(dot.context.diffview.flag_panel_viewtype, "snapshot", function()
    return "tree"
  end)
  t:patch_table(dot.context.diffview.flag_foldempty, "snapshot", function()
    return false
  end)
  local commits = {}
  for _, hash in ipairs({ "a", "b", "current" }) do
    local files = {}
    if hash ~= "current" then
      for index = 1, 10050 do
        files[index] = { filepath = string.format("src/file%05d.lua", index), status = "M" }
      end
    end
    commits[#commits + 1] = { hash = hash, abbrev_hash = hash, author = "A", date = 0, message = hash, files = files }
  end
  local state = State.new(vim.api.nvim_get_current_tabpage(), false)
  local bufnr = pane.create_buffer()
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 60, height = 8 })
  t:defer(function()
    state:dispose()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  state:set_commits(commits)
  state:set_current_commit(commits[3])
  local ctx =
    { state = state, layout = { tabnr = state.tabnr, layout_type = 2, commits_bufnr = bufnr, commits_winnr = winnr } }
  native.await(view.render_commits(ctx))
  return ctx, state:get_tree("commits"), commits
end

---@param ctx                           table
---@param commit                        era.m.diffview.ICommit
---@return nil
local function expand(ctx, commit)
  local done, failure = false, nil
  stl.async.run(function()
    local ok, error = pcall(action.__expand_commit__, ctx, commit)
    failure, done = not ok and error or nil, true
  end)
  t.wait_until(function()
    return done
  end, 15000, "commit expansion did not finish")
  t.assert_nil(failure)
end

t:test("the cache bounds collapsed records, preserves folds and serializes new expansion with eviction", function()
  local ctx, owner, commits = fixture()
  local cache = ctx.state._materialization
  expand(ctx, commits[1])
  local directory = tree.key("commit:a", "src", true)
  owner:set_expansion(directory, false, false)
  native.await(owner:ready())
  ctx.state:collapse_commit("a")
  native.await(owner:ready())
  expand(ctx, commits[2])
  t.assert_true(owner:data("commit:a").files_loaded, "expanded content does not consume the collapsed cache budget")
  t.assert_true(owner:linecount() > 10050)
  ctx.state:collapse_commit("b")
  t.wait_until(function()
    return owner:data("commit:a").files_loaded == false and not cache._trimming
  end, 15000)
  t.assert_true(owner:data("commit:b").files_loaded)
  t.assert_eq(10055, owner._data:source():len(), "one file tree plus all commit headers remains")
  expand(ctx, commits[1])
  t.assert_false(owner:expanded(directory), "cold materialization restores directory folds")
  t.assert_true(ctx.state:is_commit_expanded("a"))

  local failed, original = false, owner._import
  local restore = t:patch_table(owner, "_import", function(self, snapshot)
    if not failed then
      failed = true
      return stl.c.Future.reject("injected trim failure")
    end
    return original(self, snapshot)
  end)
  t:patch_table(stl.reporter, "error", function() end)
  ctx.state:collapse_commit("a")
  t.wait_until(function()
    return failed and not cache._trimming
  end, 15000)
  t.assert_true(owner:data("commit:b").files_loaded, "failed trimming keeps the published source")
  t.assert_true(owner.source:get("commit:b").files_loaded, "failed trimming restores its producer")
  restore()
  expand(ctx, commits[2])
  t.assert_true(ctx.state:is_commit_expanded("b"), "an expansion recovers after failed eviction")

  local release
  restore = t:patch_table(owner, "_import", function(self, snapshot)
    local gate = stl.c.Future.new(function(resolve)
      release = resolve
    end)
    return gate:then_(function()
      return original(self, snapshot)
    end)
  end)
  ctx.state:collapse_commit("b")
  t.wait_until(function()
    return release ~= nil and cache._trimming ~= nil
  end, 15000)
  local done = false
  stl.async.run(function()
    action.__expand_commit__(ctx, commits[1])
    done = true
  end)
  t.assert_false(done, "a new expansion waits for the accepted eviction")
  t.assert_eq(1, cache._pending)
  restore()
  release(true)
  t.wait_until(function()
    return done
  end, 15000)
  t.assert_true(ctx.state:is_commit_expanded("a"))
  t.assert_true(owner:data("commit:a").files_loaded)
  t.assert_false(owner:expanded(directory))
  ctx.state:set_current_commit(commits[2])
  ctx.state:collapse_commit("a")
  native.await(owner:ready())
  t.wait_until(function()
    return not cache._scheduled and not cache._trimming
  end, 15000)
  t.assert_true(owner:data("commit:a").files_loaded)
  t.assert_true(owner:data("commit:b").files_loaded, "the current commit is protected even while collapsed")

  local prepared, prepare = false, owner.view._options.prepare_frame
  restore = t:patch_table(owner.view._options, "prepare_frame", function(...)
    if not prepared then
      prepared = true
      return stl.c.Future.reject("injected trim publication failure")
    end
    return prepare(...)
  end)
  ctx.state:set_current_commit(commits[2])
  ctx.state:set_current_commit(commits[3])
  t.wait_until(function()
    return prepared and not cache._trimming
  end, 15000)
  t.assert_nil(owner._data:source():id(directory), "native eviction completed before surface failure")
  restore()
  expand(ctx, commits[1])
  t.assert_false(owner:expanded(directory), "a failed publication still preserves the evicted directory checkpoint")
end)

t:test("disposing a cache prevents a queued ready callback from trimming", function()
  local ready, resolve = stl.c.Future.new_with_resolver()
  local requested, rendered = false, false
  local cache = Cache.new({})
  cache:bind({
    ready = function()
      requested = true
      return ready
    end,
  }, function()
    rendered = true
  end)
  cache:schedule()
  t.wait_until(function()
    return requested
  end, 1000)
  cache:dispose()
  resolve({ kind = "Applied" })
  t.assert_false(rendered)
end)

t:run()
