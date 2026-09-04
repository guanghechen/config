---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/dressing/indentline/draw.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.dressing.indentline.draw")

bootstrap.with_runtime(t, {
  stl = {
    filetype = require("stl.filetype"),
    fn = {
      observe = function()
        return { unsubscribe = function() end }
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          return vim.api.nvim_create_augroup(name, { clear = true })
        end,
      },
    },
  },
  dot = {
    context = {
      flight = {
        dressing_indent = {
          snapshot = function()
            return true
          end,
        },
      },
    },
  },
})

local Indentline = require("era.dressing.indentline")
local Render = require("era.dressing.indentline.render")
Indentline.dressing()

---@param lines                         string[]
---@param callback                      fun(bufnr: integer, winnr: integer): nil
---@return nil
local function with_buffer(lines, callback)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local previous_foldmethod = vim.api.nvim_get_option_value("foldmethod", { win = winnr }) ---@type string
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", 2, { buf = bufnr })

  local ok, err = pcall(callback, bufnr, winnr)
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_option_value("foldmethod", previous_foldmethod, { win = winnr })
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end

---@param winnr                         integer
---@return table[]
local function render(winnr)
  local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentline"] ---@type integer
  local original = vim.api.nvim_buf_set_extmark
  local extmarks = {} ---@type table[]
  local restore = t:patch_table(vim.api, "nvim_buf_set_extmark", function(bufnr, ns_id, row, col, options)
    if ns_id == namespace and options.ephemeral == true then
      extmarks[#extmarks + 1] = { bufnr = bufnr, row = row, col = col, options = vim.deepcopy(options) }
    end
    return original(bufnr, ns_id, row, col, options)
  end)
  vim.api.nvim__redraw({ win = winnr, valid = false, flush = true })
  restore()
  table.sort(extmarks, function(left, right)
    return left.row < right.row
  end)
  return extmarks
end

t:test("provider renders visible indentation with ephemeral extmarks", function()
  with_buffer({ "root", "  one", "    two", "tail" }, function(_, winnr)
    local extmarks = render(winnr)
    t.assert_eq(2, #extmarks, "guide count")
    t.assert_eq(1, extmarks[1].row, "first guide row")
    t.assert_eq(2, extmarks[2].row, "second guide row")
    t.assert_eq("│ ", extmarks[1].options.virt_text[1][1], "first guide")
    t.assert_eq("overlay", extmarks[1].options.virt_text_pos, "position")
  end)
end)

t:test("provider keeps horizontal scroll state window-local", function()
  with_buffer({ string.rep(" ", 100) .. string.rep("x", 200), "tail" }, function(bufnr, first_winnr)
    vim.api.nvim_set_option_value("wrap", false, { win = first_winnr, scope = "local" })
    vim.cmd("vsplit")
    local second_winnr = vim.api.nvim_get_current_win() ---@type integer
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

    local ok, err = pcall(function()
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

    if vim.api.nvim_win_is_valid(second_winnr) then
      vim.api.nvim_win_close(second_winnr, true)
    end
    if not ok then
      error(err, 0)
    end
  end)
end)

t:test("provider repaints blank lines affected by an adjacent edit", function()
  with_buffer({ "  one", "", "    two", "tail" }, function(bufnr, winnr)
    render(winnr)

    local namespace = vim.api.nvim_get_namespaces()["era.dressing.indentline"] ---@type integer
    local original = vim.api.nvim_buf_set_extmark
    local extmarks = {} ---@type table<integer, table>
    local restore = t:patch_table(vim.api, "nvim_buf_set_extmark", function(target_bufnr, ns_id, row, col, options)
      if ns_id == namespace and options.ephemeral == true then
        extmarks[row] = { bufnr = target_bufnr, col = col, options = vim.deepcopy(options) }
      end
      return original(target_bufnr, ns_id, row, col, options)
    end)

    vim.api.nvim_buf_set_lines(bufnr, 2, 3, false, { "      two" })
    vim.api.nvim__redraw({ win = winnr, flush = true })
    restore()

    t.assert_true(extmarks[1] ~= nil, "dependent blank line repainted")
    t.assert_eq("│ │ │ ", extmarks[1].options.virt_text[1][1], "updated blank guide")
  end)
end)

t:test("provider renders tabs using tabstop and listchars", function()
  with_buffer({ "\tvalue", "tail" }, function(bufnr, winnr)
    vim.api.nvim_set_option_value("tabstop", 8, { buf = bufnr })
    vim.api.nvim_set_option_value("list", true, { win = winnr })
    vim.api.nvim_set_option_value("listchars", "tab:>-,space:·", { win = winnr })

    Render.invalidate()
    local extmarks = render(winnr)
    t.assert_eq(1, #extmarks, "guide count")
    t.assert_eq("│-│-│-│-", extmarks[1].options.virt_text[1][1], "tab guides")
  end)
end)

t:test("provider uses the tab end glyph for a one-column tab", function()
  with_buffer({ " \tvalue", "tail" }, function(bufnr, winnr)
    vim.api.nvim_set_option_value("tabstop", 2, { buf = bufnr })
    vim.api.nvim_set_option_value("list", true, { win = winnr })
    vim.api.nvim_set_option_value("listchars", "tab:>-<,space:·", { win = winnr })

    Render.invalidate()
    local extmarks = render(winnr)
    t.assert_eq(1, #extmarks, "guide count")
    t.assert_eq("│<", extmarks[1].options.virt_text[1][1], "one-column tab guide")
  end)
end)

t:test("provider preserves native tabs when listchars.tab is absent", function()
  with_buffer({ "\tvalue", "tail" }, function(bufnr, winnr)
    vim.api.nvim_set_option_value("tabstop", 8, { buf = bufnr })
    vim.api.nvim_set_option_value("list", true, { win = winnr })
    vim.api.nvim_set_option_value("listchars", "space:·", { win = winnr })

    Render.invalidate()
    t.assert_eq(0, #render(winnr), "native tab row has no overlay")
  end)
end)

t:test("provider preserves leading and trailing listchars", function()
  with_buffer({ "    value", "    ", "tail" }, function(_, winnr)
    vim.api.nvim_set_option_value("list", true, { win = winnr })
    vim.api.nvim_set_option_value("listchars", "leadmultispace:ab,trail:x,tab:>-", { win = winnr })

    Render.invalidate()
    local extmarks = render(winnr)
    t.assert_eq(2, #extmarks, "guide count")
    t.assert_eq("│b│b", extmarks[1].options.virt_text[1][1], "leading multispace")
    t.assert_eq("│x│x", extmarks[2].options.virt_text[1][1], "blank trail")
  end)
end)

t:test("provider gives lead precedence over multispace", function()
  with_buffer({ "    value", "tail" }, function(_, winnr)
    vim.api.nvim_set_option_value("list", true, { win = winnr })
    vim.api.nvim_set_option_value("listchars", "lead:x,multispace:ab,tab:>-", { win = winnr })

    Render.invalidate()
    local extmarks = render(winnr)
    t.assert_eq(1, #extmarks, "guide count")
    t.assert_eq("│x│x", extmarks[1].options.virt_text[1][1], "leading spaces")
  end)
end)

t:test("provider skips a closed fold and restores guides when opened", function()
  local lines = { "root" } ---@type string[]
  for index = 2, 10 do
    lines[index] = "  line"
  end
  lines[11] = "tail"

  with_buffer(lines, function(_, winnr)
    vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr })
    vim.cmd("2,10fold")
    vim.api.nvim_win_set_cursor(winnr, { 2, 0 })
    vim.cmd("normal! zc")
    t.assert_eq(0, #render(winnr), "closed fold guides")

    vim.cmd("normal! zo")
    t.assert_eq(9, #render(winnr), "open fold guides")
  end)
end)

t:run()
