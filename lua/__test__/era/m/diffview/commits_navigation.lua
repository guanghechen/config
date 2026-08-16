---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/commits_navigation.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.commits_navigation")
local ns = vim.api.nvim_create_namespace("era.m.diffview.commits_navigation.test")

bootstrap.with_global(t, "stl", {
  fileicon = {
    get_file_icon = function()
      return "F", "file_icon"
    end,
  },
  icon = {
    filetype = { FolderOpen = "D" },
    ui = { ArrowClosed = ">", ArrowOpen = "v" },
  },
})
bootstrap.with_global(t, "dot", {
  context = {
    diffview = {
      flag_foldempty = {
        snapshot = function()
          return false
        end,
      },
      flag_panel_viewtype = {
        snapshot = function()
          return "tree"
        end,
      },
    },
  },
})
t:patch_table(package.loaded, "era.m.diffview.config", {
  NS = ns,
  BUFOPTS_PANEL = {},
  WINOPTS_PANEL = {},
  FT = { COMMITS = "diffview-commits-test" },
})
t:patch_table(package.loaded, "era.m.diffview.util", {
  format_relative_time = function()
    return "now"
  end,
  get_status_hlgroup = function(status)
    return "status_" .. status
  end,
})

local commits = assert(loadfile("lua/era/m/diffview/pane/commits.lua"))()

local commit_a = {
  hash = "aaaaaaaa",
  abbrev_hash = "aaaa",
  author = "A",
  date = 0,
  message = "first",
  files = {
    { filepath = "src/a.lua", status = "M" },
    { filepath = "src/sub/b.lua", status = "A" },
    { filepath = "z.lua", status = "D" },
  },
}
local commit_b = {
  hash = "bbbbbbbb",
  abbrev_hash = "bbbb",
  author = "B",
  date = 0,
  message = "second",
  files = nil,
}

---@param viewtype stl.m.diffview.PanelViewTypeEnum
---@return era.m.diffview.IRenderResult
local function render(viewtype)
  return commits.render({ commit_a, commit_b }, { [commit_a.hash] = true }, {
    viewtype = viewtype,
    foldempty = false,
    layout = 2,
  })
end

t:test("render: projects nested TreeLayout navigation into buffer lines", function()
  local result = render("tree")
  local navigation = result.navigation ---@type era.m.diffview.ITreeNavigation

  t.assert_eq(7, #result.lines, "rendered line count")
  t.assert_eq(7, navigation.root_last_lnum, "last commit root")

  t.assert_eq(1, commits.resolve_parent_lnum(navigation, 2), "filetree root parent")
  t.assert_eq(2, commits.resolve_parent_lnum(navigation, 3), "nested directory parent")
  t.assert_eq(3, commits.resolve_parent_lnum(navigation, 4), "nested file parent")

  t.assert_eq(6, commits.resolve_last_child_or_sibling_lnum(navigation, 1), "commit last direct child")
  t.assert_eq(5, commits.resolve_last_child_or_sibling_lnum(navigation, 2), "directory last direct child")
  t.assert_eq(4, commits.resolve_last_child_or_sibling_lnum(navigation, 3), "single direct child")
  t.assert_nil(commits.resolve_last_child_or_sibling_lnum(navigation, 4), "last sibling is a no-op")
  t.assert_nil(commits.resolve_last_child_or_sibling_lnum(navigation, 7), "last root is a no-op")
end)

t:test("render: list rows retain the previous root-level navigation semantics", function()
  local result = render("list")
  local navigation = result.navigation ---@type era.m.diffview.ITreeNavigation

  t.assert_nil(commits.resolve_parent_lnum(navigation, 2), "list row has no tree parent")
  t.assert_eq(#result.lines, commits.resolve_last_child_or_sibling_lnum(navigation, 1), "list row scans to last root")
end)

t:test("apply: owns navigation with the commits buffer and cursor actions use it", function()
  local result = render("tree")
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)

  commits.apply_to_buffer(bufnr, result)
  t.assert_eq(7, commits.get_navigation(bufnr).root_last_lnum, "stored navigation")
  t.assert_true(rawequal(result.line_map, commits.get_line_map(bufnr)), "line map stays in Lua without copying")
  t.assert_true(rawequal(result.navigation, commits.get_navigation(bufnr)), "navigation stays in Lua without copying")

  vim.api.nvim_win_set_cursor(winnr, { 4, 0 })
  commits.goto_parent_node()
  t.assert_eq(3, vim.api.nvim_win_get_cursor(winnr)[1], "parent cursor target")

  vim.api.nvim_win_set_cursor(winnr, { 2, 0 })
  commits.goto_last_child_or_sibling()
  t.assert_eq(5, vim.api.nvim_win_get_cursor(winnr)[1], "last child cursor target")

  commits.apply_to_buffer(bufnr, { lines = {}, highlights = {}, line_map = {} })
  t.assert_eq(0, commits.get_navigation(bufnr).root_last_lnum, "cleared navigation")

  vim.api.nvim_win_set_buf(winnr, original_bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
  t.assert_nil(commits.get_navigation(bufnr), "wiped buffer releases navigation")
end)

t:test("apply: publishes render state before fallible decorations", function()
  local old_result = render("tree")
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  commits.apply_to_buffer(bufnr, old_result)

  local new_line_map = { { type = "commit", commit = commit_b, entry = nil } }
  local new_navigation = {
    parent_lnums = { 0 },
    last_child_lnums = { 0 },
    root_last_lnum = 1,
  } ---@type era.m.diffview.ITreeNavigation
  local restore_range = t:patch_table(vim.hl, "range", function()
    error("injected decoration failure")
  end)
  local ok = pcall(commits.apply_to_buffer, bufnr, {
    lines = { "new line" },
    highlights = { { lnum = 0, coll = 0, colr = 1, hlname = "test" } },
    line_map = new_line_map,
    navigation = new_navigation,
  })
  restore_range()

  t.assert_false(ok, "decoration failure propagates")
  t.assert_eq("new line", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1], "new lines remain applied")
  t.assert_true(rawequal(new_line_map, commits.get_line_map(bufnr)), "line map matches new lines")
  t.assert_true(rawequal(new_navigation, commits.get_navigation(bufnr)), "navigation matches new lines")

  vim.api.nvim_win_set_buf(winnr, original_bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("apply: cleanup registration fails before buffer mutation", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "original" })
  t:patch_table(vim.api, "nvim_create_autocmd", function()
    error("injected cleanup registration failure")
  end)

  local ok = pcall(commits.apply_to_buffer, bufnr, render("tree"))

  t.assert_false(ok, "cleanup registration failure propagates")
  t.assert_eq("original", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1], "buffer remains unchanged")
  t.assert_nil(commits.get_line_map(bufnr), "line map remains unpublished")
  t.assert_nil(commits.get_navigation(bufnr), "navigation remains unpublished")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
