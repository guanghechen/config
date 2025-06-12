---@class fml.dressing.foldexpr
local M = {}

---@return string
function M.foldexpr()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return "0"
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if not eve.filetype.is_language(filetype) then
    return "0"
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "terminal" then
    return "0"
  end

  local has_ts_parser = vim.b[bufnr].has_ts_parser ---@type boolean|nil
  if has_ts_parser == nil then
    local ok = pcall(vim.treesitter.get_parser, bufnr)
    vim.b[bufnr].has_ts_parser = ok
    has_ts_parser = ok
  end

  local lnum = vim.v.lnum ---@type integer|nil
  return has_ts_parser and vim.treesitter.foldexpr(lnum) or "0" ---@type string
end

vim.o.foldexpr = "v:lua.require'fml.dressing.foldexpr'.foldexpr()"

return M
