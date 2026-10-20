require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local support = require("__test__.support.git_files")
local git = require("__test__.support.git")

---@param width                         integer
---@param height                        integer
---@return table
---@return table
local function surface(width, height)
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  local grid = require("__test__.support.ui_grid").new(ui)
  ui:start({ width = width, height = height, runtime = "ark" })
  ui:lua([[
    support = require("__test__.support.git_files")
    errors = {}
    stl.reporter.error = function(value) errors[#errors + 1] = value end
    era.m.git.state.refresh_index = function() return stl.c.Future.resolve() end
  ]])
  return ui, grid
end

---@param grid                          table
---@param label                         string
---@return string
local function border_text(grid, label)
  local title = grid:find(" " .. label)
  if not title then
    return ""
  end
  local cells = grid.grids[title.grid].rows[title.row + 1]
  local text = {}
  for _, cell in ipairs(cells) do
    text[#text + 1] = cell[1]
  end
  return table.concat(text)
end

t:test("both panes render side-specific colored counts over CJK paths and resize without body writes", function()
  local ui, grid = surface(120, 40)
  ui:lua([[
    dot.path.workspace = function() return "/git" end
    dot.path.is_git_repo = function() return true end
    local paths = { "/git/long-很长的文件名_很长的文件名_很长的文件名.lua" }
    for index = 1, 1000 do paths[#paths+1] = string.format("/git/z%04d.lua", index) end
    local data = { status_map = {}, numstats = { staged = {}, unstaged = {} } }
    for _, path in ipairs(paths) do
      local relative = path:sub(6)
      data.status_map[path] = { relative = relative, staged = { M = true }, unstaged = { M = true } }
      data.numstats.staged[relative] = { insertions = 12, deletions = 3 }
      data.numstats.unstaged[relative] = { insertions = 4, deletions = 1 }
    end
    era.m.git.status.collect = function()
      return stl.c.Future.resolve({ export = function() return data end, changed_files = function() return paths, paths end })
    end
    vim.api.nvim_set_hl(0, "m_ft_git_add", {fg=0x22cc44})
    vim.api.nvim_set_hl(0, "m_ft_git_delete", {fg=0xee3344})
    vim.api.nvim_set_hl(0, "m_ft_git_staged", {fg=0x55bbff})
    vim.api.nvim_set_hl(0, "m_ft_git_unstaged", {fg=0xcccc44})
    marks, writes = 0, 0
    local extmark, set_lines = vim.api.nvim_buf_set_extmark, vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_extmark = function(bufnr, ns, row, col, options)
      if options.ephemeral and options.virt_text_pos == "right_align" then marks=marks+1 end
      return extmark(bufnr, ns, row, col, options)
    end
    vim.api.nvim_buf_set_lines = function(...) writes=writes+1; return set_lines(...) end
    widget = require("era.m.git_files").new()
    widget._preview_enabled = false
    widget:toggle()
    support.ready(widget)
  ]])
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return grid:find("Unstaged")
      and grid:find("Staged")
      and grid:find("+12    -3 M")
      and grid:find("+4    -1 M")
      and grid:find("long-")
      and border_text(grid, "Staged"):find("1 / 1001", 1, true)
      and border_text(grid, "Unstaged"):find("1 / 1001", 1, true)
  end, 5000, "both Git trees and their counts must reach the UI")
  local staged, unstaged = grid:find("+12    -3 M"), grid:find("+4    -1 M")
  t.assert_eq(0x22cc44, staged.highlight.foreground)
  local row = grid.grids[staged.grid].rows[staged.row + 1]
  t.assert_eq(0xee3344, grid.highlights[row[staged.col + 8][2]].foreground)
  t.assert_eq(0x55bbff, grid.highlights[row[staged.col + 11][2]].foreground)
  row = grid.grids[unstaged.grid].rows[unstaged.row + 1]
  t.assert_eq(0xcccc44, grid.highlights[row[unstaged.col + 10][2]].foreground)
  local state = ui:lua([[
    local lines = vim.api.nvim_buf_get_lines(widget.panes.staged.tree.view.bufnr, 0, -1, false)
    local winbars = {}
    for _, pane in pairs(widget.panes) do
      winbars[#winbars + 1] = vim.api.nvim_get_option_value("winbar", { win=pane.result:get_winnr() })
    end
    return { marks=marks, errors=errors, pure=not table.concat(lines):find("+12", 1, true), winbars=winbars }
  ]])
  t.assert_true(state.marks > 0 and state.marks < 1000, "only viewport rows receive status decorations")
  t.assert_true(state.pure, "stats and status must stay out of path/body text")
  for _, winbar in ipairs(state.winbars) do
    t.assert_eq("", winbar, "tree content starts directly below the border")
  end
  t.assert_eq(0, #state.errors, vim.inspect(state.errors))
  ui:lua("widget.panes.staged.result:set_lnum_current(2)")
  t.wait_until(function()
    return border_text(grid, "Staged"):find("2 / 1001", 1, true)
      and border_text(grid, "Unstaged"):find("1 / 1001", 1, true)
  end, 1000, "each border follows its own cursor")
  ui:lua("writes=0")
  ui:rpc("nvim_ui_try_resize", 90, 30)
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return grid:find("+12    -3 M") and grid:find("+4    -1 M")
  end, 5000)
  t.assert_eq(0, ui:lua("return writes"), "resizing must only repaint decorations")
  ui:rpc("nvim_ui_try_resize", 42, 30)
  t.wait_until(function()
    return border_text(grid, "Staged"):find(" 2 / 1001 ┤", 1, true)
      and border_text(grid, "Unstaged"):find(" 1 / 1001 ┤", 1, true)
  end, 1000, "narrow borders reserve the right edge for position counts")
end)

t:test("input and two ordered trees share one full-height preview with live search and picker navigation", function()
  local root = support.repo(t)
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged-line" })
  git.run(root, { "add", "dir/mixed.lua" })
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged-line", "unstaged-line" })
  local ui, grid = surface(140, 42)
  ui:lua(
    [[
    local root = ...
    dot.path.workspace = function() return root end
    dot.path.is_git_repo = function() return true end
    era.fn.select_copy_filepaths = function(options) copied = options.filepaths end
    widget = require("era.m.git_files").new()
    widget:toggle()
    support.ready(widget)
    support.cursor(widget, "unstaged", "dir/mixed.lua")
  ]],
    root
  )
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
  end, 1000, "one outer frame joins the two columns")
  t.assert_false(doubled, "the columns share a single vertical border")
  t.assert_nil(grid:find("C-a hjkl panes"), "footer hints are not displayed")
  ui:rpc("nvim_input", "/zznotfound")
  ui:wait_until(function()
    return ui:lua(
      "return widget._query == 'zznotfound' and widget.panes.staged.tree:linecount() == 0 and widget.panes.unstaged.tree:linecount() == 0"
    )
  end, 3000, "typing in the persistent input filters both trees")
  t.wait_until(function()
    return border_text(grid, "Staged"):find("0 / 0", 1, true) and border_text(grid, "Unstaged"):find("0 / 0", 1, true)
  end, 1000, "empty filtered trees show zero positions in their borders")
  ui:rpc("nvim_input", "<C-u>mixed")
  ui:wait_until(function()
    return ui:lua(
      "return widget._query == 'mixed' and widget.panes.staged.tree:linecount() > 0 and widget.panes.unstaged.tree:linecount() > 0"
    )
  end, 3000)
  ui:rpc("nvim_input", "<CR>")
  ui:wait_until(function()
    return ui:lua("return widget.panes.unstaged.result:isfocused() and vim.api.nvim_get_mode().mode == 'n'")
  end, 1000, "Enter leaves the input in Normal mode on the current tree")
  ui:rpc("nvim_input", "gs")
  ui:wait_until(function()
    return ui:lua(
      "return widget._request == nil and widget.panes.unstaged.tree.totals.count == 0 and widget.panes.staged.result:isfocused()"
    )
  end, 5000, "stage key must move the file into the other tree")
  t.assert_true(git.run(root, { "show", ":dir/mixed.lua" }):find("unstaged-line", 1, true) ~= nil)
  ui:rpc("nvim_input", "<C-a>j")
  ui:wait_until(function()
    return ui:lua("return widget.panes.unstaged.result:isfocused()")
  end, 1000)
  ui:rpc("nvim_input", "<C-a>kgu")
  ui:wait_until(function()
    return ui:lua(
      "return widget._request == nil and widget.panes.staged.tree.totals.count == 0 and widget.panes.unstaged.tree.totals.count == 1"
    )
  end, 5000, "unstage key must return the file to Unstaged")
  t.assert_eq("", git.run(root, { "diff", "--cached", "--name-only" }))
  ui:lua("support.cursor(widget, 'unstaged', 'dir/mixed.lua')")
  ui:rpc("nvim_input", "oc")
  ui:wait_until(function()
    return ui:lua("return copied and copied[1]") == root .. "/dir/mixed.lua"
  end, 1000)
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return grid:find("staged-line") and grid:find("unstaged-line")
  end, 5000, "optional diff preview must show the current side")
  ui:rpc("nvim_input", "<C-a>l")
  ui:wait_until(function()
    return ui:lua("return widget.preview.surface:isfocused()")
  end, 1000)
  ui:rpc("nvim_input", "<D-h>")
  ui:wait_until(function()
    return ui:lua("return widget.panes.unstaged.result:isfocused()")
  end, 1000, "Cmd navigation returns to the tree that opened preview")
  ui:rpc("nvim_input", "<M-k><M-l>")
  ui:wait_until(function()
    return ui:lua("return widget.preview.surface:isfocused() and widget._active == 'staged'")
  end, 1000)
  ui:rpc("nvim_input", "<C-a>h")
  ui:wait_until(function()
    return ui:lua("return widget.panes.staged.result:isfocused()")
  end, 1000, "preview remembers either source tree")
  ui:lua([[
    stl.env.IS_TMUX = true
    navigation_zen = false
    dot.state.status.tmux_zen_mode = { snapshot = function() return navigation_zen end }
    stl.tmux.change_pane = function(direction) moved = direction end
  ]])
  ui:rpc("nvim_input", "<C-a>j<C-a>j")
  ui:wait_until(function()
    return ui:lua("return moved == 'j' and widget.panes.unstaged.result:isfocused()")
  end, 1000, "the outer edge delegates to tmux")
  ui:lua("navigation_zen = true; moved = nil")
  ui:rpc("nvim_input", "<C-a>j")
  ui:wait_until(function()
    return ui:lua("return moved == nil and widget.input:isfocused()")
  end, 1000, "zen mode wraps from the bottom tree to the input")
  ui:rpc("nvim_input", "<C-a>l")
  ui:wait_until(function()
    return ui:lua("return widget.preview.surface:isfocused()")
  end, 1000)
  ui:rpc("nvim_input", "<C-a>h")
  ui:wait_until(function()
    return ui:lua("return widget.input:isfocused()")
  end, 1000, "preview can return to the input too")
  ui:rpc("nvim_input", "tp")
  ui:wait_until(function()
    return ui:lua("return not widget.preview.surface:isvisible()")
  end, 1000)
  ui:lua("navigation_zen = false")
  ui:rpc("nvim_input", "<M-l>")
  ui:wait_until(function()
    return ui:lua("return moved == 'l' and widget.input:isfocused()")
  end, 1000, "hidden preview is not a navigation target")
  ui:rpc("nvim_input", "q")
  ui:wait_until(function()
    return not ui:lua("return widget:isvisible()")
  end, 1000)
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:test(
  "inline preview shows source gutters, full-line and word highlights with fixed numbers while scrolling",
  function()
    local root = support.repo(t)
    support.write(root, "dir/mixed.lua", { "local prefix = 1", 'local value = "old-旧值"', "print(value)" })
    git.run(root, { "add", "dir/mixed.lua" })
    support.write(root, "dir/mixed.lua", {
      "local prefix = 1",
      'local value = "new-新值"',
      "print(value)",
      'local long = "' .. string.rep("a", 110) .. 'TAIL_END"',
      'local message = "你好"',
    })
    local ui, grid = surface(140, 42)
    ui:lua(
      [[
    local root = ...
    dot.path.workspace = function() return root end
    dot.path.is_git_repo = function() return true end
    vim.api.nvim_set_hl(0, "DiffDelRight", { bg=0x332222 })
    vim.api.nvim_set_hl(0, "DiffAddRight", { bg=0x223322 })
    vim.api.nvim_set_hl(0, "DiffWordLeft", { bg=0x992222 })
    vim.api.nvim_set_hl(0, "DiffWordRight", { bg=0x229922 })
    vim.api.nvim_set_hl(0, "m_gf_diff_del_nr", { fg=0x999999, bg=0x332222 })
    vim.api.nvim_set_hl(0, "m_gf_diff_add_nr", { fg=0x999999, bg=0x223322 })
    vim.api.nvim_set_hl(0, "m_gf_diff_hunk", { fg=0x999999, bg=0x223344 })
    widget = require("era.m.git_files").new()
    widget:toggle()
    support.ready(widget)
    support.cursor(widget, "unstaged", "dir/mixed.lua")
  ]],
      root
    )
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
      local cells, text = grid.grids[at.grid].rows[at.row + 1], {}
      for col = removed.col - 8, removed.col do
        text[#text + 1] = cells[col][1]
      end
      return table.concat(text)
    end
    t.assert_eq("  2    - ", gutter(removed), "deletions show only the old line number")
    t.assert_eq("     2 + ", gutter(added), "additions show only the new line number")
    t.assert_eq("  3  3   ", gutter(grid:find("print(value)")), "context shows both source line numbers")
    for _, at in ipairs({ removed, added, assert(grid:find("@@ -1,3 +1,5 @@")) }) do
      local cells = grid.grids[at.grid].rows[at.row + 1]
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
    end, 1000, "long source lines can scroll horizontally")
    t.assert_eq("     4 + ", gutter(grid:find("TAIL_END")), "source numbers remain fixed during horizontal scrolling")
    t.assert_eq(0, #ui:lua("return errors"))
  end
)

t:test("Git count columns and status starts align across panes and remain fixed while filtering", function()
  local ui, grid = surface(140, 42)
  ui:lua([[
    dot.path.workspace = function() return "/git" end
    dot.path.is_git_repo = function() return true end
    require("era.m.git.numstat").collect_untracked = function() return nil end
    local a, b, c, binary = "/git/dir/a_中文.lua", "/git/dir/b.lua", "/git/c.lua", "/git/image.bin"
    local data = {
      status_map = {
        [a] = { relative="dir/a_中文.lua", staged={M=true}, unstaged={M=true} },
        [b] = { relative="dir/b.lua", staged={A=true}, unstaged={} },
        [c] = { relative="c.lua", staged={}, unstaged={["?"]=true} },
        [binary] = { relative="image.bin", staged={}, unstaged={M=true} },
      },
      numstats = {
        staged = {
          ["dir/a_中文.lua"] = {insertions=1, deletions=23},
          ["dir/b.lua"] = {insertions=123, deletions=4},
        },
        unstaged = {
          ["dir/a_中文.lua"] = {insertions=4000, deletions=5},
          ["c.lua"] = {insertions=0, deletions=0},
        },
      },
    }
    era.m.git.status.collect = function()
      return stl.c.Future.resolve({export=function() return data end, changed_files=function() return {a,b}, {a,c,binary} end})
    end
    widget = require("era.m.git_files").new()
    widget:toggle()
    support.ready(widget)
  ]])
  t.wait_until(function()
    return grid:find("a_") and grid:find("b.lua") and grid:find("c.lua") and grid:find("image.bin")
  end, 3000)

  ---@param label                       string
  ---@return table
  local function columns(label)
    local at = assert(grid:find(label))
    local text = {}
    for _, cell in ipairs(grid.grids[at.grid].rows[at.row + 1]) do
      text[#text + 1] = cell[1]
    end
    local line = table.concat(text)
    local _, last = line:find(label, 1, true)
    local boundary = assert(line:find("│", last + 1, true))
    local suffix = line:sub(last + 1, boundary - 1)
    local offset = vim.api.nvim_strwidth(line:sub(1, last))
    local _, insertion = suffix:find("%+%d+")
    local _, deletion = suffix:find("%-%d+")
    local status, code = suffix:match("()(%S+)%s*$")
    return {
      insertions = insertion and offset + vim.api.nvim_strwidth(suffix:sub(1, insertion)),
      deletions = deletion and offset + vim.api.nvim_strwidth(suffix:sub(1, deletion)),
      status = offset + vim.api.nvim_strwidth(suffix:sub(1, status - 1)),
      code = code,
      unknown = suffix:find("—", 1, true) ~= nil,
    }
  end

  local expected = columns("dir")
  t.assert_eq("AM", expected.code)
  for _, label in ipairs({ "a_", "b.lua", "c.lua" }) do
    local actual = columns(label)
    t.assert_eq(expected.insertions, actual.insertions, "addition digits share a right edge across panes")
    t.assert_eq(expected.deletions, actual.deletions, "deletion digits share a right edge across panes")
    t.assert_eq(expected.status, actual.status, "single and combined statuses share a left edge")
  end
  local binary = columns("image.bin")
  t.assert_true(binary.unknown)
  t.assert_nil(binary.insertions)
  t.assert_nil(binary.deletions)
  t.assert_eq(expected.status, binary.status, "unknown counts do not shift status")
  ui:lua("widget.input:set_content('b')")
  t.wait_until(function()
    return not grid:find("a_") and not grid:find("c.lua") and grid:find("b.lua")
  end, 3000)
  local filtered = columns("b.lua")
  t.assert_eq(expected.insertions, filtered.insertions)
  t.assert_eq(expected.deletions, filtered.deletions)
  t.assert_eq(expected.status, filtered.status, "filtered views keep snapshot-wide columns")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:run()
