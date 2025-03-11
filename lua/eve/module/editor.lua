local fn = require("eve.builtin.fn")
local fs = require("eve.builtin.fs")
local path = require("eve.builtin.path")
local ft = require("eve.constant.filetype")
local varnames = require("eve.constant.var")
local setting = require("eve.constant.setting")
local winpicker = require("eve.module.winpicker")

---@class eve.module.editor
local M = {}

---@param tabnr                         integer
---@return eve.e.state.tab.meta.TabType
function M.calc_tabtype(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  ---! Check if the diffview tab
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == ft.DIFFVIEW_FILES or filetype == ft.DIFFVIEW_FILE_HISTORY then
      return setting.tabtypes.DIFFVIEW
    end
  end

  return setting.tabtypes.NORMAL ---@type string
end

---@param filetype                      string
---@return integer|nil
function M.find_winnr(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype then
      return winnr
    end
  end
  return nil
end

---@param filetype                      string|nil
---@return integer|nil
function M.find_winnr_fixed(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if filetype == nil or vim.bo[bufnr].filetype == filetype and not fn.is_win_floating(winnr) then
      return winnr
    end
  end
  return nil
end

---@param filetype                      string
---@return integer|nil
function M.find_winnr_floating(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype and fn.is_win_floating(winnr) then
      return winnr
    end
  end
  return nil
end

---@return string
function M.get_selected_text()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if filetype == ft.TERM then
    return ""
  end

  local saved_reg = vim.fn.getreg("v")
  vim.cmd([[noautocmd sil norm! "vy]])

  local selected_text = vim.fn.getreg("v")
  vim.fn.setreg("v", saved_reg)
  return selected_text or ""
end

---@return integer
---@return integer
function M.get_visual_lnum_range()
  local lnum_1 = vim.fn.getcurpos()[2] ---@type integer
  local lnum_2 = vim.fn.line("v") ---@type integer
  if lnum_1 < lnum_2 then
    return lnum_1, lnum_2
  end
  return lnum_2, lnum_1
end

---@param tabnr                         integer
---@return string[]
function M.get_visible_bufnrs(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufnrs[bufnr] = true
  end
  return bufnrs
end

---@param winnr_source                  integer|nil
---@return integer
function M.get_projectable_winnr(winnr_source)
  if
    winnr_source ~= nil
    and winnr_source > 0
    and vim.api.nvim_win_is_valid(winnr_source)
    and winpicker.filters.project(winnr_source)
  then
    return winnr_source
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    if winpicker.filters.project(winnr) then
      return winnr
    end
  end

  for _, winnr in ipairs(winnrs) do
    if not fn.is_win_floating(winnr) then
      return winnr
    end
  end
  return -1
end

---@param bufnr                         integer
---@return boolean
function M.is_buf_valid(bufnr)
  return bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

---@param bufnr                         integer
---@return boolean
function M.is_buf_sourcefile(bufnr)
  local is_sourcefile = vim.b[bufnr][varnames.FLAG_SOURCEFILE] ---@type boolean|nil
  if is_sourcefile ~= nil then
    return is_sourcefile
  end

  if not vim.bo[bufnr].buflisted then
    vim.b[bufnr][varnames.FLAG_SOURCEFILE] = false
    return false
  end

  if not ft.is_plain_file(vim.bo[bufnr].filetype) then
    vim.b[bufnr][varnames.FLAG_SOURCEFILE] = false
    return false
  end

  vim.b[bufnr][varnames.FLAG_SOURCEFILE] = true
  return true
end

---@param tabnr                         integer
---@return boolean
function M.is_tab_valid(tabnr)
  return tabnr > 0 and vim.api.nvim_tabpage_is_valid(tabnr)
end

---@param winnr                         integer
---@return boolean
function M.is_win_sourcefile(winnr)
  local is_sourcefile = vim.w[winnr][varnames.FLAG_SOURCEFILE] ---@type boolean|nil
  if is_sourcefile ~= nil then
    return is_sourcefile
  end

  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  if config.relative ~= nil and config.relative ~= "" then
    vim.w[winnr][varnames.FLAG_SOURCEFILE] = false
    return false
  end

  vim.w[winnr][varnames.FLAG_SOURCEFILE] = true
  return true
end

---@param winnr                         integer
---@return boolean
function M.is_win_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

---@param filepath                      string|nil
---@return boolean
function M.is_valid_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == setting.BUF_UNTITLED then
    return false
  end
  return fs.is_file_or_dir(filepath) == "file"
end

---@param winnr_source                  integer|nil
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr_source, filepath, lnum, col)
  filepath = path.normalize(filepath)

  ---@type integer|nil
  local winnr = (
    winnr_source ~= nil
    and winnr_source > 0
    and vim.api.nvim_win_is_valid(winnr_source)
    and winpicker.filters.project(winnr_source)
  )
      and winnr_source
    or winpicker.pick_window(winpicker.filters.project, winnr_source, true)

  if winnr == nil then
    return false
  end

  vim.api.nvim_set_current_win(winnr)
  vim.cmd("edit " .. vim.fn.fnameescape(filepath))

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

---@param winnr_source                  integer
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
    and winpicker.filters.project(winnr_source)
  )
      and winnr_source
    or winpicker.pick_window(winpicker.filters.project, winnr_source, true)

  if winnr == nil then
    return
  end

  vim.api.nvim_set_current_win(winnr)
  for _, filepath in ipairs(filepaths) do
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  end

  vim.schedule(function()
    vim.cmd.stopinsert()
  end)
end

return M
