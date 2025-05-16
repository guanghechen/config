local __module_name__ = "eve.builtin.winpicker" ---@type string

local Mask = require("eve.builtin.winpicker.mask")

---@class eve.builtin.winpicker.config
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

---@class eve.builtin.winpicker
local M = {}

---@param filter                        fun(winnr: integer): boolean
---@param winnr_candidate               integer|nil
---@param split_as_needed               boolean
---@return integer|nil
function M.pick_window(filter, winnr_candidate, split_as_needed)
  local winnr_original = vim.api.nvim_get_current_win() ---@type integer

  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  local N = 0 ---@type integer
  for i = 1, #winnrs, 1 do
    local winnr = winnrs[i] ---@type integer
    if winnr ~= winnr_candidate and filter(winnr) then
      N = N + 1 ---@type integer
      winnrs[N] = winnr
    end
  end

  if N < 1 then
    if split_as_needed then
      for _, winnr in ipairs(winnrs) do
        if not eve.win.is_float(winnr) then
          local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
          vim.bo[bufnr].bufhidden = "wipe"
          vim.bo[bufnr].buflisted = true
          vim.bo[bufnr].buftype = "nofile"
          vim.bo[bufnr].filetype = "text"
          vim.bo[bufnr].swapfile = false

          vim.api.nvim_set_current_win(winnr)
          vim.cmd("vsplit")
          local winnr_new = vim.api.nvim_get_current_win() ---@type integer
          vim.api.nvim_win_set_buf(winnr_new, bufnr)
          return winnr_new
        end
      end
    end

    std.reporter.warn({
      from = __module_name__,
      subject = "pick_window",
      message = "No windows left to pick after filtering",
    })
    return nil
  end

  if N == 1 then
    return winnrs[1]
  end

  local masks = {} ---@type table<integer, eve.builtin.winpicker.Mask>
  local winnr_target = nil ---@type integer|nil

  pcall(function()
    for i = 1, N, 1 do
      local winnr = winnrs[i] ---@type integer
      local char = config.chars[i] ---@type string
      local mask = Mask.new(char:lower()) ---@type eve.builtin.winpicker.Mask
      masks[winnr] = mask
    end

    for winnr, mask in pairs(masks) do
      mask:show(winnr)
    end

    vim.api.nvim__redraw({ flush = true })

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
  end)

  for _, mask in pairs(masks) do
    mask:hide()
  end
  vim.api.nvim__redraw({ flush = true })

  --- Refocus the original window if no window selected.
  if winnr_target == nil then
    vim.api.nvim_set_current_win(winnr_original)
  end

  return winnr_target
end

return M
