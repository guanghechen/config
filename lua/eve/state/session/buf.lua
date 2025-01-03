local env = require("eve.builtin.env")
local fn = require("eve.builtin.fn")
local path = require("eve.builtin.path")
local setting = require("eve.constant.setting")
local editor = require("eve.module.editor")
local calc_fileicon = require("eve.module.fileicon").calc_fileicon

---@class eve.t.state.buf.lsp.ISymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class eve.t.state.buf.meta.data
---@field public filepath               string
---@field public filetype               string

---@class eve.t.state.buf.meta.state
---@field public fileicon               string
---@field public fileicon_hl            string
---@field public filename               string
---@field public filepath               string
---@field public relpath                string
---@field public relpath_pieces         string[]

---@class eve.state.buf.data
---@field public list                   eve.t.state.buf.meta.data[]

---@class eve.state.buf.state
---@field public __meta_map__           table<integer, eve.t.state.buf.meta.state>
---@field public get                    fun(bufnr: integer|nil): eve.t.state.buf.meta.state|nil
---@field public set                    fun(bufnr: integer|nil, meta: eve.t.state.buf.meta.state): nil
---@field public del                    fun(bufnr: integer|nil): nil
---@field public resolve                fun(bufnr: integer|nil): eve.t.state.buf.meta.state|nil
---@field public refresh                fun(bufnr: integer|nil): nil
---@field public refresh_all            fun(): nil
---
---@field public locate_by_filepath     fun(filepath: string|nil): integer|nil
---@field public open_filepath          fun(winnr: integer, filepath: string, lnum?: integer, col?: integer): boolean
---@field public pick_filepath          fun(cwd: string, existed_paths?: table<string, boolean>): string|nil
local S = {}

---@class eve.state.buf
---@field public defaults               fun(): eve.state.buf.data
---@field public dump                   fun(): eve.state.buf.data
---@field public load                   fun(data: unknown): eve.state.buf.state
---@field public normalize              fun(data: unknown): eve.state.buf.data
local M = {}

---@type eve.state.buf.state
S = {
  __meta_map__ = {}, ---@type table<integer, eve.t.state.buf.meta.state>
  get = function(bufnr)
    if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
      return S.__meta_map__[bufnr]
    end
  end,
  set = function(bufnr, meta)
    if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
      S.__meta_map__[bufnr] = meta
      return meta
    end
  end,
  del = function(bufnr)
    if bufnr ~= nil and bufnr > 0 then
      S.__meta_map__[bufnr] = nil
    end
  end,
  resolve = function(bufnr)
    if bufnr == nil or bufnr < 1 then
      return nil
    end

    local meta = S.__meta_map__[bufnr] ---@type eve.t.state.buf.meta.state|nil
    if meta ~= nil then
      return meta
    end

    if not editor.is_buf_valid(bufnr) then
      return nil
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local filename = path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and setting.BUF_UNTITLED or filename
    local fileicon, fileicon_hl = calc_fileicon(filename) ---@type string, string

    local workspace_pieces = path.split(path.workspace()) ---@type string[]
    local cwd_pieces = path.split(path.cwd()) ---@type string[]
    local relpath_pieces = path.split_prettier(workspace_pieces, cwd_pieces, filepath) ---@type string[]
    local relpath = table.concat(relpath_pieces, env.PATH_SEP)

    ---@type eve.t.state.buf.meta.state
    meta = {
      fileicon = fileicon,
      fileicon_hl = fileicon_hl,
      filename = filename,
      filepath = filepath,
      relpath = relpath,
      relpath_pieces = relpath_pieces,
    }
    S.__meta_map__[bufnr] = meta
    return meta
  end,
  refresh = function(bufnr)
    if bufnr == nil or bufnr < 1 then
      return nil
    end

    local meta = S.__meta_map__[bufnr] ---@type eve.t.state.buf.meta.state|nil
    if meta == nil then
      S.resolve(bufnr)
      return
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if meta.filepath ~= filepath then
      local filename = path.basename(filepath) ---@type string
      filename = #filename > 0 and filename or setting.BUF_UNTITLED
      local fileicon, fileicon_hl = calc_fileicon(filename) ---@type string, string

      local workspace_pieces = path.split(path.workspace()) ---@type string[]
      local cwd_pieces = path.split(path.cwd()) ---@type string[]
      local relpath_pieces = path.split_prettier(workspace_pieces, cwd_pieces, filepath) ---@type string[]
      local relpath = table.concat(relpath_pieces, env.PATH_SEP)

      meta.fileicon = fileicon
      meta.fileicon_hl = fileicon_hl
      meta.filename = filename
      meta.filepath = filepath
      meta.relpath = relpath
      meta.relpath_pieces = relpath_pieces
    end
  end,
  refresh_all = function()
    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      S.refresh(bufnr)
    end

    local invalid_bufnrs = {} ---@type integer[]
    for bufnr in pairs(S.__meta_map__) do
      if bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
        invalid_bufnrs[#invalid_bufnrs + 1] = bufnr
      end
    end

    for _, bufnr in ipairs(invalid_bufnrs) do
      S.__meta_map__[bufnr] = nil
    end
  end,
  locate_by_filepath = function(filepath)
    if filepath == nil or #filepath < 1 then
      return nil
    end

    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local meta = S.__meta_map__[bufnr] ---@type eve.t.state.buf.meta.state|nil
      local buf_filepath = meta and meta.filepath or vim.api.nvim_buf_get_name(bufnr) ---@type string
      if buf_filepath == filepath then
        return bufnr
      end
    end
    return nil
  end,
  open_filepath = function(winnr, filepath, lnum, col)
    filepath = path.normalize(filepath)

    if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
      return false
    end

    local bufnr = S.locate_by_filepath(filepath) ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_set_current_win(winnr)
      vim.api.nvim_win_set_buf(winnr, bufnr)
    else
      vim.api.nvim_set_current_win(winnr)
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    end

    vim.schedule(function()
      vim.cmd.stopinsert()

      if lnum ~= nil and col ~= nil then
        pcall(function()
          vim.api.nvim_win_set_cursor(winnr, { lnum, col })
        end)
      end
    end)
    return true
  end,
  pick_filepath = function(cwd, existed_paths)
    if existed_paths == nil then
      existed_paths = {} ---@type table<string, boolean>

      local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
      for _, bufnr in ipairs(bufnrs) do
        local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
        local filepath = path.resolve(cwd, filename) ---@type string
        existed_paths[filepath] = true
      end
    end

    for i = 1, 100 do
      local filepath = path.join(cwd, setting.BUF_UNTITLED .. "-" .. tostring(i)) ---@type string
      if not existed_paths[filepath] and vim.uv.fs_stat(filepath) == nil then
        return filepath
      end
    end
    return nil
  end,
}

---@return eve.state.buf.data
function M.defaults()
  ---@type eve.state.buf.data
  return {
    list = {},
  }
end

---@param data                        any
---@return eve.state.buf.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.buf.data
  if type(data) == "table" then
    if type(data.list) == "table" then
      for _, item in ipairs(data.list) do
        if type(item.filepath) == "string" and type(item.filetype) == "string" then
          ---@type eve.t.state.buf.meta.data
          local meta = {
            filepath = item.filepath,
            filetype = item.filetype,
          }
          table.insert(resolved.list, meta)
        end
      end
    end
  end

  ---@type eve.state.buf.data
  return resolved
end

---@return eve.state.buf.data
function M.dump()
  local list = {} ---@type eve.t.state.buf.meta.data[]
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local meta = S.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil
    if meta ~= nil then
      ---@type eve.t.state.buf.meta.data
      local meta_data = {
        filepath = meta.filepath,
        filetype = vim.bo[bufnr].filetype,
      }
      list[#list + 1] = meta_data
    end
  end

  ---@type eve.state.buf.data
  return {
    list = list,
  }
end

---@param raw_data                      any
---@return eve.state.buf.state
function M.load(raw_data)
  S.__meta_map__ = {}

  local data = M.normalize(raw_data) ---@type eve.state.buf.data

  local workspace_pieces = path.split(path.workspace()) ---@type string[]
  local cwd_pieces = path.split(path.cwd()) ---@type string[]
  local filepath2bufnr = fn.filepath2bufnr() ---@type table<string, integer>
  for _, item in ipairs(data.list) do
    local bufnr = filepath2bufnr[item.filepath] ---@type integer|nil
    if bufnr ~= nil then
      local filename = path.basename(item.filepath) ---@type string
      local fileicon, fileicon_hl = calc_fileicon(filename) ---@type string, string
      local relpath_pieces = path.split_prettier(workspace_pieces, cwd_pieces, item.filepath) ---@type string[]
      local relpath = table.concat(relpath_pieces, env.PATH_SEP)

      if #vim.bo[bufnr].filetype < 1 then
        vim.bo[bufnr].filetype = item.filetype
      end

      ---@type eve.t.state.buf.meta.state
      local meta = {
        fileicon_hl = fileicon_hl,
        fileicon = fileicon,
        filename = filename,
        filepath = item.filepath,
        relpath = relpath,
        relpath_pieces = relpath_pieces,
      }
      S.set(bufnr, meta)
    end
  end
  return S
end

return M
