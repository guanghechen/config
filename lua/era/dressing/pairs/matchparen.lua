---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.pairs.matchparen" ---@type string

--- Highlights the pair at the cursor, or the innermost pair around it.
---@class era.dressing.pairs.matchparen
local M = {}

local GROUP = "f_matched_pairs_0" ---@type string
local PRIORITY = 250 ---@type integer

local namespace = vim.api.nvim_create_namespace(__module_name__) ---@type integer
local shown_bufnr = nil ---@type integer|nil
-- The document revision and the pair shown: revisions differ across documents, and moving the cursor within the
-- pair leaves the marks, and the lines between them, as they are.
local shown_key = nil ---@type string|nil

---@return nil
local function clear()
  if shown_bufnr ~= nil and vim.api.nvim_buf_is_valid(shown_bufnr) then
    vim.api.nvim_buf_clear_namespace(shown_bufnr, namespace, 0, -1)
  end
  shown_bufnr, shown_key = nil, nil
end

---@return nil
local function update()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local document = era.m.pairs.document(bufnr)
  if not document then
    clear()
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local open_row, open_col, open_len, close_row, close_col, close_len =
    document:surrounding_pair(cursor[1] - 1, cursor[2])
  if not (open_row and open_col and open_len and close_row and close_col and close_len) then
    clear()
    return
  end
  local key = string.format("%d:%d:%d:%d:%d", document:revision(), open_row, open_col, close_row, close_col)
  if key == shown_key then
    return
  end
  clear()
  vim.api.nvim_buf_set_extmark(bufnr, namespace, open_row, open_col, {
    end_col = open_col + open_len,
    hl_group = GROUP,
    priority = PRIORITY,
  })
  vim.api.nvim_buf_set_extmark(bufnr, namespace, close_row, close_col, {
    end_col = close_col + close_len,
    hl_group = GROUP,
    priority = PRIORITY,
  })
  shown_bufnr, shown_key = bufnr, key
end

---@param augroup                       integer
---@return nil
function M.setup(augroup)
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "TextChanged", "WinEnter" }, {
    group = augroup,
    callback = update,
  })
end

return M
