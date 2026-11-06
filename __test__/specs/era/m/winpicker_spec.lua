local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()

local HINT = { "+-+", "|a|", "+-+" } ---@type string[]

bootstrap.with_runtime(t, {
  stl = {
    e = { WinTypeEnum = { WINPICKER = "ux:winpicker" } },
    filetype = { WINPICKER_MASK = "winpicker-mask" },
    winhint = { a = HINT },
  },
  dot = {
    var = { N_WINLINE_DISABLED = "__test_winline_disabled" },
    win = {
      resolve_zindex = function()
        return 50
      end,
    },
  },
})

local Winpicker = assert(loadfile("lua/era/m/winpicker.lua"))()

---@return integer[]
local function hint_bufnrs()
  return vim.tbl_filter(function(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "winpicker-mask"
  end, vim.api.nvim_list_bufs())
end

t:test("picking again reuses the hint buffer of a key and draws its hint once", function()
  t:defer(function()
    for _, bufnr in ipairs(hint_bufnrs()) do
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  for _ = 1, 3 do
    local mask = Winpicker.new("a")
    mask:show(winnr)
    mask:hide()
  end

  local bufnrs = hint_bufnrs()
  t.assert_eq(1, #bufnrs, "hint buffers")
  t.assert_same(HINT, vim.api.nvim_buf_get_lines(bufnrs[1], 0, -1, false), "hint lines")
end)

t:run()
