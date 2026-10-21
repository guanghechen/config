local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local git = require("__test__.support.git")

local git_calls = {} ---@type table[]
local refreshed = 0
local git_result = { code = 0, stderr = "" }
local git_results = {} ---@type table[]
local reports = {} ---@type table[]
local workspace = "/repo"

---@param args                          string[]
---@param opts                          { cwd: string, stdin: string|nil }
---@param callback                      fun(lines: string[], code: integer, stderr: string)
local function exec_real_git(args, opts, callback)
  local cmd = { "git", "-C", opts.cwd }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { text = true, stdin = opts.stdin }):wait()
  callback({}, result.code, result.stderr or "")
end

bootstrap.with_global(t, "stl", {
  c = {
    Future = require("stl.c.future"),
  },
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
bootstrap.with_global(t, "era", {
  m = {
    diffview = {},
    git = {
      index = require("era.m.git.index"),
    },
  },
})

local entries_at_line = {} ---@type table<integer, table<integer, era.m.diffview.IFileEntry>>
local line_maps = {} ---@type table<integer, era.m.diffview.IFiletreeItem[]>
local pane = require("__test__.support.diffview_pane").new(function(bufnr)
  return line_maps[bufnr]
end)
pane.get_entry_at_line = function(bufnr, lnum)
  return entries_at_line[bufnr] and entries_at_line[bufnr][lnum]
end
pane.get_item_at_line = function(bufnr, lnum)
  return line_maps[bufnr] and line_maps[bufnr][lnum]
end
t:patch_table(package.loaded, "era.m.diffview.pane.changes", pane)
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return "/repo/" .. filepath
  end,
})
t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
  focus_changes = function(lyt, stage_type)
    local pane = lyt.changes and lyt.changes[stage_type]
    if pane and pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      vim.api.nvim_set_current_win(pane.winnr)
    end
  end,
  get_changes_pane = function(lyt, stage_type)
    if lyt.changes then
      return lyt.changes[stage_type]
    end
    return { stage_type = stage_type }
  end,
  get_changes_panes = function(lyt)
    if not lyt.changes then
      return {}
    end
    return { lyt.changes.staged, lyt.changes.unstaged }
  end,
  is_changes_buffer = function(lyt, bufnr)
    if lyt.changes then
      return lyt.changes.staged.bufnr == bufnr or lyt.changes.unstaged.bufnr == bufnr
    end
    return lyt.changes_bufnr == bufnr
  end,
})

local action = require("era.m.diffview.view.workspace.action")

local function request_refresh()
  refreshed = refreshed + 1
end

local function reset_calls()
  git_calls = {}
  refreshed = 0
  git_result = { code = 0, stderr = "" }
  git_results = {}
  reports = {}
  workspace = "/repo"
  line_maps = {}
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

---@param call                          table
---@return string[]
local function get_pathspecs(call)
  local input = assert(call.opts.stdin, "pathspec stdin")
  t.assert_eq("\0", input:sub(-1), "trailing NUL")
  return vim.split(input:sub(1, -2), "\0", { plain = true })
end

---@param call                          table
---@param command                       string
---@param expected                      string[]
local function assert_transfer_call(call, command, expected)
  t.assert_eq("--literal-pathspecs", call.args[1], "literal pathspecs")
  t.assert_eq(command, call.args[2], "git command")
  t.assert_eq("--pathspec-from-file=-", call.args[#call.args - 1], "pathspec stdin")
  t.assert_eq("--pathspec-file-nul", call.args[#call.args], "NUL pathspecs")
  t.assert_eq("/repo", call.opts.cwd, "cwd")

  local actual = get_pathspecs(call)
  t.assert_eq(#expected, #actual, "pathspec count")
  for i, filepath in ipairs(expected) do
    t.assert_eq(filepath, actual[i], "pathspec " .. i)
  end
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
  assert_transfer_call(git_calls[1], "add", { "cursor-unstaged.txt" })
  t.assert_eq("rev-parse", git_calls[2].args[1], "HEAD probe")
  assert_transfer_call(git_calls[3], "reset", { "cursor-staged.txt" })
  t.assert_eq("HEAD", git_calls[3].args[3], "reset target")
  t.assert_eq(2, refreshed, "refresh calls")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("whole-file stage shares the repository index FIFO", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "unstaged" })
  entries_at_line[changes_bufnr] = {
    { filepath = "queued.txt", stage_type = "unstaged", status = "M" },
  }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_current_entry = function()
        return nil
      end,
      request_refresh = request_refresh,
    },
  }

  local release = nil ---@type (fun(result: nil): nil)|nil
  era.m.git.index.run("/repo", function(resolve)
    release = resolve
  end)

  action.stage(ctx)
  t.assert_eq(0, #git_calls, "whole-file stage waits")
  assert(release)(nil)

  t.assert_eq(1, #git_calls, "whole-file stage starts after release")
  assert_transfer_call(git_calls[1], "add", { "queued.txt" })
  t.assert_eq(1, refreshed, "refresh after queued stage")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("changes pane copies the filepath for the entry at cursor", function()
  reset_calls()
  local selections = {} ---@type era.fn.select_copy_filepath.IParams[]
  t:patch_table(era, "fn", {
    select_copy_filepath = function(params)
      selections[#selections + 1] = params
    end,
  })
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "Unstaged", "src/main.lua" })
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  entries_at_line[changes_bufnr] = {
    [2] = { filepath = "src/main.lua", stage_type = "unstaged", status = "M" },
  }

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.copy_filepath()

  t.assert_eq(1, #selections, "selection count")
  t.assert_eq("/repo/src/main.lua", selections[1].filepath, "absolute filepath")
  t.assert_eq("cursor", selections[1].relative, "popup anchor")
  t.assert_eq(1, selections[1].row, "popup row")
  t.assert_eq(4, selections[1].col, "popup column")

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.copy_filepath()
  t.assert_eq(1, #selections, "non-file row ignored")

  entries_at_line[changes_bufnr] = nil
  vim.cmd.enew()
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("stage transfers keep the source work queue stable and move focus only when it empties", function()
  reset_calls()
  local staged_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(staged_winnr) ---@type integer
  local staged_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local unstaged_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(staged_winnr, staged_bufnr)
  vim.cmd("belowright split")
  local unstaged_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(unstaged_winnr, unstaged_bufnr)

  local first_unstaged = { filepath = "first.lua", stage_type = "unstaged", status = "M" }
  local first_staged = { filepath = "first.lua", stage_type = "staged", status = "M" }
  local second_unstaged = { filepath = "second.lua", stage_type = "unstaged", status = "M" }
  local second_staged = { filepath = "second.lua", stage_type = "staged", status = "M" }
  local third_staged = { filepath = "third.lua", stage_type = "staged", status = "M" }
  local root_unstaged = { filepath = "root.lua", stage_type = "unstaged", status = "M" }
  local root_staged = { filepath = "root.lua", stage_type = "staged", status = "M" }
  local hidden_unstaged = { filepath = "hidden/inside.lua", stage_type = "unstaged", status = "M" }
  local nested_unstaged = { filepath = "src/a.lua", stage_type = "unstaged", status = "M" }
  local nested_staged = { filepath = "src/a.lua", stage_type = "staged", status = "M" }
  local remaining_unstaged = { filepath = "remaining.lua", stage_type = "unstaged", status = "M" }
  local current = first_unstaged ---@type era.m.diffview.IFileEntry
  local entries = { first_unstaged, second_unstaged } ---@type era.m.diffview.IFileEntry[]
  local phase = 1
  local layout = {
    changes = {
      staged = { stage_type = "staged", bufnr = staged_bufnr, winnr = staged_winnr },
      unstaged = { stage_type = "unstaged", bufnr = unstaged_bufnr, winnr = unstaged_winnr },
    },
  }
  local state = {
    get_current_entry = function()
      return current
    end,
    get_entries = function()
      return entries
    end,
    request_refresh = function(_, callback)
      if phase == 1 then
        entries = { first_staged, second_unstaged }
        line_maps[unstaged_bufnr] = {
          { type = "header", stage_type = "unstaged" },
          { type = "file", entry = second_unstaged, stage_type = "unstaged" },
        }
      elseif phase == 2 then
        entries = { first_unstaged, third_staged, second_unstaged }
        line_maps[staged_bufnr] = {
          { type = "header", stage_type = "staged" },
          { type = "file", entry = third_staged, stage_type = "staged" },
        }
      elseif phase == 3 then
        entries = { second_staged, third_staged }
        current = second_staged
        line_maps[unstaged_bufnr] = {
          { type = "header", stage_type = "unstaged" },
        }
      elseif phase == 4 then
        entries = { root_staged, hidden_unstaged, third_staged }
        current = root_staged
        line_maps[unstaged_bufnr] = {
          { type = "header", stage_type = "unstaged" },
          { type = "directory", uuid = "hidden", stage_type = "unstaged" },
        }
      else
        entries = { nested_staged, remaining_unstaged, third_staged }
        line_maps[staged_bufnr] = {
          { type = "header", stage_type = "staged" },
          { type = "file", entry = nested_staged, stage_type = "staged" },
          { type = "file", entry = third_staged, stage_type = "staged" },
        }
        line_maps[unstaged_bufnr] = {
          { type = "header", stage_type = "unstaged" },
          { type = "file", entry = remaining_unstaged, stage_type = "unstaged" },
        }
      end
      callback()
    end,
    set_current_entry = function(_, entry)
      current = entry
    end,
  }
  local ctx = { layout = layout, state = state }

  vim.api.nvim_buf_set_lines(unstaged_bufnr, 0, -1, false, { "Unstaged", "first.lua", "second.lua" })
  entries_at_line[unstaged_bufnr] = { [2] = first_unstaged, [3] = second_unstaged }
  line_maps[unstaged_bufnr] = {
    { type = "header", stage_type = "unstaged" },
    { type = "file", entry = first_unstaged, stage_type = "unstaged" },
    { type = "file", entry = second_unstaged, stage_type = "unstaged" },
  }
  vim.api.nvim_set_current_win(unstaged_winnr)
  vim.api.nvim_win_set_cursor(unstaged_winnr, { 2, 0 })
  action.stage(ctx)
  t.assert_eq(second_unstaged, current, "stage selects the next unstaged entry")
  t.assert_eq(unstaged_winnr, vim.api.nvim_get_current_win(), "stage keeps unstaged focus")

  phase = 2
  current = first_staged
  entries = { first_staged, third_staged, second_unstaged }
  vim.api.nvim_buf_set_lines(staged_bufnr, 0, -1, false, { "Staged", "first.lua", "third.lua" })
  entries_at_line[staged_bufnr] = { [2] = first_staged, [3] = third_staged }
  line_maps[staged_bufnr] = {
    { type = "header", stage_type = "staged" },
    { type = "file", entry = first_staged, stage_type = "staged" },
    { type = "file", entry = third_staged, stage_type = "staged" },
  }
  vim.api.nvim_set_current_win(staged_winnr)
  vim.api.nvim_win_set_cursor(staged_winnr, { 2, 0 })
  action.unstage(ctx)
  t.assert_eq(third_staged, current, "unstage selects the next staged entry")
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "unstage keeps staged focus")

  phase = 3
  current = second_unstaged
  entries = { second_unstaged, third_staged }
  vim.api.nvim_buf_set_lines(unstaged_bufnr, 0, -1, false, { "Unstaged", "second.lua" })
  entries_at_line[unstaged_bufnr] = { [2] = second_unstaged }
  line_maps[unstaged_bufnr] = {
    { type = "header", stage_type = "unstaged" },
    { type = "file", entry = second_unstaged, stage_type = "unstaged" },
  }
  vim.api.nvim_set_current_win(unstaged_winnr)
  vim.api.nvim_win_set_cursor(unstaged_winnr, { 2, 0 })
  action.stage(ctx)
  t.assert_eq(second_staged, current, "last transfer follows the canonical destination entry")
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "empty source moves focus to destination")

  phase = 4
  current = root_unstaged
  entries = { root_unstaged, hidden_unstaged, third_staged }
  vim.api.nvim_buf_set_lines(unstaged_bufnr, 0, -1, false, { "Unstaged", "root.lua", "  hidden/" })
  entries_at_line[unstaged_bufnr] = { [2] = root_unstaged }
  line_maps[unstaged_bufnr] = {
    { type = "header", stage_type = "unstaged" },
    { type = "file", entry = root_unstaged, stage_type = "unstaged" },
    { type = "directory", uuid = "hidden", stage_type = "unstaged" },
  }
  vim.api.nvim_set_current_win(unstaged_winnr)
  vim.api.nvim_win_set_cursor(unstaged_winnr, { 2, 0 })
  action.stage(ctx)
  t.assert_eq(root_staged, current, "hidden source entries follow the canonical destination entry")
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "hidden-only source moves focus to destination")

  phase = 5
  current = nested_unstaged
  entries = { nested_unstaged, remaining_unstaged, third_staged }
  vim.api.nvim_buf_set_lines(unstaged_bufnr, 0, -1, false, { "Unstaged", "src", "remaining.lua" })
  entries_at_line[unstaged_bufnr] = {}
  line_maps[unstaged_bufnr] = {
    { type = "header", stage_type = "unstaged" },
    { type = "directory", uuid = "src", stage_type = "unstaged" },
    { type = "file", entry = remaining_unstaged, stage_type = "unstaged" },
  }
  vim.api.nvim_set_current_win(unstaged_winnr)
  vim.api.nvim_win_set_cursor(unstaged_winnr, { 2, 0 })
  action.stage(ctx)
  t.assert_eq(remaining_unstaged, current, "directory stage selects the next source entry")
  t.assert_eq(unstaged_winnr, vim.api.nvim_get_current_win(), "directory stage keeps source focus")

  entries_at_line[staged_bufnr] = nil
  entries_at_line[unstaged_bufnr] = nil
  line_maps[staged_bufnr] = nil
  line_maps[unstaged_bufnr] = nil
  vim.api.nvim_win_close(unstaged_winnr, true)
  vim.api.nvim_set_current_win(staged_winnr)
  vim.api.nvim_win_set_buf(staged_winnr, original_bufnr)
  vim.api.nvim_buf_delete(staged_bufnr, { force = true })
  vim.api.nvim_buf_delete(unstaged_bufnr, { force = true })
end)

t:test("completed Git work does not refresh disposed workspace state", function()
  reset_calls()
  local entry = { filepath = "deferred.lua", stage_type = "unstaged", status = "M" }
  local disposed = false
  local reads = 0
  local writes = 0
  local refreshes = 0
  local resolve_git = nil ---@type fun(stdout: string[], code: integer, stderr: string)|nil
  t:patch_table(stl.git.exec, "exec_async", function(_, _, callback)
    resolve_git = callback
  end)

  local ctx = {
    layout = {},
    state = {
      get_current_entry = function()
        reads = reads + 1
        return entry
      end,
      is_disposed = function()
        return disposed
      end,
      request_refresh = function()
        refreshes = refreshes + 1
      end,
      set_current_entry = function()
        writes = writes + 1
      end,
    },
  }

  action.stage(ctx)
  disposed = true
  assert(resolve_git)({}, 0, "")

  t.assert_eq(1, reads, "disposed callback does not read selection")
  t.assert_eq(0, writes, "disposed callback does not write selection")
  t.assert_eq(0, refreshes, "disposed callback does not request refresh")
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
  assert_transfer_call(git_calls[1], "add", { "preview-unstaged.txt" })
  t.assert_eq("rev-parse", git_calls[2].args[1], "HEAD probe")
  assert_transfer_call(git_calls[3], "reset", { "preview-staged.txt" })
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
  assert_transfer_call(git_calls[2], "reset", { "old.lua", "new.lua" })
  t.assert_eq("HEAD", git_calls[2].args[3], "reset target")
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

  assert_transfer_call(git_calls[1], "add", { "old.lua", "new.lua" })
  t.assert_eq(1, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("changes directory stage includes every unstaged descendant", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "Unstaged", "src" })
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  line_maps[changes_bufnr] = {
    { type = "header", stage_type = "unstaged" },
    { type = "directory", stage_type = "unstaged", uuid = "src" },
  }
  local entries = {
    { filepath = "src/a.lua", stage_type = "unstaged", status = "M" },
    { filepath = "src/nested/b.lua", stage_type = "unstaged", status = "M" },
    {
      filepath = "src/new.lua",
      prev_filepath = "legacy.lua",
      stage_type = "unstaged",
      status = "R",
    },
    { filepath = "outside.lua", stage_type = "unstaged", status = "M" },
    { filepath = "src/already.lua", stage_type = "staged", status = "M" },
  }
  for i = 1, 20000 do
    entries[#entries + 1] = {
      filepath = string.format("src/generated/%05d.lua", i),
      prev_filepath = string.format("legacy/generated/%05d.lua", i),
      stage_type = "unstaged",
      status = "R",
    }
  end
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_current_entry = function()
        return nil
      end,
      get_entries = function()
        return entries
      end,
      request_refresh = request_refresh,
    },
  }

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.stage(ctx)

  local call = git_calls[1]
  t.assert_eq(4, #call.args, "argv stays fixed as external renames grow")
  local pathspecs = get_pathspecs(call)
  t.assert_eq(40004, #pathspecs, "all exact snapshot paths")
  t.assert_eq("src/a.lua", pathspecs[1], "direct child")
  t.assert_eq("src/nested/b.lua", pathspecs[2], "nested child")
  t.assert_eq("legacy.lua", pathspecs[3], "rename source")
  t.assert_eq("src/new.lua", pathspecs[4], "rename destination")
  t.assert_eq("legacy/generated/00001.lua", pathspecs[5], "first generated source")
  t.assert_eq("src/generated/00001.lua", pathspecs[6], "first generated destination")
  t.assert_eq("src/generated/20000.lua", pathspecs[#pathspecs], "last generated destination")
  t.assert_eq(1, refreshed, "refresh calls")

  line_maps[changes_bufnr] = nil
  vim.cmd.enew()
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("changes directory unstage handles HEAD and unborn repositories", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "Staged", "src" })
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  line_maps[changes_bufnr] = {
    { type = "header", stage_type = "staged" },
    { type = "directory", stage_type = "staged", uuid = "src" },
  }
  local entries = {
    { filepath = "src/a.lua", stage_type = "staged", status = "M" },
    {
      filepath = "src/new.lua",
      prev_filepath = "legacy.lua",
      stage_type = "staged",
      status = "R",
    },
    { filepath = "outside.lua", stage_type = "staged", status = "M" },
  }
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_current_entry = function()
        return nil
      end,
      get_entries = function()
        return entries
      end,
      request_refresh = request_refresh,
    },
  }

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.unstage(ctx)

  t.assert_eq("rev-parse", git_calls[1].args[1], "HEAD probe")
  assert_transfer_call(git_calls[2], "reset", { "src/a.lua", "legacy.lua", "src/new.lua" })
  t.assert_eq("HEAD", git_calls[2].args[3], "reset target")
  t.assert_eq(1, refreshed, "HEAD refresh")

  reset_calls()
  entries = {
    { filepath = "src/new.lua", stage_type = "staged", status = "A" },
  }
  line_maps[changes_bufnr] = {
    { type = "header", stage_type = "staged" },
    { type = "directory", stage_type = "staged", uuid = "src" },
  }
  git_results = {
    { code = 1, stderr = "" },
    { code = 0, stderr = "" },
  }
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.unstage(ctx)

  t.assert_eq("rev-parse", git_calls[1].args[1], "unborn HEAD probe")
  assert_transfer_call(git_calls[2], "rm", { "src/new.lua" })
  t.assert_eq("--cached", git_calls[2].args[3], "cached only")
  t.assert_eq("-f", git_calls[2].args[4], "force index removal")
  t.assert_eq(1, refreshed, "unborn refresh")

  line_maps[changes_bufnr] = nil
  vim.cmd.enew()
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("stage, unstage, and discard treat pathspec-magic filenames literally", function()
  reset_calls()
  local repo = git.repo(t)
  t:defer(function()
    workspace = "/repo"
  end)
  local magic = ":(glob)o*.txt" ---@type string
  vim.fn.writefile({ "magic base" }, repo .. "/" .. magic)
  vim.fn.writefile({ "other base" }, repo .. "/other.txt")
  git.run(repo, { "add", "--all" })
  git.run(repo, { "commit", "-qm", "base" })
  vim.fn.writefile({ "magic changed" }, repo .. "/" .. magic)
  vim.fn.writefile({ "other changed" }, repo .. "/other.txt")
  workspace = repo

  t:patch_table(stl.git.exec, "exec_async", exec_real_git)

  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "magic" })
  local entry = { filepath = magic, stage_type = "unstaged", status = "M" }
  entries_at_line[changes_bufnr] = { entry }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_current_entry = function()
        return entry
      end,
      request_refresh = request_refresh,
      set_current_entry = function() end,
    },
  }

  action.stage(ctx)
  local cached = git.system(repo, { "diff", "--staged", "--name-only", "-z", "--" })
  t.assert_eq(magic .. "\0", cached.stdout or "", "only the literal filename staged")

  entry.stage_type = "staged"
  action.unstage(ctx)
  cached = git.system(repo, { "diff", "--staged", "--name-only", "-z", "--" })
  t.assert_eq("", cached.stdout or "", "only the literal filename unstaged")

  entry.stage_type = "unstaged"
  action.reset(ctx)
  t.assert_eq("magic base", vim.fn.readfile(repo .. "/" .. magic)[1], "literal filename discarded")
  t.assert_eq("other changed", vim.fn.readfile(repo .. "/other.txt")[1], "glob target preserved")
  t.assert_eq(3, refreshed, "refresh calls")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("rename stage updates both paths in a real Git index", function()
  reset_calls()
  local repo = git.repo(t)
  t:defer(function()
    workspace = "/repo"
  end)
  vim.fn.writefile({ "content" }, repo .. "/old.lua")
  git.run(repo, { "add", "--", "old.lua" })
  git.run(repo, { "commit", "-qm", "base" })
  t.assert_eq(0, vim.uv.fs_rename(repo .. "/old.lua", repo .. "/new.lua") and 0 or 1, "rename file")
  git.run(repo, { "add", "-N", "--", "new.lua" })
  workspace = repo

  t:patch_table(stl.git.exec, "exec_async", exec_real_git)

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

  local cached = git.system(repo, { "diff", "--staged", "--name-status", "--" })
  local worktree = git.run(repo, { "diff", "--name-status", "--" })
  t.assert_eq(0, cached.code, "cached diff")
  t.assert_true((cached.stdout or ""):find("old.lua", 1, true) ~= nil, "source staged")
  t.assert_true((cached.stdout or ""):find("new.lua", 1, true) ~= nil, "destination staged")
  t.assert_eq("", worktree, "rename fully staged")
  t.assert_eq(1, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("rename unstage clears both paths from a real Git index", function()
  reset_calls()
  local repo = git.repo(t)
  t:defer(function()
    workspace = "/repo"
  end)
  vim.fn.writefile({ "content" }, repo .. "/old.lua")
  git.run(repo, { "add", "--", "old.lua" })
  git.run(repo, { "commit", "-qm", "base" })
  git.run(repo, { "mv", "old.lua", "new.lua" })
  workspace = repo

  t:patch_table(stl.git.exec, "exec_async", exec_real_git)

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

  local cached = git.system(repo, { "diff", "--staged", "--name-status", "--" })
  t.assert_eq(0, cached.code, "cached diff")
  t.assert_eq("", cached.stdout or "", "index has no staged rename residue")
  t.assert_eq(1, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("unborn unstage removes only the index entry", function()
  reset_calls()
  local repo = git.repo(t)
  t:defer(function()
    workspace = "/repo"
  end)
  vim.fn.writefile({ "content" }, repo .. "/staged.lua")
  git.run(repo, { "add", "--", "staged.lua" })
  workspace = repo

  t:patch_table(stl.git.exec, "exec_async", exec_real_git)

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

  t.assert_eq(1, git.system(repo, { "ls-files", "--error-unmatch", "--", "staged.lua" }).code, "index entry removed")
  t.assert_eq(1, vim.fn.filereadable(repo .. "/staged.lua"), "worktree file preserved")
  t.assert_eq(1, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
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

t:test("discard refreshes after a tracked file is restored", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "tracked" })
  entries_at_line[changes_bufnr] = {
    { filepath = "tracked.txt", stage_type = "unstaged", status = "M" },
  }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = { layout = { changes_bufnr = changes_bufnr }, state = { request_refresh = request_refresh } }

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.reset(ctx)

  t.assert_eq(1, #git_calls, "git calls")
  assert_git_call(git_calls[1], "checkout", "tracked.txt")
  t.assert_eq(1, refreshed, "refresh calls")
  t.assert_eq(0, #reports, "error reports")
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("discard reports a tracked failure without refreshing", function()
  reset_calls()
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "tracked" })
  entries_at_line[changes_bufnr] = {
    { filepath = "conflicted.txt", stage_type = "unstaged", status = "M" },
  }
  vim.api.nvim_win_set_buf(0, changes_bufnr)
  local ctx = { layout = { changes_bufnr = changes_bufnr }, state = { request_refresh = request_refresh } }

  git_result = { code = 128, stderr = "fatal: checkout failed\n" }
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.reset(ctx)

  t.assert_eq(0, refreshed, "refresh calls")
  t.assert_eq(1, #reports, "error reports")
  t.assert_eq("discard", reports[1].subject, "tracked report subject")
  t.assert_eq(
    "Failed to discard `conflicted.txt` (exit 128): fatal: checkout failed",
    reports[1].message,
    "tracked report message"
  )
  entries_at_line[changes_bufnr] = nil
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:run()
