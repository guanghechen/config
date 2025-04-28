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

---@class eve.builtin.buf.IMetaData
---@field public filepath               string
---@field public relpath                string
---@field public filename               string
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

---@class eve.builtin.buf
local M = {}

M.Types = vim.deepcopy(Types)

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

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local bufpath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if bufpath == filepath then
      return bufnr
    end
  end

  if eve.path.is_exist_filepath(filepath) then
    local bufnr = vim.fn.bufadd(filepath) ---@type integer
    vim.bo[bufnr].buflisted = true
    vim.fn.bufload(bufnr)
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

---@param bufnr                         integer|nil
---@return eve.builtin.buf.IMetaData|nil
function M.resolve(bufnr)
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

  local cwd = eve.path.cwd() ---@type string
  if vim.b[bufnr].eve_filepath == filepath or vim.b[bufnr].eve_cwd == cwd then
    local relpath = vim.b[bufnr].eve_relpath ---@type string
    local filename = vim.b[bufnr].eve_filename ---@type string
    local fileicon = vim.b[bufnr].eve_fileicon ---@type string
    local fileicon_hln = vim.b[bufnr].eve_fileicon_hln ---@type string

    ---@type eve.builtin.buf.IMetaData
    local meta = {
      filepath = filepath,
      relpath = relpath,
      filename = filename,
      fileicon = fileicon,
      fileicon_hln = fileicon_hln,
    }
    return meta
  end

  local relpath = eve.path.relative(cwd, filepath, false) ---@type string
  local filename = eve.path.basename(filepath) ---@type string
  local fileicon, fileicon_hln = eve.fn.fileicon(filename) ---@type string, string

  vim.b[bufnr].eve_cwd = cwd
  vim.b[bufnr].eve_filepath = filepath
  vim.b[bufnr].eve_relpath = relpath
  vim.b[bufnr].eve_filename = filename
  vim.b[bufnr].eve_fileicon = fileicon
  vim.b[bufnr].eve_fileicon_hln = fileicon_hln

  ---@type eve.builtin.buf.IMetaData
  local meta = {
    filepath = filepath,
    relpath = relpath,
    filename = filename,
    fileicon = fileicon,
    fileicon_hln = fileicon_hln,
  }
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

return M
