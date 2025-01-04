local __module_name__ = "eve.module.winpicker" ---@type string

local fn = require("eve.builtin.fn")
local reporter = require("eve.builtin.reporter")
local ft = require("eve.constant.filetype")
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

---@class eve.module.winpicker.filters
M.filters = {
  ---@param winnr                       integer
  ---@return boolean
  focus = function(winnr)
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not ft.is_not_focusable_filetype(filetype)
  end,
  ---@param winnr                       integer
  ---@return boolean
  swap = function(winnr)
    if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
      return false
    end

    if fn.is_win_floating(winnr) then
      return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not ft.is_not_projectable_filetype(filetype)
  end,
  ---@param winnr                       integer
  ---@return boolean
  project = function(winnr)
    if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
      return false
    end

    if fn.is_win_floating(winnr) then
      return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not ft.is_not_projectable_filetype(filetype)
  end,
}

---@param filter                        fun(winnr: integer): boolean
---@param winnr_source                  integer
---@param split_as_needed               boolean
---@return integer|nil
function M.pick_window(filter, winnr_source, split_as_needed)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  local N = 0 ---@type integer
  for i = 1, #winnrs, 1 do
    local winnr = winnrs[i] ---@type integer
    if winnr ~= winnr_source and filter(winnr) then
      N = N + 1 ---@type integer
      winnrs[N] = winnr
    end
  end

  if N < 1 then
    if split_as_needed then
      for _, winnr in ipairs(winnrs) do
        if not fn.is_win_floating(winnr) then
          vim.api.nvim_set_current_win(winnr)
          vim.cmd("vsplit")
          return vim.api.nvim_get_current_win() ---@type integer
        end
      end
    end

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
