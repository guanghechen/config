---@alias eve.builtin.win.TypeEnum
---| "ux:board"
---| "ux:cmdline"
---| "ux:input"
---| "ux:maximize"
---| "ux:notify"
---| "ux:popupmenu"
---| "ux:search-input"
---| "ux:search-main"
---| "ux:search-preview"
---| "ux:select-popup"
---| "ux:terminal"
---| "ux:textarea"
---| "ux:winpicker"
---| "ux:winsep"
---
---| "plugin:avante"
---| "plugin:neotree"

---@class eve.builtin.win.Types
local Types = {
  -- stylua: ignore start
  BOARD           = "ux:board",
  CMDLINE         = "ux:cmdline",
  INPUT           = "ux:input",
  MAXIMIZE        = "ux:maximize",
  NOTIFY          = "ux:notify",
  POPUPMENU       = "ux:popupmenu",
  SEARCH_INPUT    = "ux:search-input",
  SEARCH_MAIN     = "ux:search-main",
  SEARCH_PREVIEW  = "ux:search-preview",
  SELECT_POPUP    = "ux:select-popup",
  TERMINAL        = "ux:terminal",
  TEXTAREA        = "ux:textarea",
  WINPICKER       = "ux:winpicker",
  WINSEP          = "ux:winsep",

  AVANTE          = "plugin:avante",
  NEOTREE         = "plugin:neotree",
  -- stylua: ignore end
}

local wintype_attrs = {
  focusable = {
    [Types.BOARD] = true,
    [Types.INPUT] = true,
    [Types.MAXIMIZE] = true,
    [Types.NOTIFY] = true,
    [Types.POPUPMENU] = true,
    [Types.SEARCH_INPUT] = true,
    [Types.SEARCH_MAIN] = true,
    [Types.SEARCH_PREVIEW] = true,
    [Types.SELECT_POPUP] = true,
    [Types.TERMINAL] = true,
    [Types.TEXTAREA] = true,

    [Types.AVANTE] = true,
    [Types.NEOTREE] = true,
  },
  projectable = {},
  sourcefile = {},
  swappable = {},
}

---@class eve.builtin.win
local M = {}

M.Types = vim.deepcopy(Types)

---@param winnr                         integer
---@param wintype                       eve.builtin.win.TypeEnum|nil
---@return nil
function M.set_type(winnr, wintype)
  vim.w[winnr].eve_type = wintype
end

---@param winnr                         integer
---@return eve.builtin.win.TypeEnum|nil
function M.get_type(winnr)
  return vim.w[winnr].eve_type
end

----------------------------------------------------------------------------------------------------

---@param tabnr                         integer
---@param filetype                      string
---@return integer|nil
function M.find_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype then
      return winnr
    end
  end
  return nil
end

---@param tabnr                         integer
---@param filetype                      string|nil
---@return integer|nil
function M.find_fixed_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if (filetype == nil or vim.bo[bufnr].filetype == filetype) and M.is_fixed(winnr) then
      return winnr
    end
  end
  return nil
end

---@param tabnr                         integer
---@param filetype                      string
---@return integer|nil
function M.find_floating_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype and M.is_floating(winnr) then
      return winnr
    end
  end
  return nil
end

---@param filetype                      string|nil
---@return integer|nil
function M.find_sourcefile_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if (filetype == nil or vim.bo[bufnr].filetype == filetype) and M.is_sourcefile(winnr) then
      return winnr
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------

---@param winnr                         integer
---@return boolean
function M.is_fixed(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config == nil or config.relative == ""
end

---@param winnr                         integer
---@return boolean
function M.is_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                       integer
---@return boolean
function M.is_focusable(winnr)
  local wintype = M.get_type(winnr) ---@type eve.builtin.win.TypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.focusable[wintype] == true
  end

  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  if not config.focusable then
    return false
  end

  return true
end

---@param winnr                       integer
---@return boolean
function M.is_projectable(winnr)
  local wintype = M.get_type(winnr) ---@type eve.builtin.win.TypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.projectable[wintype] == true
  end

  if vim.wo[winnr].winfixbuf then
    return false
  end

  if M.is_floating(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_sourcefile(winnr)
  local wintype = M.get_type(winnr) ---@type eve.builtin.win.TypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.sourcefile[wintype] == true
  end

  if vim.wo[winnr].winfixbuf then
    return false
  end

  if M.is_floating(winnr) then
    return false
  end

  return true
end

---@param winnr                       integer
---@return boolean
function M.is_swappable(winnr)
  local wintype = M.get_type(winnr) ---@type eve.builtin.win.TypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.swappable[wintype] == true
  end

  if M.is_floating(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

----------------------------------------------------------------------------------------------------

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_focusable(winnr_candidate)
  return eve.winpicker.pick_window(M.is_focusable, winnr_candidate, false) ---@type integer|nil
end

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_projectable(winnr_candidate)
  return eve.winpicker.pick_window(M.is_projectable, winnr_candidate, false) ---@type integer|nil
end

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_sourcefile(winnr_candidate)
  if winnr_candidate ~= nil and eve.win.is_valid(winnr_candidate) and M.is_sourcefile(winnr_candidate) then
    return winnr_candidate
  end
  return eve.winpicker.pick_window(M.is_sourcefile, winnr_candidate, true) ---@type integer|nil
end

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_swappable(winnr_candidate)
  return eve.winpicker.pick_window(M.is_swappable, winnr_candidate, false) ---@type integer|nil
end

return M
