---@alias ark.vim.buf.TypeEnum
---| ""
---| "acwrite"
---| "help"
---| "nofile"
---| "nowrite"
---| "quickfix"
---| "terminal"
---| "prompt"

local CONTENT_SPLITLINE = string.rep("-", 100) ---@type string

---@class ark.vim.buf.Types
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
  sourcefile = {
    [Types.EMPTY] = true,
    [Types.ACWRITE] = true,
    [Types.NOFILE] = true,
    [Types.NOWRITE] = true,
  },
}

local filepath_to_bufnr = {} ---@type table<string, integer>
local bufnr_to_filepath = {} ---@type table<integer, string>

---@class ark.vim.buf
local M = {}

M.CONTENT_SPLITLINE = CONTENT_SPLITLINE ---@type string
M.Types = vim.deepcopy(Types)

---@param bufnr                         integer|nil
---@return nil
function M.close(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

---@param bufnr                         integer|nil
---@return boolean
function M.is_editable(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  return vim.bo[bufnr].buftype == "" and vim.bo[bufnr].modifiable and not vim.bo[bufnr].readonly
end

---@param bufnr                         integer|nil
---@return boolean
function M.is_sourcefile(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype_attrs.sourcefile[buftype] ~= true then
    return false
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if stl.filetype.is_not_sourcefile(filetype) then
    return false
  end

  return true
end

---@param bufnr                         integer
---@return boolean
function M.is_valid(bufnr)
  return bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

---@return table<string, integer>
function M.filepath2bufnr()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local result = {} ---@type table<string, integer>

  for _, bufnr in ipairs(bufnrs) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    if filepath ~= nil and #filepath > 0 then
      result[filepath] = bufnr
    end
  end
  return result
end

---@return table<string, integer>
function M.get_loaded_bufnrs()
  local result = {} ---@type table<string, integer>
  for filepath, bufnr in pairs(filepath_to_bufnr) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
      result[filepath] = bufnr
    end
  end
  return result
end

---@param filepath                      string
---@return integer|nil
function M.locate_bufnr(filepath)
  local bufnr = filepath_to_bufnr[filepath] ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  filepath_to_bufnr[filepath] = nil
  if bufnr ~= nil then
    bufnr_to_filepath[bufnr] = nil
  end

  bufnr = vim.fn.bufnr(filepath) ---@type integer
  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end
end

---@param bufnr                         integer
---@param filepath                      string
---@return nil
function M.on_buf_open(bufnr, filepath)
  if bufnr < 1 or filepath == "" then
    return
  end

  local old_filepath = bufnr_to_filepath[bufnr] ---@type string|nil
  if old_filepath ~= nil and old_filepath ~= filepath then
    filepath_to_bufnr[old_filepath] = nil
  end

  filepath_to_bufnr[filepath] = bufnr
  bufnr_to_filepath[bufnr] = filepath
end

---@param bufnr                         integer
---@return nil
function M.on_buf_close(bufnr)
  local old_filepath = bufnr_to_filepath[bufnr] ---@type string|nil
  if old_filepath ~= nil then
    filepath_to_bufnr[old_filepath] = nil
    bufnr_to_filepath[bufnr] = nil
  end
end

---@return string
function M.retrieve_selected_text()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == Types.TERMINAL or buftype == Types.PROMPT then
    return ""
  end

  local saved_reg = vim.fn.getreg("v") ---@type string
  vim.cmd([[noautocmd sil norm! "vy]])

  local selected_text = vim.fn.getreg("v") ---@type string
  vim.fn.setreg("v", saved_reg)
  return selected_text or ""
end

---@param winnr                         integer
---@return string
function M.retrieve_split_block(winnr)
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local cursor_line = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer

  local lft = 0 ---@type integer
  for i = cursor_line, 1, -1 do
    if lines[i] == CONTENT_SPLITLINE then
      lft = i
      break
    end
  end

  local rht = #lines + 1 ---@type integer
  for i = cursor_line, #lines do
    if lines[i] == CONTENT_SPLITLINE then
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

---@return integer
---@return integer
function M.retrieve_visual_lnum_range()
  local start_pos = vim.fn.getpos("v") -- visual selection start
  local end_pos = vim.fn.getpos(".") -- visual selection end (cursor)

  local lnum_start = start_pos[2] ---@type integer
  local lnum_end = end_pos[2] ---@type integer

  if lnum_start < lnum_end then
    return lnum_start, lnum_end
  end
  return lnum_end, lnum_start
end

---@return integer
---@return integer
---@return integer
---@return integer
function M.retrieve_visual_range()
  local s_pos = vim.fn.getpos("v") -- visual selection start
  local e_pos = vim.fn.getpos(".") -- visual selection end (cursor)

  local s_lnum = s_pos[2] ---@type integer
  local s_col = s_pos[3] ---@type integer
  local e_lnum = e_pos[2] ---@type integer
  local e_col = e_pos[3] ---@type integer

  if s_lnum < e_lnum then
    return s_lnum, s_col, e_lnum, e_col
  end

  if s_lnum == e_lnum and s_col < e_col then
    return s_lnum, s_col, e_lnum, e_col
  end

  return e_lnum, e_col, s_lnum, s_col
end

---@param bufnr                         integer
---@param lnum_start                    integer
---@param col_start                     integer
---@param lnum_end                      integer
---@param col_end                       integer
---@return string[]
function M.retrieve_visual_range_lines(bufnr, lnum_start, col_start, lnum_end, col_end)
  local lines = vim.api.nvim_buf_get_lines(bufnr, lnum_start - 1, lnum_end, false) ---@type string[]
  local N = #lines ---@type integer

  if N == 0 then
    return {}
  end

  if N == 1 then
    lines[1] = string.sub(lines[1], col_start, col_end)
  end

  if N > 1 then
    lines[1] = string.sub(lines[1], col_start, -1)
    lines[N] = string.sub(lines[N], 1, col_end)
  end

  return lines
end

return M
