local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local nvim_fn = require("stl.nvim.fn")
local t = harness.new()

local callbacks = {} ---@type table<string, function>
local symbols = {} ---@type dot.t.ILspSymbol[]

bootstrap.with_runtime(t, {
  stl = {
    icon = { kind = {}, fillchars = { foldclose = ">" } },
    nvim = { fn = nvim_fn },
  },
  dot = {
    G = {
      register_anonymous_fn = function(callback)
        local name = "lsp_component_fn_" .. (vim.tbl_count(callbacks) + 1) ---@type string
        callbacks[name] = callback
        return name
      end,
    },
    win = {
      resolve = function()
        return { winline = { lsp_symbols = symbols } }
      end,
    },
  },
})

local Lsp = assert(loadfile("lua/era/m/nvimbar/component/lsp.lua"))()

t:test("a breadcrumb click jumps to its symbol however far down the file it is", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local lines = {} ---@type string[]
  for index = 1, 2000 do
    lines[index] = string.format("local value_%04d = %d", index, index)
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  local winnr = vim.api.nvim_open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 80, height = 10 })
  t:defer(function()
    vim.api.nvim_win_close(winnr, true)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  -- Columns of symbols are 1-based.
  symbols = { { name = "near", kind = 12, row = 10, col = 5 }, { name = "far", kind = 12, row = 600, col = 9 } }
  t:patch_table(vim.fn, "getmousepos", function()
    return { winid = winnr, line = 0 }
  end)

  local pieces = Lsp.symbols("winbar").refresh({ winnr = winnr })
  t.assert_eq(#symbols, #pieces, "pieces")
  for index, piece in ipairs(pieces) do
    -- Statusline click items read their number as a C int.
    local minwid, name = piece.hltext:match("%%(%d+)@v:lua%.([^@]+)@")
    t.assert_eq(tostring(index), minwid, symbols[index].name .. " click number")
    callbacks[name](tonumber(minwid), 1, "l", "    ")
    t.assert_same(
      { symbols[index].row, symbols[index].col - 1 },
      vim.api.nvim_win_get_cursor(winnr),
      symbols[index].name
    )
  end
end)

t:run()
