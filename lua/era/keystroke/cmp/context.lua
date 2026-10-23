---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.context" ---@type string

local M = {}
local keyword = vim.regex([[\k\%(\k\|-\)*$]])
local keyword_suffix = vim.regex([[^\%(\k\|-\)*]])
local versions = {} ---@type table<integer, integer>
-- A detached buffer can be loaded again; forgotten versions must never be reused.
local version = 0

---@param bufnr                         integer
---@return nil
function M.invalidate(bufnr)
  version = version + 1
  versions[bufnr] = version
end

---@param bufnr                         integer
---@return nil
function M.forget(bufnr)
  versions[bufnr] = nil
end

---@param line                          string
---@param col                           integer
---@return integer
function M.start_col(line, col)
  local before = line:sub(1, col)
  local start_col = keyword:match_str(before)
  return start_col or col
end

---@param before                        era.keystroke.cmp.IContext
---@param after                         era.keystroke.cmp.IContext
---@param include_start                 boolean
---@return boolean
function M.within_query(before, after, include_start)
  if before.bufnr ~= after.bufnr or before.winnr ~= after.winnr or before.row ~= after.row then
    return false
  end
  local _, length = keyword_suffix:match_str(before.line:sub(before.col + 1))
  return after.col >= before.start_col + (include_start and 0 or 1) and after.col <= before.col + (length or 0)
end

---@param trigger                       ?string
---@return era.keystroke.cmp.IContext|nil
function M.capture(trigger)
  local mode = vim.api.nvim_get_mode().mode
  if mode:sub(1, 1) ~= "i" and mode:sub(1, 1) ~= "s" then
    return nil
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if versions[bufnr] == nil then
    M.invalidate(bufnr)
  end
  local winnr = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local line = vim.api.nvim_buf_get_lines(bufnr, cursor[1] - 1, cursor[1], false)[1]
  if line == nil then
    -- A terminating signal unloads buffer contents before VimLeavePre runs.
    return nil
  end
  local col = cursor[2]
  local start_col = M.start_col(line, col)
  return {
    bufnr = bufnr,
    winnr = winnr,
    row = cursor[1] - 1,
    col = col,
    line = line,
    start_col = start_col,
    keyword = line:sub(start_col + 1, col),
    filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }),
    changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
    modified = vim.api.nvim_get_option_value("modified", { buf = bufnr }),
    buffer_version = versions[bufnr],
    trigger = trigger or "typing",
  }
end

---@param path                          string
---@return boolean
function M.is_private(path)
  local name = path:match("[^/\\]+$") or path
  return name:match("^%.env") ~= nil
    or name:match("%.http%.out$") ~= nil
    or name:match("%.http_request$") ~= nil
    or name:match("%.http_response$") ~= nil
    or name == ".git-credentials"
    or path:match("[/\\]%.ssh[/\\]") ~= nil
    or path:match("[/\\]%.credentials[/\\]") ~= nil
    or path:match("[/\\]local[/\\]env%.") ~= nil
end

---@param context                       era.keystroke.cmp.IContext
---@return boolean
function M.enabled(context)
  return vim.api.nvim_get_option_value("buftype", { buf = context.bufnr }) ~= "nowrite"
    and vim.api.nvim_get_option_value("modifiable", { buf = context.bufnr })
    and not M.is_private(vim.api.nvim_buf_get_name(context.bufnr))
    and stl.filetype.is_cmp_enabled(context.filetype)
end

---@param before                        era.keystroke.cmp.IContext
---@param after                         ?era.keystroke.cmp.IContext
---@return boolean
function M.same_input(before, after)
  return after ~= nil
    and before.bufnr == after.bufnr
    and before.winnr == after.winnr
    and before.row == after.row
    and before.col == after.col
    and before.line == after.line
    and before.filetype == after.filetype
    and before.start_col == after.start_col
    and before.buffer_version == after.buffer_version
end

---@param before                        era.keystroke.cmp.IContext
---@param after                         era.keystroke.cmp.IContext
---@param start_col                     ?integer
---@return boolean
function M.compatible(before, after, start_col)
  start_col = start_col or before.start_col
  return before.bufnr == after.bufnr
    and before.winnr == after.winnr
    and before.row == after.row
    and before.filetype == after.filetype
    and before.start_col == after.start_col
    and before.buffer_version == after.buffer_version
    and after.col >= start_col
    and before.line:sub(1, start_col) == after.line:sub(1, start_col)
    and before.line:sub(before.col + 1) == after.line:sub(after.col + 1)
end

---@param before                        era.keystroke.cmp.IContext
---@param after                         era.keystroke.cmp.IContext
---@return boolean
function M.extends(before, after)
  return before.start_col == after.start_col
    and M.compatible(before, after)
    and vim.startswith(after.keyword, before.keyword)
end

return M
