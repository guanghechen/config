---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/commits_reveal.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.commits_reveal")
local line_maps = {} ---@type table<integer, era.m.diffview.ICommitsLineMap[]>

local pane_commits = {
  apply_to_buffer = function(bufnr, result)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)
    line_maps[bufnr] = result.line_map
  end,
  apply_winopts = function() end,
  create_buffer = function()
    return vim.api.nvim_create_buf(false, true)
  end,
  find_commit_line = function(line_map, hash)
    for lnum, item in ipairs(line_map) do
      if item.type == "commit" and item.commit.hash == hash then
        return lnum
      end
    end
  end,
  find_file_line = function(line_map, hash, filepath)
    for lnum, item in ipairs(line_map) do
      if item.type == "file" and item.commit.hash == hash and item.entry and item.entry.filepath == filepath then
        return lnum
      end
    end
  end,
  get_line_map = function(bufnr)
    return line_maps[bufnr]
  end,
  render = function(commits, expanded)
    local lines = {} ---@type string[]
    local line_map = {} ---@type era.m.diffview.ICommitsLineMap[]
    for _, commit in ipairs(commits) do
      lines[#lines + 1] = commit.hash
      line_map[#line_map + 1] = { type = "commit", commit = commit }
      if expanded[commit.hash] then
        for _, entry in ipairs(commit.files or {}) do
          lines[#lines + 1] = entry.filepath
          line_map[#line_map + 1] = { type = "file", commit = commit, entry = entry }
        end
      end
    end
    return { lines = lines, highlights = {}, line_map = line_map }
  end,
}

t:patch_global("dot", {})
t:patch_global("era", {})
t:patch_global("stl", {})
t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_WIDTH = 20 })
t:patch_table(package.loaded, "era.m.diffview.data", {})
t:patch_table(package.loaded, "era.m.diffview.layout", {})
t:patch_table(package.loaded, "era.m.diffview.pane.commits", pane_commits)
t:patch_table(package.loaded, "era.m.diffview.pane.filetree", {})
t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
t:patch_table(package.loaded, "era.m.diffview.view.commits.keymap", {
  setup_commits = function() end,
})
t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {})

local view = assert(loadfile("lua/era/m/diffview/view/commits/view.lua"))()
t:patch_table(package.loaded, "era.m.diffview.view.commits.view", view)
local action = assert(loadfile("lua/era/m/diffview/view/commits/action.lua"))()

t:test("hide_commits keeps a commits-only tab alive", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage()
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local commits_winnr = vim.api.nvim_get_current_win()
  local commits_bufnr = pane_commits.create_buffer()
  vim.api.nvim_win_set_buf(commits_winnr, commits_bufnr)
  local lyt = {
    tabnr = tabnr,
    layout_type = 4,
    commits_winnr = commits_winnr,
    commits_bufnr = commits_bufnr,
  }

  view.hide_commits(lyt)

  t.assert_true(vim.api.nvim_tabpage_is_valid(tabnr), "commits-only tab")
  t.assert_true(vim.api.nvim_win_is_valid(commits_winnr), "last window")
  t.assert_eq(commits_winnr, lyt.commits_winnr, "layout reference")

  vim.cmd.tabclose()
  vim.api.nvim_set_current_tabpage(original_tabnr)
  if vim.api.nvim_buf_is_valid(commits_bufnr) then
    vim.api.nvim_buf_delete(commits_bufnr, { force = true })
  end
end)

t:test("reveal expands and focuses the active file, then hides Commits", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage()
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local sbs_winnr = vim.api.nvim_get_current_win()
  local entry = { filepath = "src/a.lua", status = "M" }
  local commit = { hash = "abc123", files = { entry } }
  local expanded = false
  local state = {
    get_commits = function()
      return { commit }
    end,
    get_current_commit = function()
      return commit
    end,
    get_current_entry = function()
      return entry
    end,
    get_expanded_commits = function()
      return expanded and { [commit.hash] = true } or {}
    end,
    is_commit_expanded = function()
      return expanded
    end,
    toggle_commit_expanded = function()
      expanded = not expanded
    end,
  }
  local lyt = {
    tabnr = tabnr,
    layout_type = 3,
    commits_winnr = nil,
    commits_bufnr = nil,
    sbs_left_winnr = sbs_winnr,
  }
  local ctx = { layout = lyt, state = state }

  action.reveal(ctx)
  local commits_winnr = assert(lyt.commits_winnr)
  local commits_bufnr = assert(lyt.commits_bufnr)
  t.assert_true(expanded, "active commit expanded")
  t.assert_eq(commits_winnr, vim.api.nvim_get_current_win(), "Commits focused")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(commits_winnr)[1], "active file cursor")

  action.reveal(ctx)
  t.assert_true(vim.api.nvim_tabpage_is_valid(tabnr), "tab remains valid")
  t.assert_nil(lyt.commits_winnr, "Commits hidden")
  t.assert_eq(sbs_winnr, vim.api.nvim_get_current_win(), "SBS retained")

  vim.cmd.tabclose()
  vim.api.nvim_set_current_tabpage(original_tabnr)
  if vim.api.nvim_buf_is_valid(commits_bufnr) then
    vim.api.nvim_buf_delete(commits_bufnr, { force = true })
  end
end)

t:run()
