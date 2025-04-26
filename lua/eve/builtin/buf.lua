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
  if eve.filetype.is_not_sourcefile_filetype(filetype) then
    return false
  end

  return true
end

---@param bufnr                         integer
---@return boolean
function M.is_valid(bufnr)
  return bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

return M
