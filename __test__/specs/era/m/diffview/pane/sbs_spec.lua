require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local pane_sbs = require("era.m.diffview.pane.sbs")
local Future = stl.c.Future

t:test("matching refresh preserves view without resetting diff folds", function()
  local pane = pane_sbs
  local left_bufnr, right_bufnr = t:buffer(), t:buffer()
  local stale_left_bufnr, stale_right_bufnr = t:buffer(), t:buffer()
  local left_winnr, right_winnr = diffview.sbs_windows(t)
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
  t.wait_until(function()
    return #restored == 2
  end, 5000, "restored views")

  t.assert_eq(0, fold_resets, "diff folds retained")
  t.assert_eq(7, restored[1].lnum, "left view restored")
  t.assert_eq(9, restored[2].lnum, "right view restored")
end)

t:test("unchanged staged preview skips view capture and diff refresh", function()
  local pane = pane_sbs
  local left_winnr, right_winnr = diffview.sbs_windows(t)
  local applied_opts = nil ---@type era.m.diffview.pane.sbs.IApplyBuffersOpts|nil
  local view_captures = 0 ---@type integer
  local loads = 0 ---@type integer

  t:patch_table(vim.fn, "winsaveview", function()
    view_captures = view_captures + 1
    return {}
  end)
  local loader = {
    load = function()
      loads = loads + 1
      return true, false
    end,
  }
  t:patch_table(pane, "__apply_buffers__", function(_, _, _, _, opts)
    applied_opts = opts
  end)

  pane.open_diff_entry({
    left_winnr = left_winnr,
    right_winnr = right_winnr,
    entry = { filepath = "cached.txt", stage_type = "staged", status = "M" },
    loader = loader,
    preserve_view = true,
  })

  t.assert_eq(2, loads, "both immutable sides checked")
  t.assert_eq(0, view_captures, "unchanged content skips view capture")
  t.assert_false(assert(applied_opts).refresh_diff, "unchanged staged content skips diff refresh")
end)

t:test("changed staged or mutable unstaged preview retains diff refresh", function()
  diffview.workspace(t, t:tempdir())
  local pane = pane_sbs
  local left_winnr, right_winnr = diffview.sbs_windows(t)
  local applied = {} ---@type era.m.diffview.pane.sbs.IApplyBuffersOpts[]
  local view_captures = 0 ---@type integer
  local load_count = 0 ---@type integer
  local mutable_phase = false ---@type boolean

  t:patch_table(vim.fn, "winsaveview", function()
    view_captures = view_captures + 1
    return {}
  end)
  local loader = {
    load = function(_, _, _, opts)
      if mutable_phase then
        return true, false
      end
      load_count = load_count + 1
      local changed = load_count == 2
      if changed then
        opts.before_write()
      end
      return true, changed
    end,
  }
  t:patch_table(pane, "__apply_buffers__", function(_, _, _, _, opts)
    applied[#applied + 1] = opts
  end)

  pane.open_diff_entry({
    left_winnr = left_winnr,
    right_winnr = right_winnr,
    entry = { filepath = "changed.txt", stage_type = "staged", status = "M" },
    loader = loader,
    preserve_view = true,
  })
  t.assert_true(applied[1].refresh_diff, "changed staged side refreshes diff")
  t.assert_eq(2, view_captures, "changed staged content captures both views")

  view_captures = 0
  mutable_phase = true
  pane.open_diff_entry({
    left_winnr = left_winnr,
    right_winnr = right_winnr,
    entry = { filepath = "changed.txt", stage_type = "unstaged", status = "M" },
    loader = loader,
    preserve_view = true,
  })
  t.assert_true(applied[2].refresh_diff, "mutable working-tree side refreshes diff")
  t.assert_eq(2, view_captures, "mutable preview captures both views")
end)

t:test("unchanged matching buffers skip scheduled diff work only while identity matches", function()
  local pane = pane_sbs
  local left_bufnr, right_bufnr = t:buffer(), t:buffer()
  local replacement_left_bufnr, replacement_right_bufnr = t:buffer(), t:buffer()
  local left_winnr, right_winnr = diffview.sbs_windows(t)
  local schedules = 0 ---@type integer
  vim.api.nvim_win_set_buf(left_winnr, left_bufnr)
  vim.api.nvim_win_set_buf(right_winnr, right_bufnr)
  t:patch_table(vim, "schedule", function()
    schedules = schedules + 1
  end)

  pane.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr, {
    preserve_view = true,
    refresh_diff = false,
  })

  t.assert_eq(0, schedules, "cache hit schedules no diff refresh")
  t.assert_eq(left_bufnr, vim.api.nvim_win_get_buf(left_winnr), "left buffer retained")
  t.assert_eq(right_bufnr, vim.api.nvim_win_get_buf(right_winnr), "right buffer retained")

  pane.__apply_buffers__(left_winnr, right_winnr, replacement_left_bufnr, replacement_right_bufnr, {
    preserve_view = true,
    refresh_diff = false,
  })
  t.assert_eq(1, schedules, "buffer mismatch retains scheduled setup")
  t.assert_eq(replacement_left_bufnr, vim.api.nvim_win_get_buf(left_winnr), "left replacement applied")
  t.assert_eq(replacement_right_bufnr, vim.api.nvim_win_get_buf(right_winnr), "right replacement applied")
end)

t:test("workspace preview routes status snapshot identities for every file shape", function()
  local pane = pane_sbs
  local calls = {} ---@type { object: string, object_name: string|nil }[]
  local next_bufnr = 0
  t:patch_table(pane, "create_sbs_buffer", function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end)
  t:patch_table(pane, "get_null_buffer", function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end)
  t:patch_table(pane, "find_or_create_local_buffer", function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end)
  local loader = {
    load = function(_, object, _, opts)
      calls[#calls + 1] = { object = object, object_name = opts.object_name }
      return true
    end,
  }
  t:patch_table(pane, "__apply_buffers__", function() end)

  ---@param entry                      era.m.diffview.IFileEntry
  ---@return { object: string, object_name: string|nil }[]
  local function open(entry)
    calls = {}
    pane.open_diff_entry({ left_winnr = -1, right_winnr = -1, entry = entry, loader = loader })
    return calls
  end

  local modified = open({
    filepath = "modified.lua",
    stage_type = "staged",
    status = "M",
    old_object_name = "head-modified",
    new_object_name = "index-modified",
  })
  t.assert_eq("head-modified", modified[1].object_name, "staged modify source identity")
  t.assert_eq("index-modified", modified[2].object_name, "staged modify target identity")

  local worktree_modified = open({
    filepath = "modified.lua",
    stage_type = "unstaged",
    status = "M",
    old_object_name = "index-before-worktree",
  })
  t.assert_eq(1, #worktree_modified, "unstaged modify loads only its index source")
  t.assert_eq("index-before-worktree", worktree_modified[1].object_name, "unstaged modify source identity")

  local added = open({
    filepath = "added.lua",
    stage_type = "staged",
    status = "A",
    new_object_name = "index-added",
  })
  t.assert_eq(1, #added, "staged add loads only its target")
  t.assert_eq("index-added", added[1].object_name, "staged add target identity")

  local deleted = open({
    filepath = "deleted.lua",
    stage_type = "staged",
    status = "D",
    old_object_name = "head-deleted",
  })
  t.assert_eq(1, #deleted, "staged delete loads only its source")
  t.assert_eq("head-deleted", deleted[1].object_name, "staged delete source identity")

  local copied = open({
    filepath = "copied.lua",
    prev_filepath = "original.lua",
    stage_type = "staged",
    status = "C",
    old_object_name = "head-original",
    new_object_name = "index-copy",
  })
  t.assert_eq("HEAD:original.lua", copied[1].object, "staged copy source selector")
  t.assert_eq("head-original", copied[1].object_name, "staged copy source identity")
  t.assert_eq("index-copy", copied[2].object_name, "staged copy target identity")

  local renamed = open({
    filepath = "new.lua",
    prev_filepath = "index.lua",
    stage_type = "unstaged",
    status = "R",
    old_object_name = "index-source",
  })
  t.assert_eq(1, #renamed, "unstaged rename loads only its index source")
  t.assert_eq(":./index.lua", renamed[1].object, "unstaged rename source selector")
  t.assert_eq("index-source", renamed[1].object_name, "unstaged rename source identity")
end)

t:test("staged preview starts both immutable loads before publishing", function()
  local pane = pane_sbs
  local left_gate, release_left = Future.new_with_resolver()
  local started = {} ---@type string[]
  local applied = 0 ---@type integer
  local next_bufnr = 0 ---@type integer
  t:patch_table(pane, "create_sbs_buffer", function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end)
  local loader = {
    load = function(_, object)
      started[#started + 1] = object
      if object == "HEAD:f.txt" then
        left_gate:await()
      end
      return true, true
    end,
  }
  t:patch_table(pane, "__apply_buffers__", function()
    applied = applied + 1
  end)

  stl.async.run(function()
    pane.open_diff_entry({
      left_winnr = -1,
      right_winnr = -1,
      entry = { filepath = "f.txt", stage_type = "staged", status = "M" },
      loader = loader,
    })
  end)

  t.assert_eq(2, #started, "right load starts while left remains pending")
  t.assert_eq("HEAD:f.txt", started[1], "left source")
  t.assert_eq(":./f.txt", started[2], "right source")
  t.assert_eq(0, applied, "pair is not published while one side is pending")

  release_left(true)
  t.wait_until(function()
    return applied == 1
  end, 5000, "the published pair")
end)

t:test("stale staged pair cannot publish after both loads settle", function()
  local pane = pane_sbs
  local left_gate, release_left = Future.new_with_resolver()
  local right_gate, release_right = Future.new_with_resolver()
  local current = true ---@type boolean
  local applied = 0 ---@type integer
  local next_bufnr = 0 ---@type integer
  t:patch_table(pane, "create_sbs_buffer", function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end)
  local loader = {
    load = function(_, object)
      if object == "HEAD:f.txt" then
        left_gate:await()
      else
        right_gate:await()
      end
      return true, true
    end,
  }
  t:patch_table(pane, "__apply_buffers__", function()
    applied = applied + 1
  end)

  local preview = stl.async.run_future(function()
    pane.open_diff_entry({
      left_winnr = -1,
      right_winnr = -1,
      entry = { filepath = "f.txt", stage_type = "staged", status = "M" },
      loader = loader,
      is_current = function()
        return current
      end,
    })
  end)

  current = false
  release_left(true)
  release_right(true)
  t.await(preview)
  t.assert_eq(0, applied, "stale pair rejected at the publish barrier")
end)

t:test("staged pair drains its sibling before propagating a load exception", function()
  local pane = pane_sbs
  local right_gate, release_right = Future.new_with_resolver()
  local applied = 0 ---@type integer
  local next_bufnr = 0 ---@type integer
  t:patch_table(pane, "create_sbs_buffer", function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end)
  local loader = {
    load = function(_, object)
      if object == "HEAD:f.txt" then
        error("left load failed")
      end
      right_gate:await()
      return true, true
    end,
  }
  t:patch_table(pane, "__apply_buffers__", function()
    applied = applied + 1
  end)

  local preview = stl.async.run_future(function()
    pane.open_diff_entry({
      left_winnr = -1,
      right_winnr = -1,
      entry = { filepath = "f.txt", stage_type = "staged", status = "M" },
      loader = loader,
    })
  end)

  t.assert_false(preview:is_done(), "parent waits for the still-running sibling")
  release_right(true)
  local ok, err = t.settle(preview)
  t.assert_false(ok, "load exception propagated")
  t.assert_true(tostring(err):find("left load failed", 1, true) ~= nil, "original exception retained")
  t.assert_eq(0, applied, "failed pair never published")
end)

t:test("real staged preview reuses captured identities without resolver processes", function()
  local repo = diffview.committed(t, { ["f.txt"] = { "base" } })
  fs.write(repo .. "/f.txt", { "staged" })
  git.run(repo, { "add", "--", "f.txt" })

  local head_object = vim.trim(git.run(repo, { "rev-parse", "HEAD:f.txt" })) ---@type string
  local index_object = vim.trim(git.run(repo, { "rev-parse", ":f.txt" })) ---@type string
  local resolution_calls = 0 ---@type integer
  local blob_calls = 0 ---@type integer
  local active_blob_calls = 0 ---@type integer
  local max_active_blob_calls = 0 ---@type integer
  local production_info = assert(loadfile("lua/stl/git/info.lua"))()
  local get_object_name = production_info.get_object_name
  local get_file_info = production_info.get_file_info
  local get_show_blob = production_info.get_show_blob
  production_info.get_object_name = function(...)
    resolution_calls = resolution_calls + 1
    return get_object_name(...)
  end
  production_info.get_file_info = function(...)
    resolution_calls = resolution_calls + 1
    return get_file_info(...)
  end
  production_info.get_show_blob = function(...)
    blob_calls = blob_calls + 1
    active_blob_calls = active_blob_calls + 1
    max_active_blob_calls = math.max(max_active_blob_calls, active_blob_calls)
    local future = get_show_blob(...)
    future:finally(function()
      active_blob_calls = active_blob_calls - 1
    end)
    return future
  end

  local loader = require("era.m.diffview.content").Loader.new(production_info)

  local pane = pane_sbs
  local left_winnr, right_winnr = diffview.sbs_windows(t)
  ---@type era.m.diffview.IFileEntry
  local entry = {
    filepath = "f.txt",
    stage_type = "staged",
    status = "M",
    old_object_name = head_object,
    new_object_name = index_object,
  }
  local function open_preview()
    t.await(stl.async.run_future(function()
      pane.open_diff_entry({
        left_winnr = left_winnr,
        right_winnr = right_winnr,
        entry = entry,
        loader = loader,
        preserve_view = true,
      })
    end))
  end

  open_preview()
  open_preview()

  local left_bufnr = vim.api.nvim_win_get_buf(left_winnr) ---@type integer
  local right_bufnr = vim.api.nvim_win_get_buf(right_winnr) ---@type integer
  t:defer(function()
    for _, bufnr in ipairs({ left_bufnr, right_bufnr, vim.fn.bufnr(repo .. "/f.txt") }) do
      if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  t.assert_eq(0, resolution_calls, "captured identities eliminate resolver processes")
  t.assert_eq(2, blob_calls, "second preview reuses both immutable buffers")
  t.assert_eq(2, max_active_blob_calls, "cold staged blobs load concurrently")
  t.assert_eq("base", vim.api.nvim_buf_get_lines(left_bufnr, 0, 1, false)[1], "HEAD snapshot")
  t.assert_eq("staged", vim.api.nvim_buf_get_lines(right_bufnr, 0, 1, false)[1], "index snapshot")
end)

t:test("parallel preview does not publish buffers after either Git content load fails", function()
  local pane = pane_sbs
  local objects = {} ---@type string[]
  local applied = 0
  local next_bufnr = 0
  t:patch_table(pane, "create_sbs_buffer", function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end)
  local loader = {
    load = function(_, object)
      objects[#objects + 1] = object
      return false
    end,
  }
  t:patch_table(pane, "__apply_buffers__", function()
    applied = applied + 1
  end)

  pane.open_diff_entry({
    left_winnr = -1,
    right_winnr = -1,
    entry = { filepath = "new.lua", prev_filepath = "old.lua", stage_type = "staged", status = "R" },
    loader = loader,
  })

  t.assert_eq(2, #objects, "both immutable loads start concurrently")
  t.assert_eq("HEAD:old.lua", objects[1], "failed source")
  t.assert_eq(":./new.lua", objects[2], "parallel destination")
  t.assert_eq(0, applied, "buffers not published")
end)

t:test("conflict preview compares ours with the working tree", function()
  local repo = git.repo(t, { "-b", "main" })
  fs.write(repo .. "/f.txt", { "base" })
  git.commit(repo, "base")
  git.run(repo, { "branch", "theirs" })
  fs.write(repo .. "/f.txt", { "ours" })
  git.commit(repo, "ours")
  git.run(repo, { "checkout", "-q", "theirs" })
  fs.write(repo .. "/f.txt", { "theirs" })
  git.commit(repo, "theirs")
  git.run(repo, { "checkout", "-q", "main" })
  t.assert_eq(1, git.system(repo, { "merge", "theirs" }).code, "merge conflict")

  repo = diffview.workspace(t, repo)
  local loader = require("era.m.diffview.content").Loader.new(require("stl.git.info"))

  local pane = pane_sbs
  local applied = nil ---@type integer[]|nil
  t:patch_table(pane, "__apply_buffers__", function(_, _, left_bufnr, right_bufnr)
    applied = { left_bufnr, right_bufnr }
  end)

  t.await(stl.async.run_future(function()
    pane.open_diff_entry({
      left_winnr = -1,
      right_winnr = -1,
      entry = { filepath = "f.txt", stage_type = "unstaged", status = "U" },
      loader = loader,
    })
  end))

  local buffers = assert(applied, "conflict preview applied")
  t:defer(function()
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)
  t.assert_eq("ours", vim.api.nvim_buf_get_lines(buffers[1], 0, 1, false)[1], "stage two on left")
  local working = table.concat(vim.api.nvim_buf_get_lines(buffers[2], 0, -1, false), "\n")
  t.assert_true(working:find("<<<<<<< HEAD", 1, true) ~= nil, "working conflict markers on right")
end)

---@param winnr                         integer
---@param command                       string
local function normal(winnr, command)
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("normal! " .. command)
  end)
end

---@param winnr                         integer
---@return boolean
local function is_fold_closed(winnr)
  return vim.api.nvim_win_call(winnr, function()
    return vim.fn.foldclosed(1) ~= -1
  end)
end

---Folds lines 1 to 3 of window `winnr` by hand.
---@param winnr                         integer
---@return nil
local function fold(winnr)
  vim.api.nvim_set_option_value("foldenable", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr, scope = "local" })
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("1,3fold")
  end)
end

---Runs the scheduled fold commands and the work they schedule in turn.
---@return nil
local function wait_for_scheduled()
  t.drain()
  t.drain()
end

t:test("side-by-side fold policy is deterministic and preserves panel focus", function()
  local panel_winnr = vim.api.nvim_get_current_win() ---@type integer
  local lines = { "one", "two", "three", "four", "five" }
  t:buffer(lines, { current = true })
  local left_winnr, right_winnr = diffview.sbs_windows(t, lines)
  for _, winnr in ipairs({ panel_winnr, left_winnr, right_winnr }) do
    fold(winnr)
  end
  normal(panel_winnr, "zR")

  normal(left_winnr, "zM")
  normal(right_winnr, "zM")
  vim.api.nvim_set_current_win(panel_winnr)
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, false)
  t.wait_until(function()
    return not is_fold_closed(left_winnr) and not is_fold_closed(right_winnr)
  end, 5000, "expanded diff folds")
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after expand")

  normal(right_winnr, "zM")
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, false)
  t.wait_until(function()
    return not is_fold_closed(left_winnr) and not is_fold_closed(right_winnr)
  end, 5000, "reapplied expanded diff folds")

  normal(left_winnr, "zR")
  normal(right_winnr, "zM")
  pane_sbs.apply_fold_unchanged_pair(left_winnr, right_winnr, true)
  t.wait_until(function()
    return is_fold_closed(left_winnr) and is_fold_closed(right_winnr)
  end, 5000, "collapsed diff folds")
  wait_for_scheduled()
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after collapse")
  t.assert_false(is_fold_closed(panel_winnr), "panel folds unchanged")

  local fold_unchanged = true
  local left_bufnr, right_bufnr = vim.api.nvim_win_get_buf(left_winnr), vim.api.nvim_win_get_buf(right_winnr)
  pane_sbs.__apply_buffers__(left_winnr, right_winnr, left_bufnr, right_bufnr, {
    get_fold_unchanged = function()
      return fold_unchanged
    end,
  })
  fold_unchanged = false
  t.wait_until(function()
    return not is_fold_closed(left_winnr) and not is_fold_closed(right_winnr)
  end, 5000, "latest fold policy applied")
  wait_for_scheduled()
end)

t:run()
