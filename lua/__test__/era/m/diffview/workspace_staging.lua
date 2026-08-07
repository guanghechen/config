---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_staging.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_staging")

local git_calls = {} ---@type table[]
local refreshed = 0

bootstrap.with_global(t, "stl", {
  async = {
    run = function(callback)
      callback()
    end,
  },
  git = {
    exec = {
      exec_async = function(args, opts, callback)
        git_calls[#git_calls + 1] = { args = args, opts = opts }
        callback(nil, 0)
      end,
    },
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    workspace = function()
      return "/repo"
    end,
  },
})
bootstrap.with_global(t, "era", {})

local entries_at_line = {} ---@type table<integer, table<integer, era.m.diffview.IFileEntry>>
t:patch_table(package.loaded, "era.m.diffview.data", {})
t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
  get_entry_at_line = function(bufnr, lnum)
    return entries_at_line[bufnr] and entries_at_line[bufnr][lnum]
  end,
})
t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {})
t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {})

local action = assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()
action.refresh = function()
  refreshed = refreshed + 1
end

local function reset_calls()
  git_calls = {}
  refreshed = 0
end

---@param call                           table
---@param command                        string
---@param filepath                       string
local function assert_git_call(call, command, filepath)
  t.assert_eq(command, call.args[1], "git command")
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
      get_current_entry = function()
        return { filepath = "preview.txt", stage_type = "unstaged", status = "M" }
      end,
    },
  }

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  action.stage(ctx)
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  action.unstage(ctx)

  t.assert_eq(2, #git_calls, "git calls")
  assert_git_call(git_calls[1], "add", "cursor-unstaged.txt")
  assert_git_call(git_calls[2], "reset", "cursor-staged.txt")
  t.assert_eq("HEAD", git_calls[2].args[2], "reset target")
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
      get_current_entry = function()
        return current
      end,
    },
  }

  action.stage(ctx)
  current = { filepath = "preview-staged.txt", stage_type = "staged", status = "M" }
  action.unstage(ctx)

  t.assert_eq(2, #git_calls, "git calls")
  assert_git_call(git_calls[1], "add", "preview-unstaged.txt")
  assert_git_call(git_calls[2], "reset", "preview-staged.txt")
  t.assert_eq(2, refreshed, "refresh calls")
  vim.api.nvim_buf_delete(ctx.layout.changes_bufnr, { force = true })
  vim.api.nvim_buf_delete(sbs_bufnr, { force = true })
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
