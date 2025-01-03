local __module_name__ = "eve.module.winpicker" ---@type string

local reporter = require("eve.builtin.reporter")
local Mask = require("eve.module.winpicker.mask")

---@class eve.module.winpicker.config
local config = {
  chars = {
    "F",
    "J",
    "D",
    "K",
    "S",
    "L",
    "A",
    ";",
    "C",
    "M",
    "R",
    "U",
    "E",
    "I",
    "W",
    "O",
    "Q",
    "P",
  },
}

---@return string|nil
local function get_user_input_char()
  local ok, c = pcall(vim.fn.getchar)

  if not ok then
    return
  end

  while type(c) ~= "number" do
    c = vim.fn.getchar()
  end

  return vim.fn.nr2char(c)
end

---@class eve.module.winpicker
local M = {}

---@param filter                        fun(winnr: integer): boolean
---@param winnr_cur                     integer|nil
---@return integer|nil
function M.pick_window(filter, winnr_cur)
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  local N = 0 ---@type integer
  for i = 1, #winnrs, 1 do
    local winnr = winnrs[i] ---@type integer
    if winnr ~= winnr_cur and filter(winnr) then
      N = N + 1 ---@type integer
      winnrs[N] = winnr
    end
  end

  if N < 1 then
    reporter.warn({
      from = __module_name__,
      subject = "pick_window",
      message = "No windows left to pick after filtering",
    })
    return nil
  end

  if N == 1 then
    return winnrs[1]
  end

  local masks = {} ---@type table<integer, eve.module.winpicker.Mask>
  for i = 1, N, 1 do
    local winnr = winnrs[i] ---@type integer
    local char = config.chars[i] ---@type string
    local mask = Mask.new(char:lower()) ---@type eve.module.winpicker.Mask
    masks[winnr] = mask
  end

  for winnr, mask in pairs(masks) do
    mask:show(winnr)
  end

  vim.cmd.redraw()
  local winnr_target = nil ---@type integer|nil

  local char = get_user_input_char() ---@type string|nil
  if char ~= nil then
    char = char:lower() ---@type string
    for winnr, mask in pairs(masks) do
      if char == mask.char then
        winnr_target = winnr ---@type integer
        break
      end
    end
  end

  for _, mask in pairs(masks) do
    mask:hide()
  end
  vim.cmd.redraw()

  return winnr_target
end

return M
