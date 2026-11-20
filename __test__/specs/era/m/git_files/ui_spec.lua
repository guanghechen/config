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
  expect("<Esc>]p", {
    focus = "staged",
    mode = "n",
    active = "staged",
    marks = { staged = marker, unstaged = "─" },
  }, "entering a tree makes it the most recently used tree")
  expect("<C-a>k", { focus = "input", mode = "n", active = "staged" }, "the input keeps the empty tree preferred")
  expect("<CR>", { focus = "unstaged", active = "unstaged" }, "Enter resolves the target the same way")
  t.assert_eq(0, #ui:lua("return errors"))
end)

---A widget on 60 untracked files, whose Unstaged tree is taller than its window, with `unstaged()` in the child: that
---window's topline and cursor, whether the tree's state and the pane's current line have both taken the cursor, and
---whether the input has the focus.
---@param setup                         ?string Lua the child runs before the widget opens.
---@return __test__.support.UI
---@return table grid
local function tall_unstaged(setup)
  local files = {} ---@type table<string, string[]>
  for index = 1, 60 do
    files[string.format("many/file%02d.lua", index)] = { "new" }
  end
  local ui, grid = support.surface(t, 140, 42, support.changes(t, {}, files))
  ui:lua((setup or "") .. [[
    open()
    function unstaged()
      local pane = widget.panes.unstaged
      local winnr = pane.result:get_winnr()
      local cursor = vim.api.nvim_win_get_cursor(winnr)[1]
      local status = pane.tree.view:status()
      return {
        topline = vim.fn.getwininfo(winnr)[1].topline,
        cursor = cursor,
        settled = not status.preparing and status.frame.cursor_row == cursor and pane.result.lnum_current:snapshot() == cursor,
        input = widget.input:isfocused(),
      }
    end
  ]])
  return ui, grid
end

---Waits until `check` accepts `unstaged()`, failing with the last one it saw.
---@param ui                            __test__.support.UI
---@param check                         fun(state: table): boolean
---@param message                       string
---@return table
local function wait_unstaged(ui, check, message)
  local state
  local ok = pcall(ui.wait_until, ui, function()
    state = ui:lua("return unstaged()")
    return check(state)
  end, 5000)
  t.assert_true(ok, message .. ": " .. vim.inspect(state))
  return state
end

t:test("the mouse wheel scrolls a tree under it while the input keeps focus", function()
  local ui, grid = tall_unstaged()
  ui:rpc("nvim_command", "redraw")
  local window = ui:lua("return vim.fn.getwininfo(widget.panes.unstaged.result:get_winnr())[1]")
  ---@return nil
  local function step()
    ui:rpc("nvim_input_mouse", "wheel", "down", "", 0, window.winrow + 2, window.wincol + 4)
    ui:rpc("nvim_eval", "0")
  end

  -- With the tree publishing nothing, the pane's current line alone must follow the cursor the wheel moved; left
  -- behind, it would move the cursor back.
  ui:lua([[
    local surface = require("ux.treeview.surface")
    local request, held = surface.request, widget.panes.unstaged.tree.view
    hold = true
    surface.request = function(view, ...)
      if not hold or view ~= held then
        return request(view, ...)
      end
    end
  ]])
  step()
  ui:wait_lua("return unstaged().topline == 4", 5000, "the first step scrolls three lines")
  local held = ui:lua("return unstaged()")
  t.assert_eq(held.cursor, ui:lua("return widget.panes.unstaged.result.lnum_current:snapshot()"))
  ui:lua("hold = false")

  -- One step at a time, as a wheel turns: publications of earlier steps can land between later ones.
  for _ = 2, 4 do
    step()
  end
  local state = wait_unstaged(ui, function(state)
    return state.topline == 13 and state.settled
  end, "four wheel steps of three lines stay scrolled")
  t.assert_true(state.input, "the input keeps focus")
  t.wait_until(function()
    return border_text(grid, "Unstaged"):find(string.format(" %d / 61 ", state.cursor), 1, true) ~= nil
  end, 5000, "the border counts the row the wheel moved the cursor to")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test("the input moves a tall target tree by jumps that its state follows, with smooth scrolling on", function()
  -- Smooth scrolling animates the windows a program scrolls, unless a Treeview View owns the cursor there.
  local ui = tall_unstaged("era.dressing.scroll.dressing()\n")
  for _, case in ipairs({ { "G", 61 }, { "gg", 1 }, { "40j", 41 } }) do
    ui:rpc("nvim_input", case[1])
    wait_unstaged(ui, function(state)
      return state.cursor == case[2] and state.settled
    end, string.format("%s moves the tree to row %d", case[1], case[2]))
  end
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test("<Tab> toggles the selection at the cursor of a tree, or of the target tree from the input", function()
  local root = support.changes(t, {
    ["dir/mixed.lua"] = { "one", "two", "three", "staged" },
    ["dir/second.lua"] = { "base", "staged" },
  }, { ["outside.lua"] = { "base", "unstaged" } })
  local ui = support.surface(t, 140, 42, root)
  ui:lua([[
    open()
    function selected(scope)
      local tree = widget.panes[scope].tree
      local rows = {}
      for _, key in ipairs(tree:selected_keys(false, tree:frame())) do
        rows[#rows + 1] = tree:retrieve_lnum(key)
      end
      table.sort(rows)
      return rows
    end
  ]])

  ---@param keys                        string
  ---@param rows                        integer[] Selected rows of Staged.
  ---@param message                     string
  ---@return nil
  local function expect(keys, rows, message)
    ui:rpc("nvim_input", keys)
    local actual
    local ok = pcall(ui.wait_until, ui, function()
      actual = ui:lua("return selected('staged')")
      return vim.deep_equal(actual, rows)
    end, 5000)
    t.assert_true(ok, message .. ": " .. vim.inspect(actual))
  end

  expect("<Tab>", { 1 }, "the input toggles the row of its target tree")
  expect("<Tab>", {}, "and back")
  expect("i<Tab>", { 1 }, "from Insert mode too")
  t.assert_eq("i", ui:lua("return vim.api.nvim_get_mode().mode"), "the input stays in Insert mode")
  expect("<Esc>]pj<Tab>", { 1, 2 }, "a tree toggles its current row")
  expect("<Tab>", { 1 }, "and back")
  expect("Vj<Tab>", { 1, 2, 3 }, "and a Visual range")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test("<Tab> in the preview and <S-Tab> in the Insert mode input do nothing", function()
  local root = support.changes(t, { ["dir/mixed.lua"] = { "one", "two", "three", "staged" } }, {})
  local ui = support.surface(t, 140, 42, root)
  -- The global <Tab> jumps back, here to a buffer the fixed preview window cannot show.
  ui:lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two" })
    vim.cmd("normal! G")
    open()
    vim.v.errmsg = ""
  ]])
  ui:rpc("nvim_input", "<C-a>l")
  ui:wait_lua("return widget.preview.surface:isfocused()", 5000)
  ui:rpc("nvim_input", "<Tab><C-a>hi<S-Tab>x")
  ui:wait_lua("return widget.input:isfocused() and vim.api.nvim_get_current_line() ~= ''", 5000, "the input took x")
  t.assert_eq("x", ui:lua("return vim.api.nvim_get_current_line()"), "<S-Tab> leaves the query")
  t.assert_eq("", ui:lua("return vim.v.errmsg"), "<Tab> leaves the preview buffer")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test("z; leaves the input and the most recently used tree in the column, which follows tree switches", function()
  local root = support.changes(t, { ["dir/mixed.lua"] = { "one", "two", "three", "staged" } }, {
    ["outside.lua"] = { "base", "unstaged" },
  })
  local ui = support.surface(t, 140, 42, root)
  ui:lua([[
    stl.env.IS_TMUX = false
    open()
    function column()
      local function window(winnr)
        local config = vim.api.nvim_win_get_config(winnr)
        return { row = config.row, height = config.height, hide = config.hide, focusable = config.focusable }
      end
      local state = {
        focus = widget.input:isfocused() and "input" or "preview",
        active = widget._active,
        input = window(widget.input:get_winnr()),
        preview = window(widget.preview.surface:get_winnr()),
      }
      for scope, pane in pairs(widget.panes) do
        state.focus = pane.result:isfocused() and scope or state.focus
        state[scope] = window(pane.result:get_winnr())
      end
      return state
    end
  ]])

  ---@param keys                        string
  ---@param check                       fun(state: table): boolean
  ---@param message                     string
  ---@return table
  local function expect(keys, check, message)
    if keys ~= "" then
      ui:rpc("nvim_input", keys)
    end
    local state
    local ok = pcall(ui.wait_until, ui, function()
      state = ui:lua("return column()")
      return check(state)
    end, 5000)
    t.assert_true(ok, message .. "\n" .. vim.inspect(state))
    return state
  end

  ---@param shown                       era.view.git_files.Scope
  ---@return fun(state: table): boolean
  local function immersive(shown)
    local hidden = shown == "staged" and "unstaged" or "staged"
    return function(state)
      local tree = state[shown]
      return not tree.hide
        and tree.focusable
        and state[hidden].hide
        and not state[hidden].focusable
        and tree.row == state.input.row + 2
        and tree.row + tree.height == state.preview.row + state.preview.height
    end
  end

  local split = expect("", function(state)
    return state.focus == "input" and not state.staged.hide and not state.unstaged.hide
  end, "both trees show at first")
  expect("z;", immersive("staged"), "z; in the input shows the input over the most recently used tree only")
  expect("<C-a>j", function(state)
    return state.focus == "staged" and immersive("staged")(state)
  end, "the column below the input holds the shown tree")
  expect("<C-a>j", function(state)
    return state.focus == "input"
  end, "the shown tree is the bottom of the column")
  expect("[p", function(state)
    return state.focus == "unstaged" and state.active == "unstaged" and immersive("unstaged")(state)
  end, "entering the other tree shows it in place of the first")
  expect("<C-a>k<C-a>j", function(state)
    return state.focus == "unstaged"
  end, "the input leads back down to the shown tree")
  expect("z;", function(state)
    return state.focus == "unstaged"
      and vim.deep_equal(state.staged, split.staged)
      and vim.deep_equal(state.unstaged, split.unstaged)
  end, "z; in a tree shows both trees again")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test("Insert mode stays in the input: entering a tree ends it, and closing leaves none behind", function()
  local root = support.changes(t, { ["a.lua"] = { "a" } }, { ["a.lua"] = { "a", "b" } })
  local ui = support.surface(t, 140, 42, root)
  ui:lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = 1" })
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    source_winnr = vim.api.nvim_get_current_win()
    open()
  ]])
  ---@return { mode: string, source: boolean, cursor: integer[] }
  local function state()
    return ui:lua([[return {
      mode = vim.api.nvim_get_mode().mode,
      source = vim.api.nvim_get_current_win() == source_winnr,
      cursor = vim.api.nvim_win_get_cursor(source_winnr),
    }]])
  end
  ---@return nil
  local function insert()
    ui:rpc("nvim_input", "i")
    ui:wait_lua("return vim.api.nvim_get_mode().mode == 'i'", 5000, "Insert mode in the input")
  end

  insert()
  ui:rpc("nvim_command", "redraw")
  local window = ui:lua("return vim.fn.getwininfo(widget.panes.unstaged.result:get_winnr())[1]")
  ui:rpc("nvim_input_mouse", "left", "press", "", 0, window.winrow, window.wincol + 4)
  ui:rpc("nvim_input_mouse", "left", "release", "", 0, window.winrow, window.wincol + 4)
  ui:wait_lua(
    "return vim.api.nvim_get_current_win() == widget.panes.unstaged.result:get_winnr()",
    5000,
    "the click focuses the tree"
  )
  t.assert_eq("n", state().mode, "the tree takes the click in Normal mode")
  ui:rpc("nvim_input", "q")
  ui:wait_lua("return vim.api.nvim_get_current_win() == source_winnr", 5000, "q returns to the source window")
  t.assert_same({ mode = "n", source = true, cursor = { 1, 6 } }, state())

  ui:lua("widget:toggle(); support.ready(widget)")
  insert()
  ui:rpc("nvim_input", "<C-c>")
  ui:wait_lua("return vim.api.nvim_get_current_win() == source_winnr", 5000, "<C-c> returns to the source window")
  t.assert_same({ mode = "n", source = true, cursor = { 1, 6 } }, state(), "the cursor does not step back")

  -- i_CTRL-O holds Insert mode while its command runs and resumes it after.
  ui:lua("widget:toggle(); support.ready(widget)")
  insert()
  ui:rpc("nvim_input", "<C-\\><C-o>q")
  ui:wait_lua("return vim.api.nvim_get_current_win() == source_winnr", 5000, "i_CTRL-O q returns to the source window")
  t.assert_same({ mode = "n", source = true, cursor = { 1, 6 } }, state(), "the held Insert mode does not resume")
  ui:lua("widget:toggle(); support.ready(widget); widget:focus('unstaged'); widget:focus('input')")
  insert()
  ui:rpc("nvim_input", "<C-\\><C-o><C-w>p")
  ui:wait_lua(
    "return vim.api.nvim_get_current_win() == widget.panes.unstaged.result:get_winnr()",
    5000,
    "i_CTRL-O <C-w>p focuses the tree"
  )
  t.assert_eq("n", state().mode, "the held Insert mode does not resume in the tree")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:run()
