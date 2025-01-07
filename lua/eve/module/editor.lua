local fn = require("eve.builtin.fn")
local fs = require("eve.builtin.fs")
local path = require("eve.builtin.path")
local ft = require("eve.constant.filetype")
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
      return setting.TT_DIFFVIEW
    end
  end

  return setting.TT_NORMAL ---@type string
end

---@param filetype                      string
---@return integer|nil
function M.find_floating_winnr(filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype and fn.is_win_floating(winnr) then
      return winnr
    end
  end
  return nil
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

---@param bufnr                         integer|nil
---@return boolean
function M.is_buf_valid(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if not vim.bo[bufnr].buflisted then
    return false
  end

  if not ft.is_plain_file(vim.bo[bufnr].filetype) then
    return false
  end

  return true
end

---@param tabnr                         integer|nil
---@return boolean
function M.is_tab_valid(tabnr)
  if tabnr == nil or tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
    return false
  end

  return true
end

---@param winnr                         integer|nil
---@return boolean
function M.is_win_valid(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return false
  end

  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  if config.relative ~= nil and config.relative ~= "" then
    return false
  end

  return true
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
