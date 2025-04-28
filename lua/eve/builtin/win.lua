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

---@class eve.builtin.win.IFilepathHistoryItem
---@field public bufnr                  integer|nil
---@field public filepath               string|nil

---@class eve.builtin.win.IMetaData
---@field public history                eve.std.collection.IHistory|nil

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

local history_map = {} ---@type table<integer, eve.std.collection.IHistory>

---@class eve.builtin.win
local M = {}

M.Types = vim.deepcopy(Types)

---@param winnr                         integer|nil
---@return eve.builtin.win.TypeEnum|nil
function M.get_type(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end
  return vim.w[winnr].eve_type
end

---@param winnr                         integer
---@param wintype                       eve.builtin.win.TypeEnum|nil
---@return nil
function M.set_type(winnr, wintype)
  vim.w[winnr].eve_type = wintype
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
  if winnr_candidate ~= nil and M.is_valid(winnr_candidate) and M.is_sourcefile(winnr_candidate) then
    return winnr_candidate
  end
  return eve.winpicker.pick_window(M.is_sourcefile, winnr_candidate, true) ---@type integer|nil
end

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_swappable(winnr_candidate)
  return eve.winpicker.pick_window(M.is_swappable, winnr_candidate, false) ---@type integer|nil
end

----------------------------------------------------------------------------------------------------

---@param winnr_source                  integer
---@param winnr_target                  integer
---@return eve.builtin.win.IMetaData|nil
function M.fork(winnr_source, winnr_target)
  if
    winnr_source < 1
    or winnr_target < 1
    or not vim.api.nvim_win_is_valid(winnr_source)
    or not vim.api.nvim_win_is_valid(winnr_target)
  then
    return nil
  end

  local meta_source = M.resolve(winnr_source) ---@type eve.builtin.win.IMetaData|nil
  if meta_source == nil then
    return nil
  end

  local history = meta_source.history ---@type eve.std.collection.IHistory
  local history_forked = history:fork({ name = "win_filepath" }) ---@type eve.std.collection.IHistory

  local history_target = history_map[winnr_target] ---@type eve.std.collection.IHistory|nil
  if history_target ~= nil then
    history_map[winnr_target]:clear()
  end
  history_map[winnr_target] = history_forked

  ---@type eve.builtin.win.IMetaData|nil
  local meta_target = {
    history = history_forked,
  }
  return meta_target
end

---@param winnr_source                  integer|nil
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr_source, filepath, lnum, col)
  local bufnr = eve.buf.loadfile(filepath) ---@type integer|nil
  if bufnr == nil then
    return false
  end

  local winnr = M.pick_sourcefile(winnr_source) ---@type integer|nil
  if winnr == nil then
    return false
  end

  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.schedule(function()
    vim.cmd.stopinsert()

    if lnum ~= nil and col ~= nil then
      pcall(function()
        vim.api.nvim_win_set_cursor(winnr, { lnum, col })
      end)
    end
  end)
  return true
end

---@param winnr_source                  integer|nil
---@param filepaths                     string[]
---@return nil
function M.open_filepaths(winnr_source, filepaths)
  if #filepaths < 1 then
    return
  end

  ---@type integer|nil
  local winnr = (
    winnr_source ~= nil
    and winnr_source > 0
    and vim.api.nvim_win_is_valid(winnr_source)
    and M.is_sourcefile(winnr_source)
  )
      and winnr_source
    or eve.winpicker.pick_window(M.is_sourcefile, winnr_source, true)

  if winnr == nil then
    return
  end

  for _, filepath in ipairs(filepaths) do
    local bufnr = eve.buf.loadfile(filepath) ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_win_set_buf(winnr, bufnr)
    end
  end

  vim.schedule(function()
    vim.cmd.stopinsert()
  end)
end

---@param winnr                         integer|nil
---@return eve.builtin.win.IMetaData|nil
function M.resolve(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local wintype = M.get_type(winnr) ---@type eve.builtin.win.TypeEnum|nil
  if wintype ~= nil then
    return nil
  end

  if M.is_floating(winnr) then
    return nil
  end

  local history = history_map[winnr] ---@type eve.std.collection.IHistory|nil
  if history == nil then
    history = eve.std.History.new({
      name = "win#bufs",
      capacity = eve.setting.WIN_BUF_HISTORY_CAPACITY,
      ---@param x                       eve.builtin.win.IFilepathHistoryItem
      ---@param y                       eve.builtin.win.IFilepathHistoryItem
      equals = function(x, y)
        return x == y or (x.bufnr == y.bufnr and x.filepath == y.filepath)
      end,
    })
    history_map[winnr] = history
  end

  ---@type eve.builtin.win.IMetaData
  local meta = {
    history = history,
  }
  return meta
end

---@param winnr                         integer
---@return nil
function M.on_close(winnr)
  local history = history_map[winnr] ---@type eve.std.collection.IHistory|nil
  if history ~= nil then
    history:clear()
    history_map[winnr] = nil
  end
end

---@param winnr                         integer
---@param bufnr                         integer
---@return nil
function M.on_buf_enter(winnr, bufnr)
  local meta_win = M.resolve(winnr) ---@type eve.builtin.win.IMetaData|nil
  if meta_win == nil then
    return
  end

  local meta_buf = eve.buf.resolve(bufnr) ---@type eve.builtin.buf.IMetaData|nil
  if meta_buf == nil then
    return
  end

  local filepath = meta_buf.filepath ---@type string
  local history = meta_win.history ---@type eve.std.collection.IHistory
  local item = { bufnr = bufnr, filepath = filepath } ---@type eve.builtin.win.IFilepathHistoryItem
  history:push(item)
end

return M
