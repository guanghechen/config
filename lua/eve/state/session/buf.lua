---@class eve.state.buf.lsp.ISymbol
---@field public kind                   string
---@field public name                   string
---@field public row                    integer
---@field public col                    integer

---@class eve.state.buf.meta.data
---@field public filepath               string
---@field public filetype               string

---@class eve.state.buf.meta.state
---@field public fileicon               string
---@field public fileicon_hl            string
---@field public filename               string
---@field public filepath               string
---@field public relpath                string
---@field public relpath_pieces         string[]

---@class eve.state.buf.data
---@field public list                   eve.state.buf.meta.data[]

---@class eve.state.buf.state
---@field public __meta_map__           table<integer, eve.state.buf.meta.state>
---@field public get                    fun(bufnr: integer|nil): eve.state.buf.meta.state|nil
---@field public set                    fun(bufnr: integer|nil, meta: eve.state.buf.meta.state): nil
---@field public del                    fun(bufnr: integer|nil): nil
---@field public resolve                fun(bufnr: integer|nil): eve.state.buf.meta.state|nil
---@field public refresh                fun(bufnr: integer|nil): nil
---@field public refresh_all            fun(): nil
---
---@field public locate_by_filepath     fun(filepath: string|nil): integer|nil
---@field public pick_filepath          fun(cwd: string, existed_paths?: table<string, boolean>): string|nil

---@class eve.state.buf : eve.state.buf.state
---@field public defaults               fun(): eve.state.buf.data
---@field public dump                   fun(): eve.state.buf.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.buf.data
local M = {}

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
          ---@type eve.state.buf.meta.data
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
  local list = {} ---@type eve.state.buf.meta.data[]
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local meta = M.resolve(bufnr) ---@type eve.state.buf.meta.state|nil
    if meta ~= nil then
      ---@type eve.state.buf.meta.data
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
---@return nil
function M.load(raw_data)
  M.__meta_map__ = {}

  local data = M.normalize(raw_data) ---@type eve.state.buf.data
  local workspace_pieces = eve.path.split(eve.path.workspace()) ---@type string[]
  local cwd_pieces = eve.path.split(eve.path.cwd()) ---@type string[]
  local filepath2bufnr = eve.nvim.filepath2bufnr() ---@type table<string, integer>
  for _, item in ipairs(data.list) do
    local bufnr = filepath2bufnr[item.filepath] ---@type integer|nil
    if bufnr ~= nil then
      local filename = eve.path.basename(item.filepath) ---@type string
      local fileicon, fileicon_hl = eve.fn.fileicon(filename) ---@type string, string
      local relpath_pieces = eve.path.split_prettier(workspace_pieces, cwd_pieces, item.filepath) ---@type string[]
      local relpath = table.concat(relpath_pieces, eve.env.PATH_SEP)

      if #vim.bo[bufnr].filetype < 1 then
        vim.bo[bufnr].filetype = item.filetype
      end

      ---@type eve.state.buf.meta.state
      local meta = {
        fileicon_hl = fileicon_hl,
        fileicon = fileicon,
        filename = filename,
        filepath = item.filepath,
        relpath = relpath,
        relpath_pieces = relpath_pieces,
      }
      M.set(bufnr, meta)
    end
  end
end

----------------------------------------------------------------------------------------------------

M.__meta_map__ = {} ---@type table<integer, eve.state.buf.meta.state>

---@param bufnr                         integer|nil
---@return eve.state.buf.meta.state|nil
function M.get(bufnr)
  if bufnr ~= nil and eve.editor.is_buf_valid(bufnr) then
    return M.__meta_map__[bufnr]
  end
end

---@param bufnr                         integer|nil
---@param meta                          eve.state.buf.meta.state
---@return nil
function M.set(bufnr, meta)
  if bufnr ~= nil and eve.editor.is_buf_valid(bufnr) then
    M.__meta_map__[bufnr] = meta
    return meta
  end
end

---@param bufnr                         integer|nil
---@return nil
function M.del(bufnr)
  if bufnr ~= nil and bufnr > 0 then
    M.__meta_map__[bufnr] = nil
  end
end

---@param bufnr                         integer|nil
---@return eve.state.buf.meta.state|nil
function M.resolve(bufnr)
  if bufnr == nil or not eve.editor.is_buf_valid(bufnr) or not eve.editor.is_buf_sourcefile(bufnr) then
    return nil
  end

  local meta = M.__meta_map__[bufnr] ---@type eve.state.buf.meta.state|nil
  if meta ~= nil then
    return meta
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filename = eve.path.basename(filepath) ---@type string
  filename = (not filename or filename == "") and eve.setting.BUF_UNTITLED or filename
  local fileicon, fileicon_hl = eve.fn.fileicon(filename) ---@type string, string

  local workspace_pieces = eve.path.split(eve.path.workspace()) ---@type string[]
  local cwd_pieces = eve.path.split(eve.path.cwd()) ---@type string[]
  local relpath_pieces = eve.path.split_prettier(workspace_pieces, cwd_pieces, filepath) ---@type string[]
  local relpath = table.concat(relpath_pieces, eve.env.PATH_SEP)

  ---@type eve.state.buf.meta.state
  meta = {
    fileicon = fileicon,
    fileicon_hl = fileicon_hl,
    filename = filename,
    filepath = filepath,
    relpath = relpath,
    relpath_pieces = relpath_pieces,
  }
  M.__meta_map__[bufnr] = meta
  return meta
end

---@param bufnr                         integer|nil
---@return nil
function M.refresh(bufnr)
  if bufnr == nil or not eve.editor.is_buf_valid(bufnr) then
    return nil
  end

  local meta = M.__meta_map__[bufnr] ---@type eve.state.buf.meta.state|nil
  if meta == nil then
    M.resolve(bufnr)
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if meta.filepath ~= filepath then
    local filename = eve.path.basename(filepath) ---@type string
    filename = #filename > 0 and filename or eve.setting.BUF_UNTITLED
    local fileicon, fileicon_hl = eve.fn.fileicon(filename) ---@type string, string

    local workspace_pieces = eve.path.split(eve.path.workspace()) ---@type string[]
    local cwd_pieces = eve.path.split(eve.path.cwd()) ---@type string[]
    local relpath_pieces = eve.path.split_prettier(workspace_pieces, cwd_pieces, filepath) ---@type string[]
    local relpath = table.concat(relpath_pieces, eve.env.PATH_SEP)

    meta.fileicon = fileicon
    meta.fileicon_hl = fileicon_hl
    meta.filename = filename
    meta.filepath = filepath
    meta.relpath = relpath
    meta.relpath_pieces = relpath_pieces
  end
end

---@return nil
function M.refresh_all()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    M.refresh(bufnr)
  end

  local invalid_bufnrs = {} ---@type integer[]
  for bufnr in pairs(M.__meta_map__) do
    if not eve.editor.is_buf_valid(bufnr) then
      invalid_bufnrs[#invalid_bufnrs + 1] = bufnr
    end
  end

  for _, bufnr in ipairs(invalid_bufnrs) do
    M.__meta_map__[bufnr] = nil
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
    local meta = M.__meta_map__[bufnr] ---@type eve.state.buf.meta.state|nil
    local buf_filepath = meta and meta.filepath or vim.api.nvim_buf_get_name(bufnr) ---@type string
    if buf_filepath == filepath then
      return bufnr
    end
  end
  return nil
end

---@param cwd                           string
---@param existed_paths                 ?table<string, boolean>
---@return string|nil
function M.pick_filepath(cwd, existed_paths)
  if existed_paths == nil then
    existed_paths = {} ---@type table<string, boolean>

    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = eve.path.resolve(cwd, filename) ---@type string
      existed_paths[filepath] = true
    end
  end

  for i = 1, 100 do
    local filepath = eve.path.join(cwd, eve.setting.BUF_UNTITLED .. "-" .. tostring(i)) ---@type string
    if not existed_paths[filepath] and vim.uv.fs_stat(filepath) == nil then
      return filepath
    end
  end
  return nil
end

return M
