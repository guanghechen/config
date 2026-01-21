---@class stl.nvim.win
local M = {}

---@param winnr                         ?integer
---@return nil
function M.close(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  vim.api.nvim_win_close(winnr, true)
end

---@param tabnr                         integer
---@param filetype                      string
---@return integer|nil
function M.find_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == filetype then
      return winnr
    end
  end
  return nil
end

---@param winnr                         integer
---@return boolean
function M.is_fixed(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config == nil or config.relative == ""
end

---@param winnr                         integer
---@return boolean
function M.is_float(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer
---@return boolean
function M.is_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

return M
