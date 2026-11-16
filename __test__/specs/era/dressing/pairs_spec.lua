local harness = require("__test__.support.harness")
local Grid = require("__test__.support.ui_grid")
local UI = require("__test__.support.ui")
local t = harness.new()

-- Rainbow groups carry a foreground only and matchparen a background only, so a cell shows both.
local COLORS = { 0x111111, 0x222222, 0x333333, 0x444444, 0x555555 }
local UNMATCHED = 0x990000
local MATCHPAREN = 0x00aa00

---@param lines                         string[]
---@param filetype                      ?string
---@return __test__.support.UI
---@return table grid
local function open(lines, filetype)
  local ui = UI.open(t)
  local grid = Grid.new(ui)
  ui:start({ width = 60, height = 8, runtime = "ark" })
  ui:lua(
    [[
    local lines, filetype, colors, unmatched, matchparen = ...
    vim.cmd("filetype plugin indent on")
    for level, color in ipairs(colors) do
      vim.api.nvim_set_hl(0, "f_matched_pairs_" .. level, { fg = color })
    end
    vim.api.nvim_set_hl(0, "f_unmatched_pairs", { fg = unmatched })
    vim.api.nvim_set_hl(0, "f_matched_pairs_0", { bg = matchparen })
    vim.o.number = false
    vim.o.cursorline = false
    vim.o.list = false
    era.dressing.pairs.dressing()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.filetype = filetype
  ]],
    lines,
    filetype or "lua",
    COLORS,
    UNMATCHED,
    MATCHPAREN
  )
  return ui, grid
end

---@param ui                            __test__.support.UI
---@return nil
local function redraw(ui)
  ui:lua("vim.api.nvim__redraw({ valid = false, flush = true })")
end

--- The highlight of each character of `text` on screen, or nil before it shows.
---@param grid                          table
---@param text                          string
---@return table[]|nil
local function cells(grid, text)
  local at = grid:find(text)
  if not at then
    return nil
  end
  local row = grid:row_cells(at)
  local out = {} ---@type table[]
  for offset = 0, #text - 1 do
    out[#out + 1] = grid.highlights[row[at.col + offset + 1][2]] or {}
  end
  return out
end

--- Waits until `text` is on screen and `check`, when given, accepts it; the highlight of each of its characters.
---@param grid                          table
---@param text                          string
---@param check                         ?fun(drawn: table[]): boolean
---@param msg                           string
---@return table[]
local function shown(grid, text, check, msg)
  local drawn = nil ---@type table[]|nil
  t.wait_until(function()
    drawn = cells(grid, text)
    return drawn ~= nil and (check == nil or check(drawn))
  end, 5000, msg)
  return assert(drawn)
end

--- Whether any of the highlights has a pair color.
---@param drawn                         table[]
---@return boolean
local function colored(drawn)
  for _, cell in ipairs(drawn) do
    if cell.foreground == UNMATCHED or vim.tbl_contains(COLORS, cell.foreground) then
      return true
    end
  end
  return false
end

t:test("delimiters take the color of their depth, and unmatched ones their own", function()
  local text = "x = f(a[b{c}], (d)) )"
  local ui, grid = open({ text })
  redraw(ui)
  local drawn = shown(grid, text, function(drawn)
    return drawn[6].foreground == COLORS[1]
  end, "rainbow drawn")
  local colors = {} ---@type (integer|false)[]
  for index = 1, #text do
    if text:sub(index, index):find("[%(%)%[%]{}]") then
      colors[#colors + 1] = drawn[index].foreground or false
    end
  end
  local c = COLORS
  t.assert_same({ c[1], c[2], c[3], c[3], c[2], c[2], c[2], c[1], UNMATCHED }, colors)
end)

t:test("an edit recolors what it changes", function()
  local ui, grid = open({ "f((a))" })
  redraw(ui)
  shown(grid, "f((a))", function(drawn)
    return drawn[3].foreground == COLORS[2]
  end, "nested pair drawn")
  ui:lua("vim.api.nvim_buf_set_text(0, 0, 2, 0, 3, { '' })")
  redraw(ui)
  shown(grid, "f(a))", function(drawn)
    return drawn[2].foreground == COLORS[1] and drawn[5].foreground == UNMATCHED
  end, "the pair moves out and the extra closing is unmatched")
end)

t:test("matchparen highlights the pair at the cursor and else the pair around it", function()
  local text = "local t = { f(1), g(2) }"
  local ui, grid = open({ text })
  ui:lua("vim.api.nvim_win_set_cursor(0, { 1, 13 }); vim.api.nvim_exec_autocmds('CursorMoved', {})")
  redraw(ui)
  shown(grid, text, function(drawn)
    return drawn[14].background == MATCHPAREN and drawn[16].background == MATCHPAREN
  end, "the pair of f( is highlighted")
  ui:lua("vim.api.nvim_win_set_cursor(0, { 1, 17 }); vim.api.nvim_exec_autocmds('CursorMoved', {})")
  redraw(ui)
  shown(grid, text, function(drawn)
    return drawn[11].background == MATCHPAREN
      and drawn[24].background == MATCHPAREN
      and drawn[14].background ~= MATCHPAREN
  end, "the braces around the cursor are highlighted instead")
end)

t:test("a buffer reloaded from disk drops the colors of the text it replaced", function()
  local path = t:tempdir() .. "/reload.lua"
  vim.fn.writefile({ "f(a[b]c)" }, path)
  local ui, grid = open({}, "lua")
  ui:lua("vim.cmd.edit(...)", path)
  redraw(ui)
  shown(grid, "f(a[b]c)", function(drawn)
    return drawn[2].foreground == COLORS[1]
  end, "pairs drawn")
  -- Unedited, the rebuilt document starts over like the one it replaces.
  vim.fn.writefile({ "abcdefgh" }, path)
  ui:lua("vim.cmd('edit!')")
  redraw(ui)
  t.assert_false(colored(shown(grid, "abcdefgh", nil, "new text on screen")))
end)

t:test("a substitute preview draws no pair colors until it ends", function()
  local ui, grid = open({ "a(b[c])" }, "lua")
  ui:lua("vim.o.inccommand = 'nosplit'")
  redraw(ui)
  shown(grid, "a(b[c])", function(drawn)
    return drawn[2].foreground == COLORS[1]
  end, "pairs drawn")
  ui:rpc("nvim_input", ":s/a/xxxx/")
  -- The document has not seen the preview's text, so it draws nothing rather than colors at stale columns.
  t.assert_false(colored(shown(grid, "xxxx(b[c])", nil, "preview on screen")))
  ui:rpc("nvim_input", "<Esc>")
  ui:wait_lua("return vim.api.nvim_get_mode().mode == 'n'", 5000, "Normal mode")
  redraw(ui)
  shown(grid, "a(b[c])", function(drawn)
    return drawn[2].foreground == COLORS[1] and drawn[4].foreground == COLORS[2] and not colored({ drawn[1] })
  end, "pairs drawn again after the preview")
end)

t:run()
