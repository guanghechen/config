local env = require("eve.lib.env")
local path = require("eve.lib.path")
local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")
local calc_fileicon = require("eve.builtin.nvim").calc_fileicon
local tab = require("eve.builtin.tab")

local meta_map = {} ---@type table<integer, eve.t.state.state.buf.IMeta>

---@class eve.builtin.buf
local M = {}
M.__meta_map__ = meta_map

---@param bufnr                         integer|nil
---@return eve.t.state.state.buf.IMeta|nil
function M.get_meta(bufnr)
  if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    return meta_map[bufnr]
  end
end

---@param bufnr                         integer|nil
---@param meta                          eve.t.state.state.buf.IMeta|nil
---@return eve.t.state.state.buf.IMeta|nil
function M.set_meta(bufnr, meta)
  if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    meta_map[bufnr] = meta
    return meta
  end
end

---@param bufnr                         integer|nil
---@return nil
function M.del_meta(bufnr)
  if bufnr ~= nil then
    meta_map[bufnr] = nil
  end
end

---@param bufnr                         integer|nil
---@return eve.t.state.state.buf.IMeta|nil
function M.resolve(bufnr)
  local meta = M.get_meta(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
  if meta ~= nil then
    return meta
  end

  if bufnr == nil or not checks.is_buf_valid(bufnr) then
    return nil
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  local filename = path.basename(filepath) ---@type string
  filename = (not filename or filename == "") and constant.BUF_UNTITLED or filename
  local fileicon, fileicon_hl = calc_fileicon(filename) ---@type string, string

  local workspace_pieces = path.split(path.workspace()) ---@type string[]
  local cwd_pieces = path.split(path.cwd()) ---@type string[]
  local relpath_pieces = path.split_prettier(workspace_pieces, cwd_pieces, filepath) ---@type string[]
  local relpath = table.concat(relpath_pieces, env.PATH_SEP)

  ---@type eve.t.state.state.buf.IMeta
  meta = {
    fileicon = fileicon,
    fileicon_hl = fileicon_hl,
    filename = filename,
    filepath = filepath,
    filetype = filetype,
    relpath = relpath,
    relpath_pieces = relpath_pieces,
  }
  return M.set_meta(bufnr, meta)
end

---@param bufnr                         integer|nil
---@return eve.t.state.state.buf.IMeta|nil
function M.refresh(bufnr)
  if bufnr == nil then
    return
  end

  local meta = M.get_meta(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
  if meta == nil then
    return M.resolve(bufnr)
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = vim.bo[bufnr].filetype ---@type string
  if meta.filepath ~= filepath or meta.filetype ~= filetype then
    local filename = path.basename(filepath) ---@type string
    filename = #filename > 0 and filename or constant.BUF_UNTITLED
    local fileicon, fileicon_hl = calc_fileicon(filename) ---@type string, string

    local workspace_pieces = path.split(path.workspace()) ---@type string[]
    local cwd_pieces = path.split(path.cwd()) ---@type string[]
    local relpath_pieces = path.split_prettier(workspace_pieces, cwd_pieces, filepath) ---@type string[]
    local relpath = table.concat(relpath_pieces, env.PATH_SEP)

    meta.fileicon = fileicon
    meta.fileicon_hl = fileicon_hl
    meta.filename = filename
    meta.filepath = filepath
    meta.filetype = filetype
    meta.relpath = relpath
    meta.relpath_pieces = relpath_pieces
  end
  return meta
end

---@return nil
function M.refresh_all()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    M.refresh(bufnr)
  end

  local invalid_bufnrs = {} ---@type integer[]
  for bufnr in pairs(meta_map) do
    if bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
      invalid_bufnrs[#invalid_bufnrs + 1] = bufnr
    end
  end

  for _, bufnr in ipairs(invalid_bufnrs) do
    M.del_meta(bufnr)
  end
end

----------------------------------------------------------------------------------------------------

---@param bufnr                         integer the stable unique number of the buffer
---@return nil
function M.go(bufnr)
  local meta_tab = tab.get_current() ---@type eve.t.state.state.tab.IMeta|nil
  local winnr = meta_tab and meta_tab.winnr_listed or 0 ---@type integer
  if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
end

---@param filepath                      string|nil
---@return integer|nil
function M.locate_by_filepath(filepath)
  if filepath == nil or #filepath < 1 then
    return nil
  end

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local meta = M.get_meta(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
    local buf_filepath = meta and meta.filepath or vim.api.nvim_buf_get_name(bufnr) ---@type string
    if buf_filepath == filepath then
      return bufnr
    end
  end
  return nil
end

---@param winnr                         integer
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr, filepath, lnum, col)
  filepath = path.normalize(filepath) ---! normalize the filepath
  if vim.api.nvim_win_is_valid(winnr) then
    local bufnr = M.locate_by_filepath(filepath) ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_win_set_buf(winnr, bufnr)
    else
      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      if winnr_cur == winnr then
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
      else
        vim.api.nvim_set_current_win(winnr)
        vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        vim.api.nvim_set_current_win(winnr_cur)
      end
    end

    vim.schedule(function()
      vim.cmd("stopinsert")

      local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
      local bufnr_cur = vim.api.nvim_win_get_buf(winnr) ---@type integer
      vim.bo[bufnr_cur].buflisted = true
      tab.on_buf_enter(winnr_cur, bufnr_cur)

      if lnum ~= nil and col ~= nil then
        pcall(function()
          vim.api.nvim_win_set_cursor(winnr_cur, { lnum, col })
        end)
      end
    end)
    return true
  end
  return false
end

---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath_in_current_valid_win(filepath, lnum, col)
  local winnr = tab.get_current_winnr() ---@type integer
  if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    return M.open_filepath(winnr, filepath, lnum, col)
  end
  return false
end

---@param cwd                           string
---@param existed_filepaths             ?table<string, boolean>
---@return string|nil
function M.pick_filepath(cwd, existed_filepaths)
  if existed_filepaths == nil then
    existed_filepaths = {} ---@type table<string, boolean>

    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = path.resolve(cwd, filename) ---@type string
      existed_filepaths[filepath] = true
    end
  end

  for i = 1, 1000 do
    local filepath = path.join(cwd, constant.BUF_UNTITLED .. "-" .. tostring(i)) ---@type string
    if not existed_filepaths[filepath] and vim.uv.fs_stat(filepath) == nil then
      return filepath
    end
  end
  return nil
end

return M
