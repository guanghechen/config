---@class eve.std.string
local M = {}

---@param text                          string
---@return string
function M.make_termcodes_visible(text)
  ---@type string
  local next_text = text:gsub(string.char(9), "<TAB>"):gsub("", "<C-F>"):gsub(" ", "<Space>")
  return next_text
end

---@param text                          string
---@param width                         integer
---@param pad                           string
---@return string
function M.pad_start(text, width, pad)
  local delta = width - vim.api.nvim_strwidth(text) ---@type integer
  return delta <= 0 and text or (string.rep(pad, delta) .. text)
end

---@param text                          string
---@param width                         integer
---@param pad                           string
---@return string
function M.pad_end(text, width, pad)
  local delta = width - vim.api.nvim_strwidth(text) ---@type integer
  return delta <= 0 and text or (text .. string.rep(pad, delta))
end

return M
