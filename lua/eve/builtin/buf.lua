local __module_name__ = "eve.builtin.buf" ---@type string

---@alias eve.builtin.buf.TypeEnum
---| ""
---| "acwrite"
---| "help"
---| "nofile"
---| "nowrite"
---| "quickfix"
---| "terminal"
---| "prompt"

---@class eve.builtin.buf.Types
local Types = {
  EMPTY = "",
  ACWRITE = "acwrite",
  HELP = "help",
  NOFILE = "nofile",
  NOWRITE = "nowrite",
  QUICKFIX = "quickfix",
  TERMINAL = "terminal",
  PROMPT = "prompt",
}

---@class eve.builtin.buf.IMeta
---@field public dirpath_pieces         string[]
---@field public filename               string
---@field public filepath               string
---@field public relpath                string
---@field public fileicon               string
---@field public fileicon_hln           string

local buftype_attrs = {
  sourcefile = {
    [Types.EMPTY] = true,
    [Types.ACWRITE] = true,
    [Types.NOFILE] = true,
    [Types.NOWRITE] = true,
  },
}

local meta_map = {} ---@type table<integer, eve.builtin.buf.IMeta|nil>

---@class eve.builtin.buf
local M = {}

M.Types = vim.deepcopy(Types)

---@param bufnr                         integer|nil
---@return nil
function M.close(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

---@param bufnr                         integer
---@return boolean
function M.is_editable(bufnr)
  return vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable and not vim.bo[bufnr].readonly
end

---@param bufnr                         integer
---@return boolean
function M.is_sourcefile(bufnr)
  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype_attrs.sourcefile[buftype] ~= true then
    return false
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if eve.filetype.is_not_sourcefile(filetype) then
    return false
  end

  return true
end

---@param bufnr                         integer
---@return boolean
function M.is_valid(bufnr)
  return bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

---@param filepath                      string|nil
---@return integer|nil
function M.loadfile(filepath)
  if filepath == nil or #filepath < 1 then
    return nil
  end

  local bufnr_sourcefile = M.locate_bufnr(filepath) ---@type integer|nil)
  if bufnr_sourcefile ~= nil then
    vim.bo[bufnr_sourcefile].buflisted = true
    return bufnr_sourcefile
  end

  if std.path.is_exist_filepath(filepath) then
    local bufnr = vim.fn.bufadd(filepath) ---@type integer
    if bufnr == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
      return nil
    end

    vim.bo[bufnr].buflisted = true
    vim.bo[bufnr].buftype = ""
    vim.bo[bufnr].swapfile = false

    local ok, error = pcall(vim.fn.bufload, bufnr)
    if not ok then
      std.reporter.error({
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

    vim.bo[bufnr].swapfile = true
    -- vim.api.nvim_exec_autocmds("FileReadPost", { buffer = bufnr })
    -- vim.api.nvim_exec_autocmds("BufReadPost", { buffer = bufnr })
    return bufnr
  end
end

---@param filepath                      string
---@return integer|nil
function M.locate_bufnr(filepath)
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local bufpath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if bufpath == filepath then
      vim.bo[bufnr].buflisted = true
      return bufnr
    end
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
      local filepath = std.path.resolve(cwd, filename) ---@type string
      existed_paths[filepath] = true
    end
  end

  for i = 1, 100 do
    local filepath = std.path.join(cwd, eve.setting.BUF_UNTITLED .. "-" .. tostring(i)) ---@type string
    if not existed_paths[filepath] and vim.uv.fs_stat(filepath) == nil then
      return filepath
    end
  end
  return nil
end

---@param bufnr                         integer|nil
---@param force                         boolean
---@return eve.builtin.buf.IMeta|nil
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

  local meta = meta_map[bufnr] ---@type eve.builtin.buf.IMeta|nil
  if meta ~= nil and meta.filepath == filepath and not force then
    return meta
  end

  local cwd = std.path.cwd() ---@type string
  local dirpath_pieces = std.path.split(std.path.dirname(filepath)) ---@type string[]
  local filename = std.path.basename(filepath) ---@type string
  local fileicon, fileicon_hln = std.fileicon.get_file_icon(filename) ---@type string, string
  local relpath = std.path.relative(cwd, filepath, false) ---@type string

  if meta == nil then
    ---@type eve.builtin.buf.IMeta
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

---@return string
function M.retrieve_selected_text()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == Types.TERMINAL or buftype == Types.PROMPT then
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
function M.retrieve_visual_lnum_range()
  local lnum_1 = vim.fn.getcurpos()[2] ---@type integer
  local lnum_2 = vim.fn.line("v") ---@type integer
  if lnum_1 < lnum_2 then
    return lnum_1, lnum_2
  end
  return lnum_2, lnum_1
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
