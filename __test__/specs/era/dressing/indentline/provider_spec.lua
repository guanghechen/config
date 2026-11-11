local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")

local t = harness.new()

dressing.with_indentline(t)

local Indentline = require("era.dressing.indentline")
local Render = require("era.dressing.indentline.render")
Indentline.dressing()

-- Shows `lines` as Lua indented by two spaces in a file buffer of the current window, which gets its fold method back
-- when the case ends.
---@param lines                         string[]
---@return integer bufnr
---@return integer winnr
local function buffer(lines)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local foldmethod = vim.api.nvim_get_option_value("foldmethod", { win = winnr }) ---@type string
  local bufnr = t:buffer(lines, { filetype = "lua", scratch = false, current = true }) ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_option_value("foldmethod", foldmethod, { win = winnr })
    end
  end)
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })
  return bufnr, winnr
end

-- The guides a full redraw of `winnr` draws, by row.
---@param winnr                         integer
---@return __test__.support.dressing.IExtmark[]
local function render(winnr)
  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentline"] ---@type integer
  local extmarks = dressing.ephemeral_extmarks(t, namespace, function()
    vim.api.nvim__redraw({ win = winnr, valid = false, flush = true })
  end)
  table.sort(extmarks, function(left, right)
    return left.row < right.row
  end)
  return extmarks
end

t:test("provider renders visible indentation with ephemeral extmarks", function()
  local _, winnr = buffer({ "root", "  one", "    two", "tail" })
  local extmarks = render(winnr)
  t.assert_eq(2, #extmarks, "guide count")
  t.assert_eq(1, extmarks[1].row, "first guide row")
  t.assert_eq(2, extmarks[2].row, "second guide row")
  t.assert_eq("│ ", extmarks[1].options.virt_text[1][1], "first guide")
  t.assert_eq("overlay", extmarks[1].options.virt_text_pos, "position")
end)

t:test("option changes update guides on the next frame without drawing intermediate states", function()
  local bufnr, winnr = buffer({ "root", "    child", "tail" })
  local before = render(winnr)
  local frames = 0 ---@type integer
  local namespace = vim.api.nvim_create_namespace("test_indentline_option_frames") ---@type integer
  t:defer(function()
    vim.api.nvim_set_decoration_provider(namespace, {})
  end)
  vim.api.nvim_set_decoration_provider(namespace, {
    on_start = function()
      frames = frames + 1
    end,
  })

  vim.api.nvim_set_option_value("shiftwidth", 4, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 4, { buf = bufnr })
  -- Exercise OptionSet even when this spec runs before VimEnter.
  vim.api.nvim_exec_autocmds("OptionSet", { pattern = "shiftwidth", modeline = false })
  vim.api.nvim_exec_autocmds("OptionSet", { pattern = "tabstop", modeline = false })
  t.assert_eq(0, frames, "option burst does not flush intermediate frames")

  local after = render(winnr)
  t.assert_true(frames > 0, "next frame rendered")
  t.assert_false(vim.deep_equal(before[1].options.virt_text, after[1].options.virt_text), "updated indentation")
end)

t:test("provider renders indented EOF on cold and cached redraws", function()
  for _, lines in ipairs({ { "    value" }, { "root", "    value" } }) do
    local _, winnr = buffer(lines)
    Render.invalidate()
    for _ = 1, 2 do
      local extmarks = render(winnr)
      local row = #lines - 1 ---@type integer
      t.assert_eq(1, #extmarks, "EOF guide count")
      t.assert_eq(row, extmarks[1].row, "EOF guide row")
      local info = vim.fn.getwininfo(winnr)[1]
      t.assert_eq("│", vim.fn.screenstring(info.winrow + row, info.wincol + info.textoff), "EOF screen guide")
    end
  end
end)

t:test("provider preserves EOF guides when lines are appended or deleted", function()
  local bufnr, winnr = buffer({ "    one", "tail" })
  t.assert_eq(1, #render(winnr), "initial guide")

  vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})
  t.assert_eq(1, #render(winnr), "guide after deleting the last line")

  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "    last" })
  t.assert_eq(2, #render(winnr), "guide after appending an indented line")

  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})
  local extmarks = render(winnr)
  t.assert_eq(1, #extmarks, "remaining EOF guide")
  t.assert_eq(0, extmarks[1].row, "remaining EOF row")
end)

t:test("provider keeps horizontal scroll state window-local", function()
  local bufnr, first_winnr = buffer({ string.rep(" ", 100) .. string.rep("x", 200), "tail" })
  vim.api.nvim_set_option_value("wrap", false, { win = first_winnr, scope = "local" })
  vim.cmd("vsplit")
  local second_winnr = vim.api.nvim_get_current_win() ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(second_winnr) then
      vim.api.nvim_win_close(second_winnr, true)
    end
  end)
  vim.api.nvim_win_set_buf(second_winnr, bufnr)
  vim.api.nvim_set_option_value("wrap", false, { win = second_winnr, scope = "local" })
  vim.api.nvim_win_call(first_winnr, function()
    vim.api.nvim_win_set_cursor(first_winnr, { 1, 0 })
    vim.fn.winrestview({ leftcol = 0 })
  end)
  vim.api.nvim_win_call(second_winnr, function()
    vim.api.nvim_win_set_cursor(second_winnr, { 1, 80 })
    vim.cmd("normal! 10zl")
  end)

  Render.invalidate()
  local first = Render.build_frame(first_winnr, bufnr, 0, 2)
  local second = Render.build_frame(second_winnr, bufnr, 0, 2)
  t.assert_true(first ~= nil, "first frame")
  t.assert_true(second ~= nil, "second frame")
  t.assert_false(rawequal(first, second), "window-local frames")
  t.assert_eq(0, first and first.leftcol, "first leftcol")
  t.assert_true(second ~= nil and second.leftcol > 0, "second leftcol")

  local first_text = first and Render.make_virt_text(first, 0, Indentline.config) or nil
  local second_text = second and Render.make_virt_text(second, 0, Indentline.config) or nil
  t.assert_true(first_text ~= nil, "first guides")
  t.assert_true(second_text ~= nil, "second guides")
  t.assert_eq(
    second and second.leftcol,
    vim.fn.strchars(first_text or "") - vim.fn.strchars(second_text or ""),
    "horizontal clipping"
  )
end)

t:test("provider repaints blank lines affected by an adjacent edit", function()
  local bufnr, winnr = buffer({ "  one", "", "    two", "tail" })
  render(winnr)

  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentline"] ---@type integer
  local repainted = dressing.ephemeral_extmarks(t, namespace, function()
    vim.api.nvim_buf_set_lines(bufnr, 2, 3, false, { "      two" })
    vim.api.nvim__redraw({ win = winnr, flush = true })
  end)
  local extmarks = {} ---@type table<integer, __test__.support.dressing.IExtmark>
  for _, extmark in ipairs(repainted) do
    extmarks[extmark.row] = extmark
  end

  t.assert_true(extmarks[1] ~= nil, "dependent blank line repainted")
  t.assert_eq("│ │ │ ", extmarks[1].options.virt_text[1][1], "updated blank guide")
end)

t:test("provider renders tabs using tabstop and listchars", function()
  local bufnr, winnr = buffer({ "\tvalue", "tail" })
  vim.api.nvim_set_option_value("tabstop", 8, { buf = bufnr })
  vim.api.nvim_set_option_value("list", true, { win = winnr })
  vim.api.nvim_set_option_value("listchars", "tab:>-,space:·", { win = winnr })

  Render.invalidate()
  local extmarks = render(winnr)
  t.assert_eq(1, #extmarks, "guide count")
  t.assert_eq("│-│-│-│-", extmarks[1].options.virt_text[1][1], "tab guides")
end)

t:test("provider uses the tab end glyph for a one-column tab", function()
  local bufnr, winnr = buffer({ " \tvalue", "tail" })
  vim.api.nvim_set_option_value("tabstop", 2, { buf = bufnr })
  vim.api.nvim_set_option_value("list", true, { win = winnr })
  vim.api.nvim_set_option_value("listchars", "tab:>-<,space:·", { win = winnr })

  Render.invalidate()
  local extmarks = render(winnr)
  t.assert_eq(1, #extmarks, "guide count")
  t.assert_eq("│<", extmarks[1].options.virt_text[1][1], "one-column tab guide")
end)

t:test("provider preserves native tabs when listchars.tab is absent", function()
  local bufnr, winnr = buffer({ "\tvalue", "tail" })
  vim.api.nvim_set_option_value("tabstop", 8, { buf = bufnr })
  vim.api.nvim_set_option_value("list", true, { win = winnr })
  vim.api.nvim_set_option_value("listchars", "space:·", { win = winnr })

  Render.invalidate()
  t.assert_eq(0, #render(winnr), "native tab row has no overlay")
end)

t:test("provider preserves leading and trailing listchars", function()
  local _, winnr = buffer({ "    value", "    ", "tail" })
  vim.api.nvim_set_option_value("list", true, { win = winnr })
  vim.api.nvim_set_option_value("listchars", "leadmultispace:ab,trail:x,tab:>-", { win = winnr })

  Render.invalidate()
  local extmarks = render(winnr)
  t.assert_eq(2, #extmarks, "guide count")
  t.assert_eq("│b│b", extmarks[1].options.virt_text[1][1], "leading multispace")
  t.assert_eq("│x│x", extmarks[2].options.virt_text[1][1], "blank trail")
end)

t:test("provider gives lead precedence over multispace", function()
  local _, winnr = buffer({ "    value", "tail" })
  vim.api.nvim_set_option_value("list", true, { win = winnr })
  vim.api.nvim_set_option_value("listchars", "lead:x,multispace:ab,tab:>-", { win = winnr })

  Render.invalidate()
  local extmarks = render(winnr)
  t.assert_eq(1, #extmarks, "guide count")
  t.assert_eq("│x│x", extmarks[1].options.virt_text[1][1], "leading spaces")
end)

t:test("provider skips a closed fold and restores guides when opened", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 10 do
    lines[index] = "  line"
  end
  lines[11] = "tail"

  local _, winnr = buffer(lines)
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr })
  vim.cmd("2,10fold")
  vim.api.nvim_win_set_cursor(winnr, { 2, 0 })
  vim.cmd("normal! zc")
  t.assert_eq(0, #render(winnr), "closed fold guides")

  vim.cmd("normal! zo")
  t.assert_eq(9, #render(winnr), "open fold guides")
end)

t:run()
