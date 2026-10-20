require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local support = require("__test__.support.git_files")
local treeview = require("__test__.support.treeview")
local git = require("__test__.support.git")
local Paths = require("era.view.result_paths")

---@return table
local function fixture()
  local root = support.repo(t)
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged" })
  git.run(root, { "add", "dir/mixed.lua" })
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged", "unstaged" })
  support.write(root, "dir/second.lua", { "base", "second" })
  local state = support.widget(t, root)
  state.widget._foldempty = false
  state.widget:toggle()
  support.ready(state.widget)
  return state
end

t:test("both trees have independent floating windows and retain roots and folds on reopening", function()
  local state = fixture()
  local widget = state.widget
  local staged, unstaged = widget.panes.staged, widget.panes.unstaged
  t.assert_true(staged.result:get_winnr() ~= unstaged.result:get_winnr())
  t.assert_eq("editor", vim.api.nvim_win_get_config(staged.result:get_winnr()).relative)
  t.assert_eq("editor", vim.api.nvim_win_get_config(unstaged.result:get_winnr()).relative)
  support.cursor(widget, "unstaged", "dir")
  widget:root("cursor")
  t.await(unstaged.result.draw())
  t.assert_eq(Paths.key(state.root .. "/dir"), unstaged.tree:root_key())
  t.assert_eq(Paths.key(state.root), staged.tree:root_key())
  staged.tree:collapse(Paths.key(state.root .. "/dir"), "collapse")
  t.await(staged.tree:ready())
  widget:hide()
  widget:toggle()
  support.ready(widget)
  t.assert_eq(Paths.key(state.root .. "/dir"), unstaged.tree:root_key())
  t.assert_true(staged.tree:retrieve(Paths.key(state.root .. "/dir")).collapsed)
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:test("directory staging respects the active filter and leaves other unstaged files alone", function()
  local state = fixture()
  local widget = state.widget
  widget._query = "mixed"
  for _, pane in pairs(widget.panes) do
    t.await(pane.result.draw())
  end
  support.cursor(widget, "unstaged", "dir")
  t.await(assert(widget:transfer("unstaged")))
  support.ready(widget)
  t.assert_eq("dir/mixed.lua\n", git.run(state.root, { "diff", "--cached", "--name-only" }))
  t.assert_eq("dir/second.lua\n", git.run(state.root, { "diff", "--name-only" }))
  t.assert_true(git.run(state.root, { "show", ":dir/mixed.lua" }):find("unstaged", 1, true) ~= nil)
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:test("marked files transfer together and source exhaustion moves focus to the other pane", function()
  local state = fixture()
  local widget, pane = state.widget, state.widget.panes.unstaged
  for _, path in ipairs({ "dir/mixed.lua", "dir/second.lua" }) do
    pane.tree:toggle_select(Paths.key(state.root .. "/" .. path), true)
  end
  t.await(pane.tree:ready())
  widget:focus("unstaged")
  t.await(assert(widget:transfer("unstaged")))
  support.ready(widget)
  t.assert_eq("", git.run(state.root, { "diff", "--name-only" }))
  t.assert_eq(0, pane.tree.totals.count)
  t.assert_eq(2, widget.panes.staged.tree.totals.count)
  t.assert_true(widget.panes.staged.result:isfocused())
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:test("a Visual range stages all selected rows", function()
  local state = fixture()
  local widget = state.widget
  support.cursor(widget, "unstaged", "dir/mixed.lua")
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end)
  t.await(assert(widget:transfer("unstaged")))
  support.ready(widget)
  t.assert_eq("", git.run(state.root, { "diff", "--name-only" }))
  t.assert_eq(2, widget.panes.staged.tree.totals.count)
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:test("copy uses displayed paths for a Visual range and does not modify Git", function()
  local state = fixture()
  local widget = state.widget
  local copied
  t:patch_table(era.fn, "select_copy_filepaths", function(options)
    copied = options.filepaths
  end)
  local before = git.run(state.root, { "ls-files", "--stage", "-z" })
  support.cursor(widget, "unstaged", "dir/mixed.lua")
  vim.cmd.normal({ args = { "Vj" }, bang = true })
  t:defer(function()
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end)
  t.await(assert(widget:copy_paths()))
  t.assert_eq(2, #copied)
  t.assert_eq(state.root .. "/dir/mixed.lua", copied[1])
  t.assert_eq(state.root .. "/dir/second.lua", copied[2])
  t.assert_eq(before, git.run(state.root, { "ls-files", "--stage", "-z" }))
end)

t:test("open returns to the source window and a deleted file never opens an empty replacement", function()
  local state = fixture()
  local widget, opened = state.widget, {}
  t:patch_table(dot.win, "open_filepath", function(winnr, path)
    opened[#opened + 1] = { winnr, path }
  end)
  support.cursor(widget, "staged", "dir/mixed.lua")
  local origin = widget._origin
  widget:activate()
  t.assert_eq(1, #opened)
  t.assert_eq(origin, opened[1][1])
  t.assert_eq(state.root .. "/dir/mixed.lua", opened[1][2])
  t.assert_false(widget:isvisible())
  vim.fn.delete(state.root .. "/outside.lua")
  widget:toggle()
  support.ready(widget)
  support.cursor(widget, "unstaged", "outside.lua")
  widget:activate()
  t.assert_true(widget:isvisible())
  t.assert_eq(1, #opened)
  t.assert_eq(1, #state.warnings)
end)

t:test("untracked, empty and binary files get honest stats without changing the real index", function()
  local root = support.repo(t)
  support.write(root, "new.lua", { "one", "two", "three" })
  support.write(root, "empty.txt", {})
  local file = assert(io.open(root .. "/binary.dat", "wb"))
  file:write("a\0b\0c")
  file:close()
  local before = git.run(root, { "ls-files", "--stage", "-z" })
  local state = support.widget(t, root)
  state.widget:toggle()
  support.ready(state.widget)
  local tree = state.widget.panes.unstaged.tree
  local new = tree:retrieve(Paths.key(root .. "/new.lua")).git
  local empty = tree:retrieve(Paths.key(root .. "/empty.txt")).git
  local binary = tree:retrieve(Paths.key(root .. "/binary.dat")).git
  t.assert_eq(3, new.insertions)
  t.assert_eq(0, new.deletions)
  t.assert_eq(0, empty.insertions)
  t.assert_eq(1, binary.unknown)
  t.assert_nil(binary.insertions)
  t.assert_eq(before, git.run(root, { "ls-files", "--stage", "-z" }))
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:test("closing either tree window closes the entire widget", function()
  local state = fixture()
  local winnr = state.widget.panes.staged.result:get_winnr()
  vim.api.nvim_win_close(winnr, true)
  t.assert_false(state.widget:isvisible())
  state.widget:toggle()
  support.ready(state.widget)
  t.assert_true(state.widget.panes.staged.result:isvisible())
  t.assert_true(state.widget.panes.unstaged.result:isvisible())
end)

t:test("the single-line input survives reopening and closing it closes every pane", function()
  local state = fixture()
  local widget = state.widget
  local bufnr = assert(widget.input:get_bufnr())
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "mixed", "path" })
  widget:hide()
  t.assert_eq("mixed path", widget._query, "closing commits the latest input before TextChanged")
  t.assert_eq(1, vim.api.nvim_buf_line_count(bufnr))
  widget:toggle()
  support.ready(widget)
  t.assert_eq("mixed path", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
  t.assert_eq(1, vim.api.nvim_win_get_height(widget.input:get_winnr()))
  widget.input:set_content("mixed")
  for _, pane in pairs(widget.panes) do
    t.await(pane.result.draw())
  end
  t.assert_true(widget.panes.staged.tree:linecount() > 0)
  t.assert_true(widget.panes.unstaged.tree:linecount() > 0)
  vim.api.nvim_win_close(widget.input:get_winnr(), true)
  t.assert_false(widget:isvisible())
  t.assert_false(widget.panes.staged.result:isvisible())
  t.assert_false(widget.panes.unstaged.result:isvisible())
  t.assert_false(widget.preview.surface:isvisible())
end)

t:test("expansion keys typed ahead act on the tree their earlier keys produce", function()
  local state = fixture()
  local widget = state.widget
  local tree = widget.panes.unstaged.tree
  local dir = Paths.key(state.root .. "/dir")
  support.cursor(widget, "unstaged", "dir")
  local winnr = assert(widget.panes.unstaged.result:get_winnr())
  local row = vim.api.nvim_win_get_cursor(winnr)[1]
  ---@param keys                        string
  ---@return fun()
  local function feed(keys)
    -- Feeding with "x" runs every key before the event loop can publish the change of an earlier key.
    return function()
      vim.api.nvim_feedkeys(keys, "x", false)
    end
  end
  ---@param sequence                    string
  ---@return nil
  local function settled(sequence)
    support.ready(widget)
    t.assert_eq(row, vim.api.nvim_win_get_cursor(winnr)[1], sequence .. " keeps the cursor on dir")
  end
  treeview.assert_typed_ahead(t, tree, dir, feed("l"), feed("h"), settled)
  -- "zh" collapses as well, through its own mapping.
  feed("zh")()
  t.wait_until(function()
    return not tree:collapse_pending() and not tree:expanded(dir)
  end, 5000, "zh must leave dir collapsed")
  settled("zh")
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:run()
