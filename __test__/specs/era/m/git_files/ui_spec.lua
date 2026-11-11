require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local support = require("__test__.support.git_files")
local git = require("__test__.support.git")
local border_text = support.border_text

t:test("input and two ordered trees share one full-height preview inside one outer frame", function()
  local root = support.changes(t, { ["dir/mixed.lua"] = { "one", "two", "three", "staged-line" } }, {
    ["dir/mixed.lua"] = { "one", "two", "three", "staged-line", "unstaged-line" },
  })
  local ui, grid = support.surface(t, 140, 42, root)
  ui:lua([[
    open()
    support.cursor(widget, "unstaged", "dir/mixed.lua")
  ]])
  local layout = ui:lua([[
    return {
      input=vim.api.nvim_win_get_config(widget.input:get_winnr()),
      staged=vim.api.nvim_win_get_config(widget.panes.staged.result:get_winnr()),
      unstaged=vim.api.nvim_win_get_config(widget.panes.unstaged.result:get_winnr()),
      preview=vim.api.nvim_win_get_config(widget.preview.surface:get_winnr()),
    }
  ]])
  t.assert_eq(1, layout.input.height)
  t.assert_eq(layout.input.col, layout.staged.col)
  t.assert_eq(layout.input.col, layout.unstaged.col)
  t.assert_eq(layout.input.row + layout.input.height + 1, layout.staged.row, "input and Staged share one separator")
  t.assert_eq(layout.staged.row + layout.staged.height + 1, layout.unstaged.row, "the trees share one separator")
  t.assert_eq(layout.input.row, layout.preview.row)
  t.assert_eq(layout.unstaged.row + layout.unstaged.height, layout.preview.row + layout.preview.height)
  t.assert_true(layout.preview.col > layout.input.col + layout.input.width)
  local doubled = false
  t.wait_until(function()
    local top, bottom = false, false
    doubled = false
    for _, screen in pairs(grid.grids) do
      for _, cells in ipairs(screen.rows) do
        for col, cell in ipairs(cells) do
          top = top or cell[1] == "┬"
          bottom = bottom or cell[1] == "┴"
          if cell[1] == "│" and cells[col + 1] and cells[col + 1][1] == "│" then
            doubled = true
          end
        end
      end
    end
    return top and bottom
  end, 5000, "one outer frame joins the two columns")
  t.assert_false(doubled, "the columns share a single vertical border")
  t.assert_nil(grid:find("C-a hjkl panes"), "footer hints are not displayed")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test("live search filters both trees and picker keys stage, unstage and copy the current file", function()
  local root = support.changes(t, { ["dir/mixed.lua"] = { "one", "two", "three", "staged-line" } }, {
    ["dir/mixed.lua"] = { "one", "two", "three", "staged-line", "unstaged-line" },
  })
  local ui, grid = support.surface(t, 140, 42, root)
  ui:lua([[
    era.fn.select_copy_filepaths = function(options) copied = options.filepaths end
    open()
    support.cursor(widget, "unstaged", "dir/mixed.lua")
  ]])
  ui:rpc("nvim_input", "/zznotfound")
  ui:wait_lua(
    "return widget._query == 'zznotfound' and widget.panes.staged.tree:linecount() == 0 and widget.panes.unstaged.tree:linecount() == 0",
    5000,
    "typing in the persistent input filters both trees"
  )
  t.wait_until(function()
    return border_text(grid, "Staged"):find("0 / 0", 1, true) and border_text(grid, "Unstaged"):find("0 / 0", 1, true)
  end, 5000, "empty filtered trees show zero positions in their borders")
  ui:rpc("nvim_input", "<C-u>mixed")
  ui:wait_lua(
    "return widget._query == 'mixed' and widget.panes.staged.tree:linecount() > 0 and widget.panes.unstaged.tree:linecount() > 0",
    5000
  )
  ui:rpc("nvim_input", "<CR>")
  ui:wait_lua(
    "return widget.panes.unstaged.result:isfocused() and vim.api.nvim_get_mode().mode == 'n'",
    5000,
    "Enter leaves the input in Normal mode on the current tree"
  )
  ui:rpc("nvim_input", "gs")
  ui:wait_lua(
    "return widget._request == nil and widget.panes.unstaged.tree.totals.count == 0 and widget.panes.staged.result:isfocused()",
    5000,
    "stage key must move the file into the other tree"
  )
  t.assert_true(git.run(root, { "show", ":dir/mixed.lua" }):find("unstaged-line", 1, true) ~= nil)
  ui:rpc("nvim_input", "<C-a>j")
  ui:wait_lua("return widget.panes.unstaged.result:isfocused()", 5000)
  ui:rpc("nvim_input", "<C-a>kgu")
  ui:wait_lua(
    "return widget._request == nil and widget.panes.staged.tree.totals.count == 0 and widget.panes.unstaged.tree.totals.count == 1",
    5000,
    "unstage key must return the file to Unstaged"
  )
  t.assert_eq("", git.run(root, { "diff", "--cached", "--name-only" }))
  ui:lua("support.cursor(widget, 'unstaged', 'dir/mixed.lua')")
  ui:rpc("nvim_input", "oc")
  ui:wait_lua("local path = ...; return copied and copied[1] == path", 5000, nil, root .. "/dir/mixed.lua")
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return grid:find("staged-line") and grid:find("unstaged-line")
  end, 5000, "optional diff preview must show the current side")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test("pane navigation returns from the preview to its source pane and delegates outer edges to tmux", function()
  -- Staging and then unstaging dir/mixed.lua in full leaves only its unstaged side.
  local root = support.changes(t, {}, {
    ["dir/mixed.lua"] = { "one", "two", "three", "staged-line", "unstaged-line" },
  })
  local ui, grid = support.surface(t, 140, 42, root)
  ui:lua([[
    open()
    support.cursor(widget, "unstaged", "dir/mixed.lua")
  ]])
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return grid:find("staged-line") and grid:find("unstaged-line")
  end, 5000, "optional diff preview must show the current side")
  ui:rpc("nvim_input", "<C-a>l")
  ui:wait_lua("return widget.preview.surface:isfocused()", 5000)
  ui:rpc("nvim_input", "<D-h>")
  ui:wait_lua(
    "return widget.panes.unstaged.result:isfocused()",
    5000,
    "Cmd navigation returns to the tree that opened preview"
  )
  ui:rpc("nvim_input", "<M-k><M-l>")
  ui:wait_lua("return widget.preview.surface:isfocused() and widget._active == 'staged'", 5000)
  ui:rpc("nvim_input", "<C-a>h")
  ui:wait_lua("return widget.panes.staged.result:isfocused()", 5000, "preview remembers either source tree")
  ui:lua([[
    stl.env.IS_TMUX = true
    navigation_zen = false
    dot.state.status.tmux_zen_mode = { snapshot = function() return navigation_zen end }
    stl.tmux.change_pane = function(direction) moved = direction end
  ]])
  ui:rpc("nvim_input", "<C-a>j<C-a>j")
  ui:wait_lua(
    "return moved == 'j' and widget.panes.unstaged.result:isfocused()",
    5000,
    "the outer edge delegates to tmux"
  )
  ui:lua("navigation_zen = true; moved = nil")
  ui:rpc("nvim_input", "<C-a>j")
  ui:wait_lua(
    "return moved == nil and widget.input:isfocused()",
    5000,
    "zen mode wraps from the bottom tree to the input"
  )
  ui:rpc("nvim_input", "<C-a>l")
  ui:wait_lua("return widget.preview.surface:isfocused()", 5000)
  ui:rpc("nvim_input", "<C-a>h")
  ui:wait_lua("return widget.input:isfocused()", 5000, "preview can return to the input too")
  ui:rpc("nvim_input", "tp")
  ui:wait_lua("return not widget.preview.surface:isvisible()", 5000)
  ui:lua("navigation_zen = false")
  ui:rpc("nvim_input", "<M-l>")
  ui:wait_lua("return moved == 'l' and widget.input:isfocused()", 5000, "hidden preview is not a navigation target")
  ui:rpc("nvim_input", "q")
  ui:wait_lua("return not widget:isvisible()", 5000)
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test(
  "inline preview shows source gutters, full-line and word highlights with fixed numbers while scrolling",
  function()
    local root = support.changes(t, {
      ["dir/mixed.lua"] = { "local prefix = 1", 'local value = "old-旧值"', "print(value)" },
    }, {
      ["dir/mixed.lua"] = {
        "local prefix = 1",
        'local value = "new-新值"',
        "print(value)",
        'local long = "' .. string.rep("a", 110) .. 'TAIL_END"',
        'local message = "你好"',
      },
    })
    local ui, grid = support.surface(t, 140, 42, root)
    ui:lua([[
    vim.api.nvim_set_hl(0, "DiffDelRight", { bg=0x332222 })
    vim.api.nvim_set_hl(0, "DiffAddRight", { bg=0x223322 })
    vim.api.nvim_set_hl(0, "DiffWordLeft", { bg=0x992222 })
    vim.api.nvim_set_hl(0, "DiffWordRight", { bg=0x229922 })
    vim.api.nvim_set_hl(0, "m_gf_diff_del_nr", { fg=0x999999, bg=0x332222 })
    vim.api.nvim_set_hl(0, "m_gf_diff_add_nr", { fg=0x999999, bg=0x223322 })
    vim.api.nvim_set_hl(0, "m_gf_diff_hunk", { fg=0x999999, bg=0x223344 })
    open()
    support.cursor(widget, "unstaged", "dir/mixed.lua")
  ]])
    t.wait_until(function()
      return grid:find('local value = "old-') and grid:find('local value = "new-') and grid:find("print(value)")
    end, 5000, "inline code rows reach the UI")
    local removed, added = grid:find('local value = "old-'), grid:find('local value = "new-')
    t.assert_eq(0x332222, removed.highlight.background, "deletions have a full-line background")
    t.assert_eq(0x223322, added.highlight.background, "additions have a full-line background")
    t.assert_eq(0x992222, grid:find("old-").highlight.background, "deleted words have stronger emphasis")
    t.assert_eq(0x229922, grid:find("new-").highlight.background, "added words have stronger emphasis")

    ---@param at                          table
    ---@return string
    local function gutter(at)
      return grid:row_text(at, removed.col - 8, removed.col)
    end
    t.assert_eq("  2    - ", gutter(removed), "deletions show only the old line number")
    t.assert_eq("     2 + ", gutter(added), "additions show only the new line number")
    t.assert_eq("  3  3   ", gutter(grid:find("print(value)")), "context shows both source line numbers")
    for _, at in ipairs({ removed, added, assert(grid:find("@@ -1,3 +1,5 @@")) }) do
      local cells = grid:row_cells(at)
      for col = removed.col - 8, removed.col do
        t.assert_eq(
          at.highlight.background,
          grid.highlights[cells[col][2]].background,
          "background joins gutter and code"
        )
      end
    end
    t.assert_eq(0x223344, grid:find("@@ -1,3 +1,5 @@").highlight.background, "each hunk has its own header band")

    local state = ui:lua([[
    local bufnr = widget.preview.surface:get_bufnr()
    return {
      lines=vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
      readonly=vim.api.nvim_get_option_value("readonly", { buf=bufnr }),
      modifiable=vim.api.nvim_get_option_value("modifiable", { buf=bufnr }),
    }
  ]])
    t.assert_true(vim.tbl_contains(state.lines, 'local value = "old-旧值"'))
    t.assert_true(vim.tbl_contains(state.lines, 'local value = "new-新值"'))
    t.assert_false(table.concat(state.lines):find("diff --git", 1, true) ~= nil)
    t.assert_true(state.readonly)
    t.assert_false(state.modifiable)
    ui:lua([[
    widget.preview.surface:focus()
    vim.api.nvim_win_call(widget.preview.surface:get_winnr(), function()
      vim.fn.winrestview({ lnum=6, col=120, topline=1, leftcol=100 })
    end)
    vim.cmd.redraw()
  ]])
    t.wait_until(function()
      return grid:find("TAIL_END")
    end, 5000, "long source lines can scroll horizontally")
    t.assert_eq("     4 + ", gutter(grid:find("TAIL_END")), "source numbers remain fixed during horizontal scrolling")
    t.assert_eq(0, #ui:lua("return errors"))
  end
)

t:test("the input drives its target tree in Normal and Insert modes while the border marks it", function()
  local root = support.changes(t, {
    ["dir/mixed.lua"] = { "one", "two", "three", "staged" },
    ["dir/second.lua"] = { "base", "staged" },
  }, { ["outside.lua"] = { "base", "unstaged" } })
  local ui = support.surface(t, 140, 42, root)
  ui:lua([[
    open()
    function probe()
      local state = { focus = widget.input:isfocused() and "input" or nil, rows = {}, counts = {}, marks = {} }
      for scope, pane in pairs(widget.panes) do
        local winnr = pane.result:get_winnr()
        state.focus = pane.result:isfocused() and scope or state.focus
        state.rows[scope] = vim.api.nvim_win_get_cursor(winnr)[1]
        state.counts[scope] = pane.tree:linecount()
        state.marks[scope] = vim.api.nvim_win_get_config(winnr).title[1][1]
      end
      local entry = widget.preview._entry
      state.active, state.mode, state.query = widget._active, vim.api.nvim_get_mode().mode, widget._query
      state.preview = entry and entry.scope .. ":" .. entry.path or ""
      return state
    end
  ]])
  local marker = stl.icon.ui.ArrowPresent

  ---@param keys                        string
  ---@param expected                    table
  ---@param message                     string
  ---@return nil
  local function expect(keys, expected, message)
    if keys ~= "" then
      ui:rpc("nvim_input", keys)
    end
    local actual
    local ok = pcall(ui.wait_until, ui, function()
      actual = ui:lua("return probe()")
      for field, value in pairs(expected) do
        if not vim.deep_equal(actual[field], value) then
          return false
        end
      end
      return true
    end, 5000)
    t.assert_true(ok, message .. "\n" .. vim.inspect(actual))
  end

  expect("", {
    focus = "input",
    mode = "n",
    active = "staged",
    counts = { staged = 3, unstaged = 1 },
    rows = { staged = 1, unstaged = 1 },
    marks = { staged = marker, unstaged = "─" },
  }, "opening focuses the input and marks Staged as its target")
  expect("j", {
    focus = "input",
    mode = "n",
    rows = { staged = 2, unstaged = 1 },
    preview = "staged:dir/mixed.lua",
  }, "j moves the target tree and the preview follows")
  expect(
    "5j",
    { rows = { staged = 3, unstaged = 1 }, preview = "staged:dir/second.lua" },
    "counts stop at the last row"
  )
  expect("5k", { rows = { staged = 1, unstaged = 1 } }, "counts stop at the first row")
  expect("G", { rows = { staged = 3, unstaged = 1 } }, "G moves to the last row")
  expect("2gg", { rows = { staged = 2, unstaged = 1 } }, "gg with a count moves to that row")
  expect("i<C-j>", { focus = "input", mode = "i", rows = { staged = 3, unstaged = 1 } }, "C-j moves in Insert mode")
  expect("<Up>", { mode = "i", rows = { staged = 2, unstaged = 1 } }, "Up moves in Insert mode")
  expect("<C-k>", { mode = "i", rows = { staged = 1, unstaged = 1 } }, "C-k moves in Insert mode")
  expect("<Down>", { mode = "i", rows = { staged = 2, unstaged = 1 } }, "Down moves in Insert mode")
  expect("jk", { mode = "i", query = "jk" }, "j and k still type in Insert mode")
  expect("<C-u>outside", { query = "outside", counts = { staged = 0, unstaged = 1 } }, "only Unstaged keeps rows")
  expect("<C-j>", {
    focus = "input",
    mode = "i",
    active = "unstaged",
    marks = { staged = "─", unstaged = marker },
    preview = "unstaged:outside.lua",
  }, "a target without visible rows falls back to the other tree")
  expect("<Tab>", {
    focus = "staged",
    mode = "n",
    active = "staged",
    marks = { staged = marker, unstaged = "─" },
  }, "entering a tree makes it the most recently used tree")
  expect("<C-a>k", { focus = "input", mode = "n", active = "staged" }, "the input keeps the empty tree preferred")
  expect("<CR>", { focus = "unstaged", active = "unstaged" }, "Enter resolves the target the same way")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:run()
