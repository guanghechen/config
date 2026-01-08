local SPLITLINE_LEGACY = string.rep("-", 100) ---@type string
local SPLITLINE_PATTERN = "^%-+%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%-+$" ---@type string
local SPLITLINE_TOTAL_LEN = 100 ---@type integer

local SPLITLINE_FILETYPES = {
  lua = true,
  markdown = true,
  [stl.filetype.NOTEPAD] = true,
}

---@class era.m.splitline
local M = {}

---@return string
function M.make()
  local timestamp = os.date("%Y-%m-%d %H:%M:%S") --[[@as string]]
  local timestamp_len = #timestamp ---@type integer
  local left_len = math.floor((SPLITLINE_TOTAL_LEN - timestamp_len) / 2) ---@type integer
  local right_len = SPLITLINE_TOTAL_LEN - timestamp_len - left_len ---@type integer
  return string.rep("-", left_len) .. timestamp .. string.rep("-", right_len)
end

---@param line                         string
---@return boolean
function M.is_splitline(line)
  return line == SPLITLINE_LEGACY or line:match(SPLITLINE_PATTERN) ~= nil
end

---@return nil
function M.insert()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  if vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then
    local FEEDBACK_KEY = dot.var.K_CODE_INSERT_SPLITLINE ---@type string
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(FEEDBACK_KEY, true, false, true), "n", false)
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if not SPLITLINE_FILETYPES[filetype] then
    local FEEDBACK_KEY = dot.var.K_CODE_INSERT_SPLITLINE ---@type string
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(FEEDBACK_KEY, true, false, true), "n", false)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local row = cursor[1] ---@type integer
  local content = M.make() ---@type string
  vim.api.nvim_buf_set_lines(bufnr, row, row, false, { "", content, "" })
  vim.api.nvim_win_set_cursor(winnr, { row + 2, 0 })
end

---@param winnr                         integer
---@return string
function M.retrieve_block(winnr)
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local cursor_line = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer

  local lft = 0 ---@type integer
  for i = cursor_line, 1, -1 do
    if M.is_splitline(lines[i]) then
      lft = i
      break
    end
  end

  local rht = #lines + 1 ---@type integer
  for i = cursor_line, #lines do
    if M.is_splitline(lines[i]) then
      rht = i
      break
    end
  end

  while lft + 1 < rht and lines[lft + 1]:match("^%s*$") do
    lft = lft + 1
  end

  while rht - 1 > lft and lines[rht - 1]:match("^%s*$") do
    rht = rht - 1
  end

  local text = table.concat(lines, "\n", lft + 1, rht - 1) ---@type string
  return text
end

return M
