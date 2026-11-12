require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local support = require("__test__.support.git_files")
local border_text = support.border_text

t:test("both panes render side-specific colored counts over CJK paths and resize without body writes", function()
  local ui, grid = support.surface(t, 120, 40, "/git")
  ui:lua([[
    local paths = { "/git/long-很长的文件名_很长的文件名_很长的文件名.lua" }
    for index = 1, 1000 do paths[#paths+1] = string.format("/git/z%04d.lua", index) end
    local data = { status_map = {}, numstats = { staged = {}, unstaged = {} } }
    for _, path in ipairs(paths) do
      local relative = path:sub(6)
      data.status_map[path] = { relative = relative, staged = { M = true }, unstaged = { M = true } }
      data.numstats.staged[relative] = { insertions = 12, deletions = 3 }
      data.numstats.unstaged[relative] = { insertions = 4, deletions = 1 }
    end
    stub_status(data, paths, paths)
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
    open({ _preview_enabled = false })
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
  local row = grid:row_cells(staged)
  t.assert_eq(0xee3344, grid.highlights[row[staged.col + 8][2]].foreground)
  t.assert_eq(0x55bbff, grid.highlights[row[staged.col + 11][2]].foreground)
  row = grid:row_cells(unstaged)
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
  end, 5000, "each border follows its own cursor")
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
  end, 5000, "narrow borders reserve the right edge for position counts")
end)

t:test("Git count columns and status starts align across panes and remain fixed while filtering", function()
  local ui, grid = support.surface(t, 140, 42, "/git")
  ui:lua([[
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
    stub_status(data, {a,b}, {a,c,binary})
    open()
  ]])
  t.wait_until(function()
    return grid:find("a_") and grid:find("b.lua") and grid:find("c.lua") and grid:find("image.bin")
  end, 5000)

  ---@param label                       string
  ---@return table
  local function columns(label)
    local line = grid:row_text(assert(grid:find(label)))
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

  ---Whether the row of `label` shows a selection mark; nil while no row shows `label`.
  ---@param label                       string
  ---@return boolean|nil
  local function marked(label)
    local at = grid:find(label)
    return at
      and vim.iter(grid:row_cells(at)):any(function(cell)
        return cell[1] == "●" or cell[1] == "◐"
      end)
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
  ui:lua([[
    local tree = widget.panes.staged.tree
    tree:toggle_select(require("era.view.result_paths").key("/git/dir/b.lua"), true)
    local ready = tree:ready()
    assert(vim.wait(5000, function() return ready:is_done() and not tree:frame():header().summary.is_empty end))
  ]])
  t.wait_until(function()
    return marked("b.lua")
  end, 5000, "the staged selection is drawn")
  -- `columns` reads a status as the last token, so measure unselected rows: Staged a_ and Unstaged c.lua.
  for _, label in ipairs({ "a_", "c.lua" }) do
    local actual = columns(label)
    t.assert_eq(expected.insertions, actual.insertions, label .. " keeps its column while one pane has a selection")
    t.assert_eq(expected.status, actual.status, label .. " status keeps its column while one pane has a selection")
  end
  ui:lua([[
    local tree = widget.panes.staged.tree
    tree:toggle_select(require("era.view.result_paths").key("/git/dir/b.lua"), false)
    local ready = tree:ready()
    assert(vim.wait(5000, function() return ready:is_done() and tree:frame():header().summary.is_empty end))
  ]])
  t.wait_until(function()
    return marked("b.lua") == false
  end, 5000, "the staged selection is cleared")
  ui:lua("widget.input:set_content('b')")
  t.wait_until(function()
    return not grid:find("a_") and not grid:find("c.lua") and grid:find("b.lua")
  end, 5000)
  local filtered = columns("b.lua")
  t.assert_eq(expected.insertions, filtered.insertions)
  t.assert_eq(expected.deletions, filtered.deletions)
  t.assert_eq(expected.status, filtered.status, "filtered views keep snapshot-wide columns")
  t.assert_eq(0, #ui:lua("return errors"))
end)

t:run()
