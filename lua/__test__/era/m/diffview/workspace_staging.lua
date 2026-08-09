---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_staging.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_staging")

local git_calls = {} ---@type table[]
local refreshed = 0
local git_result = { code = 0, stderr = "" }
local git_results = {} ---@type table[]
local delete_calls = {} ---@type string[]
local delete_result = { ok = true, err = nil }
local reports = {} ---@type table[]
local workspace = "/repo"

---@param repo                           string
---@param ...                            string
---@return vim.SystemCompleted
local function git(repo, ...)
  return vim.system({ "git", "-C", repo, ... }, { text = true }):wait()
end

bootstrap.with_global(t, "stl", {
  env = { PATH_SEP = "/" },
  async = {
    run = function(callback)
      callback()
    end,
  },
  git = {
    exec = {
      exec_async = function(args, opts, callback)
        git_calls[#git_calls + 1] = { args = args, opts = opts }
        local result = table.remove(git_results, 1) or git_result
        callback({}, result.code, result.stderr)
      end,
    },
  },
  os = {
    fs = {
      delete = function(filepath)
        delete_calls[#delete_calls + 1] = filepath
        return delete_result.ok, delete_result.err
      end,
    },
  },
  reporter = {
    error = function(options)
      reports[#reports + 1] = options
    end,
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    join = function(base, filepath)
      return base .. "/" .. filepath
    end,
    workspace = function()
      return workspace
    end,
  },
})
bootstrap.with_global(t, "era", { m = { diffview = {} } })

local entries_at_line = {} ---@type table<integer, table<integer, era.m.diffview.IFileEntry>>
t:patch_table(package.loaded, "era.m.diffview.data", {})
t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
  get_entry_at_line = function(bufnr, lnum)
    return entries_at_line[bufnr] and entries_at_line[bufnr][lnum]
  end,
})
t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return "/repo/" .. filepath
  end,
})
t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {})
t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {})

local action = assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()

local function request_refresh()
  refreshed = refreshed + 1
end

local function reset_calls()
  git_calls = {}
  refreshed = 0
  git_result = { code = 0, stderr = "" }
  git_results = {}
  delete_calls = {}
  delete_result = { ok = true, err = nil }
  reports = {}
  workspace = "/repo"
end

---@param call                           table
---@param command                        string
---@param filepath                       string
local function assert_git_call(call, command, filepath)
  t.assert_eq("--literal-pathspecs", call.args[1], "literal pathspecs")
  t.assert_eq(command, call.args[2], "git command")
  t.assert_eq("--", call.args[#call.args - 1], "path separator")
  t.assert_eq(filepath, call.args[#call.args], "filepath")
  t.assert_eq("/repo", call.opts.cwd, "cwd")
end

t:test("changes pane routes stage and unstage to the entry at cursor", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "unstaged", "staged" })
  entries_at_line[changes_bufnr] = {
    { filepath = "cursor-unstaged.txt", stage_type = "unstaged", status = "M" },
    { filepath = "cursor-staged.txt", stage_type = "staged", status = "M" },
  }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      request_refresh = request_refresh,
      get_current_entry = function()
        return { filepath = "preview.txt", stage_type = "unstaged", status = "M" }
      end,
    },
  }

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.stage(ctx)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.unstage(ctx)

  t.assert_eq(3, #git_calls, "git calls")
  assert_git_call(git_calls[1], "add", "cursor-unstaged.txt")
  t.assert_eq("rev-parse", git_calls[2].args[1], "HEAD probe")
  assert_git_call(git_calls[3], "reset", "cursor-staged.txt")
  t.assert_eq("HEAD", git_calls[3].args[3], "reset target")
  t.assert_eq(2, refreshed, "refresh calls")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("sbs routes stage and unstage to the canonical current entry", function()
  reset_calls()
  local sbs_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(0, sbs_bufnr)
  local current = { filepath = "preview-unstaged.txt", stage_type = "unstaged", status = "M" }
  local ctx = {
    layout = { changes_bufnr = vim.api.nvim_create_buf(false, true) },
    state = {
      request_refresh = request_refresh,
      get_current_entry = function()
        return current
      end,
    },
  }

  action.stage(ctx)
  current = { filepath = "preview-staged.txt", stage_type = "staged", status = "M" }
  action.unstage(ctx)

  t.assert_eq(3, #git_calls, "git calls")
  assert_git_call(git_calls[1], "add", "preview-unstaged.txt")
  t.assert_eq("rev-parse", git_calls[2].args[1], "HEAD probe")
  assert_git_call(git_calls[3], "reset", "preview-staged.txt")
  t.assert_eq(2, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(ctx.layout.changes_bufnr, { force = true })
  vim.api.nvim_buf_delete(sbs_bufnr, { force = true })
end)

t:test("rename unstage resets both source and destination", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local current = {
    filepath = "new.lua",
    prev_filepath = "old.lua",
    stage_type = "staged",
    status = "R",
  }
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      request_refresh = request_refresh,
      get_current_entry = function()
        return current
      end,
    },
  }

  action.unstage(ctx)

  t.assert_eq("rev-parse", git_calls[1].args[1], "HEAD probe")
  t.assert_eq("--literal-pathspecs", git_calls[2].args[1], "literal pathspecs")
  t.assert_eq("reset", git_calls[2].args[2], "git command")
  t.assert_eq("HEAD", git_calls[2].args[3], "reset target")
  t.assert_eq("--", git_calls[2].args[4], "path separator")
  t.assert_eq("old.lua", git_calls[2].args[5], "rename source")
  t.assert_eq("new.lua", git_calls[2].args[6], "rename destination")
  t.assert_eq(1, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("rename stage adds both source and destination", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      request_refresh = request_refresh,
      get_current_entry = function()
        return { filepath = "new.lua", prev_filepath = "old.lua", stage_type = "unstaged", status = "R" }
      end,
    },
  }

  action.stage(ctx)

  t.assert_eq("--literal-pathspecs", git_calls[1].args[1], "literal pathspecs")
  t.assert_eq("add", git_calls[1].args[2], "git command")
  t.assert_eq("--", git_calls[1].args[3], "path separator")
  t.assert_eq("old.lua", git_calls[1].args[4], "rename source")
  t.assert_eq("new.lua", git_calls[1].args[5], "rename destination")
  t.assert_eq(1, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("stage, unstage, and discard treat pathspec-magic filenames literally", function()
  reset_calls()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    local magic = ":(glob)o*.txt" ---@type string
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "magic base" }, repo .. "/" .. magic)
    vim.fn.writefile({ "other base" }, repo .. "/other.txt")
    t.assert_eq(0, git(repo, "add", "--all").code, "initial add")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "initial commit"
    )
    vim.fn.writefile({ "magic changed" }, repo .. "/" .. magic)
    vim.fn.writefile({ "other changed" }, repo .. "/other.txt")
    workspace = repo

    t:patch_table(stl.git.exec, "exec_async", function(args, opts, callback)
      local cmd = { "git", "-C", assert(opts.cwd) }
      vim.list_extend(cmd, args)
      local result = vim.system(cmd, { text = true }):wait()
      callback({}, result.code, result.stderr or "")
    end)

    local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "magic" })
    local entry = { filepath = magic, stage_type = "unstaged", status = "M" }
    entries_at_line[changes_bufnr] = { entry }
    vim.api.nvim_win_set_buf(0, changes_bufnr)
    local ctx = { layout = { changes_bufnr = changes_bufnr }, state = { request_refresh = request_refresh } }

    action.stage(ctx)
    local cached = git(repo, "diff", "--staged", "--name-only", "-z", "--")
    t.assert_eq(magic .. "\0", cached.stdout or "", "only the literal filename staged")

    entry.stage_type = "staged"
    action.unstage(ctx)
    cached = git(repo, "diff", "--staged", "--name-only", "-z", "--")
    t.assert_eq("", cached.stdout or "", "only the literal filename unstaged")

    entry.stage_type = "unstaged"
    action.reset(ctx)
    t.assert_eq("magic base", vim.fn.readfile(repo .. "/" .. magic)[1], "literal filename discarded")
    t.assert_eq("other changed", vim.fn.readfile(repo .. "/other.txt")[1], "glob target preserved")
    t.assert_eq(3, refreshed, "refresh calls")
    entries_at_line[changes_bufnr] = nil
    vim.api.nvim_buf_delete(changes_bufnr, { force = true })
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  workspace = "/repo"
  if not ok then
    error(err)
  end
end)

t:test("rename stage updates both paths in a real Git index", function()
  reset_calls()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "content" }, repo .. "/old.lua")
    t.assert_eq(0, git(repo, "add", "--", "old.lua").code, "initial add")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "initial commit"
    )
    t.assert_eq(0, vim.uv.fs_rename(repo .. "/old.lua", repo .. "/new.lua") and 0 or 1, "rename file")
    t.assert_eq(0, git(repo, "add", "-N", "--", "new.lua").code, "intent-to-add destination")
    workspace = repo

    t:patch_table(stl.git.exec, "exec_async", function(args, opts, callback)
      local cmd = { "git", "-C", assert(opts.cwd) }
      vim.list_extend(cmd, args)
      local result = vim.system(cmd, { text = true }):wait()
      callback({}, result.code, result.stderr or "")
    end)

    local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    local ctx = {
      layout = { changes_bufnr = changes_bufnr },
      state = {
        request_refresh = request_refresh,
        get_current_entry = function()
          return { filepath = "new.lua", prev_filepath = "old.lua", stage_type = "unstaged", status = "R" }
        end,
      },
    }

    action.stage(ctx)

    local cached = git(repo, "diff", "--staged", "--name-status", "--")
    local worktree = git(repo, "diff", "--name-status", "--")
    t.assert_eq(0, cached.code, "cached diff")
    t.assert_true((cached.stdout or ""):find("old.lua", 1, true) ~= nil, "source staged")
    t.assert_true((cached.stdout or ""):find("new.lua", 1, true) ~= nil, "destination staged")
    t.assert_eq("", worktree.stdout or "", "rename fully staged")
    t.assert_eq(1, refreshed, "refresh calls")
    vim.api.nvim_buf_delete(changes_bufnr, { force = true })
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  workspace = "/repo"
  if not ok then
    error(err)
  end
end)

t:test("rename unstage clears both paths from a real Git index", function()
  reset_calls()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "content" }, repo .. "/old.lua")
    t.assert_eq(0, git(repo, "add", "--", "old.lua").code, "initial add")
    t.assert_eq(
      0,
      git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "base").code,
      "initial commit"
    )
    t.assert_eq(0, git(repo, "mv", "old.lua", "new.lua").code, "git mv")
    workspace = repo

    t:patch_table(stl.git.exec, "exec_async", function(args, opts, callback)
      local cmd = { "git", "-C", assert(opts.cwd) }
      vim.list_extend(cmd, args)
      local result = vim.system(cmd, { text = true }):wait()
      callback({}, result.code, result.stderr or "")
    end)

    local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    local ctx = {
      layout = { changes_bufnr = changes_bufnr },
      state = {
        request_refresh = request_refresh,
        get_current_entry = function()
          return { filepath = "new.lua", prev_filepath = "old.lua", stage_type = "staged", status = "R" }
        end,
      },
    }

    action.unstage(ctx)

    local cached = git(repo, "diff", "--staged", "--name-status", "--")
    t.assert_eq(0, cached.code, "cached diff")
    t.assert_eq("", cached.stdout or "", "index has no staged rename residue")
    t.assert_eq(1, refreshed, "refresh calls")
    vim.api.nvim_buf_delete(changes_bufnr, { force = true })
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  workspace = "/repo"
  if not ok then
    error(err)
  end
end)

t:test("unborn unstage removes only the index entry", function()
  reset_calls()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")

  local ok, err = xpcall(function()
    t.assert_eq(0, git(repo, "init", "-q").code, "git init")
    vim.fn.writefile({ "content" }, repo .. "/staged.lua")
    t.assert_eq(0, git(repo, "add", "--", "staged.lua").code, "git add")
    workspace = repo

    t:patch_table(stl.git.exec, "exec_async", function(args, opts, callback)
      local cmd = { "git", "-C", assert(opts.cwd) }
      vim.list_extend(cmd, args)
      local result = vim.system(cmd, { text = true }):wait()
      callback({}, result.code, result.stderr or "")
    end)

    local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    local ctx = {
      layout = { changes_bufnr = changes_bufnr },
      state = {
        request_refresh = request_refresh,
        get_current_entry = function()
          return { filepath = "staged.lua", stage_type = "staged", status = "A" }
        end,
      },
    }

    action.unstage(ctx)

    t.assert_eq(1, git(repo, "ls-files", "--error-unmatch", "--", "staged.lua").code, "index entry removed")
    t.assert_eq(1, vim.fn.filereadable(repo .. "/staged.lua"), "worktree file preserved")
    t.assert_eq(1, refreshed, "refresh calls")
    vim.api.nvim_buf_delete(changes_bufnr, { force = true })
  end, debug.traceback)

  vim.fn.delete(repo, "rf")
  workspace = "/repo"
  if not ok then
    error(err)
  end
end)

t:test("stage and unstage report Git failures without refreshing", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "unstaged", "staged" })
  entries_at_line[changes_bufnr] = {
    { filepath = "locked.txt", stage_type = "unstaged", status = "M" },
    { filepath = "denied.txt", stage_type = "staged", status = "M" },
  }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      request_refresh = request_refresh,
      get_current_entry = function()
        return nil
      end,
    },
  }

  git_result = { code = 128, stderr = "fatal: Unable to create '.git/index.lock'\n" }
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.stage(ctx)
  git_results = {
    { code = 0, stderr = "" },
    { code = 1, stderr = "" },
  }
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.unstage(ctx)

  t.assert_eq(0, refreshed, "refresh calls")
  t.assert_eq(2, #reports, "error reports")
  t.assert_eq("stage", reports[1].subject, "stage report subject")
  t.assert_eq(
    "Failed to stage `locked.txt` (exit 128): fatal: Unable to create '.git/index.lock'",
    reports[1].message,
    "stage report message"
  )
  t.assert_eq("unstage", reports[2].subject, "unstage report subject")
  t.assert_eq("Failed to unstage `denied.txt` (exit 1).", reports[2].message, "unstage report message")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("discard refreshes after tracked and untracked files are removed", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "tracked", "untracked" })
  entries_at_line[changes_bufnr] = {
    { filepath = "tracked.txt", stage_type = "unstaged", status = "M" },
    { filepath = "back\\slash.txt", stage_type = "unstaged", status = "?" },
  }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = { layout = { changes_bufnr = changes_bufnr }, state = { request_refresh = request_refresh } }

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.reset(ctx)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.reset(ctx)

  t.assert_eq(1, #git_calls, "git calls")
  assert_git_call(git_calls[1], "checkout", "tracked.txt")
  t.assert_eq("/repo/back\\slash.txt", delete_calls[1], "deleted filepath")
  t.assert_eq(2, refreshed, "refresh calls")
  t.assert_eq(0, #reports, "error reports")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("discard reports tracked and untracked failures without refreshing", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "tracked", "untracked" })
  entries_at_line[changes_bufnr] = {
    { filepath = "conflicted.txt", stage_type = "unstaged", status = "M" },
    { filepath = "locked.txt", stage_type = "unstaged", status = "?" },
  }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = { layout = { changes_bufnr = changes_bufnr }, state = { request_refresh = request_refresh } }

  git_result = { code = 128, stderr = "fatal: checkout failed\n" }
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.reset(ctx)
  delete_result = { ok = false, err = "permission_denied" }
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.reset(ctx)

  t.assert_eq(0, refreshed, "refresh calls")
  t.assert_eq(2, #reports, "error reports")
  t.assert_eq("discard", reports[1].subject, "tracked report subject")
  t.assert_eq(
    "Failed to discard `conflicted.txt` (exit 128): fatal: checkout failed",
    reports[1].message,
    "tracked report message"
  )
  t.assert_eq("discard", reports[2].subject, "untracked report subject")
  t.assert_eq(
    "Failed to discard `locked.txt`: unable to delete the untracked file.",
    reports[2].message,
    "untracked report message"
  )
  t.assert_eq("permission_denied", reports[2].details.error, "untracked report error")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("sbs keymaps route whole-file stage and unstage", function()
  local calls = {} ---@type string[]
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", {
    stage = function()
      calls[#calls + 1] = "stage"
    end,
    unstage = function()
      calls[#calls + 1] = "unstage"
    end,
  })

  local keymap = assert(loadfile("lua/era/m/diffview/view/workspace/keymap.lua"))()
  for _, mapping in ipairs(keymap.gen_sbs({})) do
    if mapping.key == "gs" or mapping.key == "gu" then
      mapping.callback()
    end
  end

  t.assert_eq("stage", calls[1], "gs routing")
  t.assert_eq("unstage", calls[2], "gu routing")
  t.assert_eq(2, #calls, "whole-file mappings")
end)

t:run()
