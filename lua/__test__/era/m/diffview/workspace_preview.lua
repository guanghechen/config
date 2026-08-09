---@diagnostic disable: undefined-global
-- cspell:ignore unchanges worktree
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_preview.lua

local bootstrap = require("__test__.bootstrap")
local Future = require("stl.c.future")
local harness = require("__test__.harness")
local staging = require("era.m.git.staging")

local t = harness.new("era.m.diffview.workspace_preview")

bootstrap.with_global(t, "stl", {
  async = require("stl.async"),
  c = { Future = Future },
  e = { TabTypeEnum = { DIFFVIEW_COMMITS = 1, DIFFVIEW_WORKSPACE = 2 } },
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
  context = {
    diffview = {
      flag_fold_unchanges = {
        snapshot = function()
          return false
        end,
      },
    },
  },
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
    workspace = function()
      return "/repo"
    end,
  },
})
bootstrap.with_global(t, "era", {
  m = {
    diffview = {
      util = {
        gen_index_bufname = function(filepath)
          return "index:" .. filepath
        end,
        gen_old_bufname = function(filepath, ref)
          return ref .. ":" .. filepath
        end,
        head_object = function(filepath)
          return "HEAD:" .. filepath
        end,
        index_stage_object = function(filepath, stage)
          return string.format(":%d:%s", stage, filepath)
        end,
        staged_object = function(filepath)
          return ":./" .. filepath
        end,
      },
    },
    git = { staging = staging },
  },
})

local production_util = assert(loadfile("lua/era/m/diffview/util.lua"))()

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
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return "/repo/" .. filepath
  end,
})

---@param predicate                     fun(): boolean
local function wait(predicate)
  t.wait_until(predicate, 5000, "async preview operation")
end

---@param repo                          string
---@param ...                           string
---@return vim.SystemCompleted
local function git(repo, ...)
  return vim.system({ "git", "-C", repo, ... }, { text = true }):wait()
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
  local disposed = false
  local ctx = {
    layout = {
      tabnr = vim.api.nvim_get_current_tabpage(),
      layout_type = 1,
      sbs_left_winnr = left_winnr,
      sbs_right_winnr = right_winnr,
      preview_generation = 0,
    },
    state = {
      is_disposed = function()
        return disposed
      end,
    },
  }

  view.open_entry(ctx, { filepath = "a.lua", stage_type = "staged", status = "M" }, nil, {
    preserve_view = true,
  })
  view.open_entry(ctx, { filepath = "b.lua", stage_type = "staged", status = "M" })

  t.assert_false(requests[1].is_current(), "older request invalidated")
  t.assert_true(requests[2].is_current(), "latest request current")
  t.assert_true(requests[1].preserve_view, "preserve option forwarded")

  disposed = true
  t.assert_false(requests[2].is_current(), "disposed workspace invalidates preview")
  disposed = false

  view.clear_sbs(ctx)
  t.assert_false(requests[2].is_current(), "clear invalidates open request")
  t.assert_true(assert(clear_is_current)(), "clear owns latest generation")
  close_windows(left_winnr, right_winnr)
end)

t:test("stale async load cannot overwrite a shared preview buffer", function()
  t:patch_table(stl.git.info, "get_object_name", function()
    return Future.resolve({ ok = true, missing = false, object_name = "head-object" })
  end)
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

t:test("unchanged staged preview skips view capture and diff refresh", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local left_winnr, right_winnr = create_windows()
  local applied_opts = nil ---@type era.m.diffview.pane.sbs.IApplyBuffersOpts|nil
  local view_captures = 0 ---@type integer
  local loads = 0 ---@type integer

  t:patch_table(stl.nvim.buf, "locate_bufnr", function(name)
    local bufnr = vim.fn.bufnr(name) ---@type integer
    return bufnr ~= -1 and bufnr or nil
  end)
  t:patch_table(vim.fn, "winsaveview", function()
    view_captures = view_captures + 1
    return {}
  end)
  pane.load_git_content = function()
    loads = loads + 1
    return true, false
  end
  pane.__apply_buffers__ = function(_, _, _, _, opts)
    applied_opts = opts
  end

  pane.open_diff_entry({
    left_winnr = left_winnr,
    right_winnr = right_winnr,
    entry = { filepath = "cached.txt", stage_type = "staged", status = "M" },
    preserve_view = true,
  })

  t.assert_eq(2, loads, "both immutable sides checked")
  t.assert_eq(0, view_captures, "unchanged content skips view capture")
  t.assert_false(assert(applied_opts).refresh_diff, "unchanged staged content skips diff refresh")
  close_windows(left_winnr, right_winnr)
end)

t:test("changed staged or mutable unstaged preview retains diff refresh", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local left_winnr, right_winnr = create_windows()
  local applied = {} ---@type era.m.diffview.pane.sbs.IApplyBuffersOpts[]
  local view_captures = 0 ---@type integer
  local load_count = 0 ---@type integer
  local mutable_phase = false ---@type boolean

  t:patch_table(stl.nvim.buf, "locate_bufnr", function(name)
    local bufnr = vim.fn.bufnr(name) ---@type integer
    return bufnr ~= -1 and bufnr or nil
  end)
  t:patch_table(vim.fn, "winsaveview", function()
    view_captures = view_captures + 1
    return {}
  end)
  pane.load_git_content = function(_, _, _, _, before_write)
    if mutable_phase then
      return true, false
    end
    load_count = load_count + 1
    local changed = load_count == 2
    if changed then
      before_write()
    end
    return true, changed
  end
  pane.__apply_buffers__ = function(_, _, _, _, opts)
    applied[#applied + 1] = opts
  end

  pane.open_diff_entry({
    left_winnr = left_winnr,
    right_winnr = right_winnr,
    entry = { filepath = "changed.txt", stage_type = "staged", status = "M" },
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
    preserve_view = true,
  })
  t.assert_true(applied[2].refresh_diff, "mutable working-tree side refreshes diff")
  t.assert_eq(2, view_captures, "mutable preview captures both views")
  close_windows(left_winnr, right_winnr)
end)

t:test("unchanged matching buffers skip scheduled diff work only while identity matches", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local left_winnr, right_winnr = create_windows()
  local left_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local right_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
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

  local replacement_left_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local replacement_right_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  pane.__apply_buffers__(left_winnr, right_winnr, replacement_left_bufnr, replacement_right_bufnr, {
    preserve_view = true,
    refresh_diff = false,
  })
  t.assert_eq(1, schedules, "buffer mismatch retains scheduled setup")
  t.assert_eq(replacement_left_bufnr, vim.api.nvim_win_get_buf(left_winnr), "left replacement applied")
  t.assert_eq(replacement_right_bufnr, vim.api.nvim_win_get_buf(right_winnr), "right replacement applied")

  close_windows(left_winnr, right_winnr)
  for _, bufnr in ipairs({ left_bufnr, right_bufnr, replacement_left_bufnr, replacement_right_bufnr }) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end)

t:test("workspace preview routes status snapshot identities for every file shape", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local calls = {} ---@type { object: string, object_name: string|nil }[]
  local next_bufnr = 0
  pane.create_sbs_buffer = function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end
  pane.get_null_buffer = function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end
  pane.find_or_create_local_buffer = function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end
  pane.load_git_content = function(object, _, _, _, _, object_name)
    calls[#calls + 1] = { object = object, object_name = object_name }
    return true
  end
  pane.__apply_buffers__ = function() end

  ---@param entry                      era.m.diffview.IFileEntry
  ---@return { object: string, object_name: string|nil }[]
  local function open(entry)
    calls = {}
    pane.open_diff_entry({ left_winnr = -1, right_winnr = -1, entry = entry })
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
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local left_gate, release_left = Future.new_with_resolver()
  local started = {} ---@type string[]
  local applied = 0 ---@type integer
  local next_bufnr = 0 ---@type integer
  pane.create_sbs_buffer = function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end
  pane.load_git_content = function(object)
    started[#started + 1] = object
    if object == "HEAD:f.txt" then
      left_gate:await()
    end
    return true, true
  end
  pane.__apply_buffers__ = function()
    applied = applied + 1
  end

  stl.async.run(function()
    pane.open_diff_entry({
      left_winnr = -1,
      right_winnr = -1,
      entry = { filepath = "f.txt", stage_type = "staged", status = "M" },
    })
  end)

  t.assert_eq(2, #started, "right load starts while left remains pending")
  t.assert_eq("HEAD:f.txt", started[1], "left source")
  t.assert_eq(":./f.txt", started[2], "right source")
  t.assert_eq(0, applied, "pair is not published while one side is pending")

  release_left(true)
  wait(function()
    return applied == 1
  end)
end)

t:test("stale staged pair cannot publish after both loads settle", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local left_gate, release_left = Future.new_with_resolver()
  local right_gate, release_right = Future.new_with_resolver()
  local current = true ---@type boolean
  local done = false ---@type boolean
  local applied = 0 ---@type integer
  local next_bufnr = 0 ---@type integer
  pane.create_sbs_buffer = function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end
  pane.load_git_content = function(object)
    if object == "HEAD:f.txt" then
      left_gate:await()
    else
      right_gate:await()
    end
    return true, true
  end
  pane.__apply_buffers__ = function()
    applied = applied + 1
  end

  stl.async.run(function()
    pane.open_diff_entry({
      left_winnr = -1,
      right_winnr = -1,
      entry = { filepath = "f.txt", stage_type = "staged", status = "M" },
      is_current = function()
        return current
      end,
    })
    done = true
  end)

  current = false
  release_left(true)
  release_right(true)
  wait(function()
    return done
  end)
  t.assert_eq(0, applied, "stale pair rejected at the publish barrier")
end)

t:test("staged pair drains its sibling before propagating a load exception", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local right_gate, release_right = Future.new_with_resolver()
  local outcome = nil ---@type { ok: boolean, err: string }|nil
  local applied = 0 ---@type integer
  local next_bufnr = 0 ---@type integer
  pane.create_sbs_buffer = function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end
  pane.load_git_content = function(object)
    if object == "HEAD:f.txt" then
      error("left load failed")
    end
    right_gate:await()
    return true, true
  end
  pane.__apply_buffers__ = function()
    applied = applied + 1
  end

  stl.async.run(function()
    local ok, err = xpcall(function()
      pane.open_diff_entry({
        left_winnr = -1,
        right_winnr = -1,
        entry = { filepath = "f.txt", stage_type = "staged", status = "M" },
      })
    end, debug.traceback)
    outcome = { ok = ok, err = tostring(err) }
  end)

  t.assert_nil(outcome, "parent waits for the still-running sibling")
  release_right(true)
  wait(function()
    return outcome ~= nil
  end)
  t.assert_false(assert(outcome).ok, "load exception propagated")
  t.assert_true(assert(outcome).err:find("left load failed", 1, true) ~= nil, "original exception retained")
  t.assert_eq(0, applied, "failed pair never published")
end)

t:test("index preview disambiguates a digit-colon filename from an unmerged stage", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "digit-colon" }, repo .. "/2:foo")
    vim.fn.writefile({ "plain" }, repo .. "/foo")
    t.assert_eq(0, git(repo, "add", "--all").code, "git add")

    t:patch_table(dot.path, "workspace", function()
      return repo
    end)
    t:patch_table(stl.git, "info", assert(loadfile("lua/stl/git/info.lua"))())

    local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
    local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
    local selector = production_util.staged_object("2:foo") ---@type string
    local outcome = nil ---@type boolean|nil
    stl.async.run(function()
      outcome = pane.load_git_content(selector, bufnr)
    end)
    wait(function()
      return outcome ~= nil
    end)

    local expected_object = vim.trim(git(repo, "rev-parse", ":./2:foo").stdout or "") ---@type string
    t.assert_eq(":./2:foo", selector, "explicit stage-zero selector")
    t.assert_true(outcome, "index preview loaded")
    t.assert_eq("digit-colon", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "exact index content")
    t.assert_eq(expected_object, vim.b[bufnr].git_object_name, "authoritative index object")
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("revision preview caches real blobs and observes HEAD changes", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "base" }, repo .. "/f.txt")
    t.assert_eq(0, git(repo, "add", "--", "f.txt").code, "git add")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "commit base"
    )
    local base_hash = vim.trim(git(repo, "rev-parse", "HEAD").stdout or "") ---@type string

    t:patch_table(dot.path, "workspace", function()
      return repo
    end)
    local production_info = assert(loadfile("lua/stl/git/info.lua"))()
    local get_show_blob = production_info.get_show_blob
    local blob_calls = 0 ---@type integer
    production_info.get_show_blob = function(...)
      blob_calls = blob_calls + 1
      return get_show_blob(...)
    end
    t:patch_table(stl.git, "info", production_info)

    local writes = 0 ---@type integer
    local replace_buffer_text = staging.replace_buffer_text
    t:patch_table(staging, "replace_buffer_text", function(...)
      writes = writes + 1
      return replace_buffer_text(...)
    end)

    local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
    local head_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
    local commit_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
    local function load(object, bufnr)
      local outcome = nil ---@type boolean|nil
      stl.async.run(function()
        outcome = pane.load_git_content(object, bufnr)
      end)
      wait(function()
        return outcome ~= nil
      end)
      return outcome
    end

    t.assert_true(load("HEAD:f.txt", head_bufnr), "initial HEAD load")
    t.assert_true(load("HEAD:f.txt", head_bufnr), "cached HEAD load")
    t.assert_eq(1, blob_calls, "cached HEAD skips blob read")
    t.assert_eq(1, writes, "cached HEAD skips buffer write")

    vim.fn.writefile({ "next" }, repo .. "/f.txt")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qam", "next").code,
      "commit next"
    )
    t.assert_true(load("HEAD:f.txt", head_bufnr), "changed HEAD load")
    t.assert_eq(2, blob_calls, "changed HEAD reads blob")
    t.assert_eq(2, writes, "changed HEAD rewrites buffer")
    t.assert_eq("next\n", staging.from_buffer(head_bufnr).text, "latest HEAD content")

    local commit_object = base_hash .. ":f.txt" ---@type string
    t.assert_true(load(commit_object, commit_bufnr), "initial commit load")
    t.assert_true(load(commit_object, commit_bufnr), "cached commit load")
    t.assert_eq(3, blob_calls, "cached commit skips blob read")
    t.assert_eq(3, writes, "cached commit skips buffer write")
    t.assert_eq("base\n", staging.from_buffer(commit_bufnr).text, "commit content")
    t.assert_eq(
      vim.trim(git(repo, "rev-parse", commit_object).stdout or ""),
      vim.b[commit_bufnr].git_content_object_name,
      "commit blob identity"
    )

    vim.api.nvim_buf_delete(head_bufnr, { force = true })
    vim.api.nvim_buf_delete(commit_bufnr, { force = true })
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("real staged preview reuses captured identities without resolver processes", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "base" }, repo .. "/f.txt")
    t.assert_eq(0, git(repo, "add", "--", "f.txt").code, "add base")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "commit base"
    )
    vim.fn.writefile({ "staged" }, repo .. "/f.txt")
    t.assert_eq(0, git(repo, "add", "--", "f.txt").code, "add staged change")

    local head_object = vim.trim(git(repo, "rev-parse", "HEAD:f.txt").stdout or "") ---@type string
    local index_object = vim.trim(git(repo, "rev-parse", ":f.txt").stdout or "") ---@type string
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

    t:patch_table(dot.path, "workspace", function()
      return repo
    end)
    t:patch_table(package.loaded["era.m.diffview.util"], "workspace_path", function(filepath)
      return repo .. "/" .. filepath
    end)
    t:patch_table(stl.nvim.buf, "locate_bufnr", function(name)
      local bufnr = vim.fn.bufnr(name) ---@type integer
      return bufnr ~= -1 and bufnr or nil
    end)
    t:patch_table(stl.git, "info", production_info)

    local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
    local left_winnr, right_winnr = create_windows()
    ---@type era.m.diffview.IFileEntry
    local entry = {
      filepath = "f.txt",
      stage_type = "staged",
      status = "M",
      old_object_name = head_object,
      new_object_name = index_object,
    }
    local function open_preview()
      local done = false ---@type boolean
      stl.async.run(function()
        pane.open_diff_entry({
          left_winnr = left_winnr,
          right_winnr = right_winnr,
          entry = entry,
          preserve_view = true,
        })
        done = true
      end)
      wait(function()
        return done
      end)
    end

    open_preview()
    open_preview()

    local left_bufnr = vim.api.nvim_win_get_buf(left_winnr) ---@type integer
    local right_bufnr = vim.api.nvim_win_get_buf(right_winnr) ---@type integer
    t.assert_eq(0, resolution_calls, "captured identities eliminate resolver processes")
    t.assert_eq(2, blob_calls, "second preview reuses both immutable buffers")
    t.assert_eq(2, max_active_blob_calls, "cold staged blobs load concurrently")
    t.assert_eq("base", vim.api.nvim_buf_get_lines(left_bufnr, 0, 1, false)[1], "HEAD snapshot")
    t.assert_eq("staged", vim.api.nvim_buf_get_lines(right_bufnr, 0, 1, false)[1], "index snapshot")

    close_windows(left_winnr, right_winnr)
    for _, bufnr in ipairs({ left_bufnr, right_bufnr, vim.fn.bufnr(repo .. "/f.txt") }) do
      if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:test("parallel preview does not publish buffers after either Git content load fails", function()
  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local objects = {} ---@type string[]
  local applied = 0
  local next_bufnr = 0
  pane.create_sbs_buffer = function()
    next_bufnr = next_bufnr + 1
    return next_bufnr
  end
  pane.load_git_content = function(object)
    objects[#objects + 1] = object
    return false
  end
  pane.__apply_buffers__ = function()
    applied = applied + 1
  end

  pane.open_diff_entry({
    left_winnr = -1,
    right_winnr = -1,
    entry = { filepath = "new.lua", prev_filepath = "old.lua", stage_type = "staged", status = "R" },
  })

  t.assert_eq(2, #objects, "both immutable loads start concurrently")
  t.assert_eq("HEAD:old.lua", objects[1], "failed source")
  t.assert_eq(":./new.lua", objects[2], "parallel destination")
  t.assert_eq(0, applied, "buffers not published")
end)

t:test("conflict preview compares ours with the working tree", function()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q", "-b", "main").code, "git init")
    vim.fn.writefile({ "base" }, repo .. "/f.txt")
    t.assert_eq(0, git(repo, "add", "--", "f.txt").code, "add base")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "commit base"
    )
    t.assert_eq(0, git(repo, "branch", "theirs").code, "create branch")
    vim.fn.writefile({ "ours" }, repo .. "/f.txt")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-am", "ours", "-q").code,
      "commit ours"
    )
    t.assert_eq(0, git(repo, "checkout", "-q", "theirs").code, "checkout theirs")
    vim.fn.writefile({ "theirs" }, repo .. "/f.txt")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-am", "theirs", "-q").code,
      "commit theirs"
    )
    t.assert_eq(0, git(repo, "checkout", "-q", "main").code, "checkout main")
    t.assert_eq(
      1,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "merge", "theirs").code,
      "merge conflict"
    )

    t:patch_table(dot.path, "workspace", function()
      return repo
    end)
    t:patch_table(package.loaded["era.m.diffview.util"], "workspace_path", function(filepath)
      return repo .. "/" .. filepath
    end)
    t:patch_table(stl.git, "info", require("stl.git.info"))

    local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
    local applied = nil ---@type integer[]|nil
    pane.__apply_buffers__ = function(_, _, left_bufnr, right_bufnr)
      applied = { left_bufnr, right_bufnr }
    end

    local done = false
    stl.async.run(function()
      pane.open_diff_entry({
        left_winnr = -1,
        right_winnr = -1,
        entry = { filepath = "f.txt", stage_type = "unstaged", status = "U" },
      })
      done = true
    end)
    wait(function()
      return done
    end)

    local buffers = assert(applied, "conflict preview applied")
    t.assert_eq("ours", vim.api.nvim_buf_get_lines(buffers[1], 0, 1, false)[1], "stage two on left")
    local working = table.concat(vim.api.nvim_buf_get_lines(buffers[2], 0, -1, false), "\n")
    t.assert_true(working:find("<<<<<<< HEAD", 1, true) ~= nil, "working conflict markers on right")

    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  if not ok then
    error(err)
  end
end)

t:run()
