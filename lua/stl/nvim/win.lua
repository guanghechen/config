---@alias stl.nvim.win.TypeEnum
---| "ux:board"
---| "ux:cmdline"
---| "ux:explorer"
---| "ux:input"
---| "ux:notify"
---| "ux:picker-finder"
---| "ux:picker-preview"
---| "ux:picker-result"
---| "ux:popupmenu"
---| "ux:searcher-finder"
---| "ux:searcher-preview"
---| "ux:searcher-result"
---| "ux:select"
---| "ux:terminal"
---| "ux:textarea"
---| "ux:winpicker"
---| "ux:winsep"

---@class stl.nvim.win.TypeEnumClass
local TypeEnum = {
  -- stylua: ignore start
  BOARD             = "ux:board",
  CMDLINE           = "ux:cmdline",
  EXPLORER          = "ux:explorer",
  INPUT             = "ux:input",
  NOTIFY            = "ux:notify",
  PICKER_FINDER     = "ux:picker-finder",
  PICKER_PREVIEW    = "ux:picker-preview",
  PICKER_RESULT     = "ux:picker-result",
  POPUPMENU         = "ux:popupmenu",
  SEARCHER_FINDER   = "ux:searcher-finder",
  SEARCHER_PREVIEW  = "ux:searcher-preview",
  SEARCHER_RESULT   = "ux:searcher-result",
  SELECT            = "ux:select",
  TERMINAL          = "ux:terminal",
  TEXTAREA          = "ux:textarea",
  WINPICKER         = "ux:winpicker",
  WINSEP            = "ux:winsep",
  -- stylua: ignore end
}

---@class stl.nvim.win
local M = {}

M.TypeEnum = vim.deepcopy(TypeEnum)

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
