local __module_name__ = "dot.buf" ---@type string

---@class dot.buf.IMeta
---@field public dirpath_pieces         string[]
---@field public filename               string
---@field public filepath               string
---@field public relpath                string
---@field public fileicon               string
---@field public fileicon_hln           string

local meta_map = {} ---@type table<integer, dot.buf.IMeta|nil>

---@class dot.buf
local M = {}

----------------------------------------------------------------------------------------------------

---@param filepath                      string|nil
---@return integer|nil
function M.loadfile(filepath)
  if filepath == nil or #filepath < 1 then
    return nil
  end

  local bufnr_sourcefile = stl.nvim.buf.locate_bufnr(filepath) ---@type integer|nil
  if bufnr_sourcefile ~= nil then
    vim.bo[bufnr_sourcefile].buflisted = true
    return bufnr_sourcefile
  end

  if yoz.path.is_exist_file(filepath) then
    local bufnr = vim.fn.bufadd(filepath) ---@type integer
    if bufnr == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
      return nil
    end

    vim.bo[bufnr].buflisted = true
    vim.bo[bufnr].buftype = ""
    vim.bo[bufnr].swapfile = false

    local ok, error = pcall(vim.fn.bufload, bufnr)
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "loadfile",
        message = string.format("Failed to load file %s", filepath),
        details = {
          bufnr = bufnr,
          filepath = filepath,
          error = error,
        },
      })
      return nil
    end

    vim.bo[bufnr].swapfile = vim.o.swapfile
    -- vim.api.nvim_exec_autocmds("FileReadPost", { buffer = bufnr })
    -- vim.api.nvim_exec_autocmds("BufReadPost", { buffer = bufnr })
    return bufnr
  end
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
      local filepath = dot.path.resolve(cwd, filename) ---@type string
      existed_paths[filepath] = true
    end
  end

  for i = 1, 100 do
    local filepath = dot.path.join(cwd, dot.var.BUF_UNTITLED .. "-" .. tostring(i)) ---@type string
    if not existed_paths[filepath] and vim.uv.fs_stat(filepath) == nil then
      return filepath
    end
  end
  return nil
end

---@param bufnr                         integer|nil
---@param force                         boolean
---@return dot.buf.IMeta|nil
function M.resolve(bufnr, force)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  if not vim.bo[bufnr].buflisted then
    return nil
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string|nil
  if filepath == nil or #filepath < 1 then
    return nil
  end

  local meta = meta_map[bufnr] ---@type dot.buf.IMeta|nil
  if meta ~= nil and meta.filepath == filepath and not force then
    return meta
  end

  local dirpath_pieces = yoz.path.split(filepath, false) ---@type string[]
  dirpath_pieces[#dirpath_pieces] = nil

  local cwd = dot.path.cwd() ---@type string
  local filename = yoz.path.basename(filepath) ---@type string
  local fileicon, fileicon_hln = stl.fileicon.get_file_icon(filename) ---@type string, string
  local relpath = dot.path.relative(cwd, filepath) ---@type string

  if meta == nil then
    ---@type dot.buf.IMeta
    meta = {
      dirpath_pieces = dirpath_pieces,
      filename = filename,
      filepath = filepath,
      relpath = relpath,
      fileicon = fileicon,
      fileicon_hln = fileicon_hln,
    }
    meta_map[bufnr] = meta
  else
    meta.dirpath_pieces = dirpath_pieces
    meta.filename = filename
    meta.filepath = filepath
    meta.relpath = relpath
    meta.fileicon = fileicon
    meta.fileicon_hln = fileicon_hln
  end

  return meta
end

----------------------------------------------------------------------------------------------------

---@param bufnr                         integer|nil
---@return nil
function M.on_close(bufnr)
  if bufnr == nil then
    return
  end

  meta_map[bufnr] = nil
end

return M
