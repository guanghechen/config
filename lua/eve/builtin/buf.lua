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

local buftype_attrs = {
  focusable = {
    [Types.EMPTY] = true,
    [Types.ACWRITE] = true,
    [Types.HELP] = true,
    [Types.NOFILE] = true,
    [Types.NOWRITE] = true,
    [Types.QUICKFIX] = true,
    [Types.TERMINAL] = true,
    [Types.PROMPT] = true,
  },
  projectable = {
    [Types.EMPTY] = true,
    [Types.ACWRITE] = true,
    [Types.NOFILE] = true,
    [Types.NOWRITE] = true,
  },
  sourcefile = {
    [Types.EMPTY] = true,
    [Types.ACWRITE] = true,
    [Types.NOFILE] = true,
    [Types.NOWRITE] = true,
  },
  swappable = {
    [Types.EMPTY] = true,
    [Types.ACWRITE] = true,
    [Types.HELP] = true,
    [Types.NOFILE] = true,
    [Types.NOWRITE] = true,
    [Types.QUICKFIX] = true,
    [Types.TERMINAL] = true,
    [Types.PROMPT] = true,
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
