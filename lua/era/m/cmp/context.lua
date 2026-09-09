---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.context" ---@type string

---@class era.m.cmp.IContext
---@field public bufnr                  integer
---@field public row                    integer
---@field public col                    integer
---@field public line                   string
---@field public filetype               string
---@field public start_col              integer
---@field public end_col                integer
---@field public keyword                string

---@class era.m.cmp.context
local M = {}

---@param params                        lsp.CompletionParams
---@param preferred_bufnr               ?integer
---@return era.m.cmp.IContext|nil
function M.from_params(params, preferred_bufnr)
  local uri = params.textDocument.uri
  local bufnr = preferred_bufnr or vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.uri_from_bufnr(bufnr) ~= uri then
    return nil
  end
  local row = params.position.line
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local col = math.min(params.position.character, #line)
  local start_col, end_col = yoz.cmp.keyword_range(line, col, true)
  return {
    bufnr = bufnr,
    row = row,
    col = col,
    line = line,
    filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }),
    start_col = start_col,
    end_col = end_col,
    keyword = line:sub(start_col + 1, col),
  }
end

---@param previous                      era.m.cmp.IContext
---@param current                       era.m.cmp.IContext
---@return boolean
function M.same_token(previous, current)
  return previous.bufnr == current.bufnr
    and previous.row == current.row
    and previous.start_col == current.start_col
    and previous.line:sub(1, previous.start_col) == current.line:sub(1, current.start_col)
    and previous.line:sub(previous.end_col + 1) == current.line:sub(current.end_col + 1)
end

---@param previous                      era.m.cmp.IContext
---@param current                       era.m.cmp.IContext
---@return boolean
function M.extends(previous, current)
  return previous.bufnr == current.bufnr
    and previous.row == current.row
    and previous.start_col == current.start_col
    and previous.col <= current.col
    and previous.line:sub(1, previous.col) == current.line:sub(1, previous.col)
    and previous.line:sub(previous.col + 1) == current.line:sub(current.col + 1)
end

return M
