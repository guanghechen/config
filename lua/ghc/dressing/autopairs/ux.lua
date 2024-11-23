local config = require("ghc.dressing.autopairs.config")
local Portion = require("ghc.dressing.autopairs.portion")

---@param bufnr                         integer
---@param nsnr                          integer
---@param pair                          ghc.dressing.autopairs.IPair
---@return nil
local function draw_pair(bufnr, nsnr, pair)
  local left = pair.left ---@type ghc.dressing.autopairs.IPos
  local right = pair.right ---@type ghc.dressing.autopairs.IPos
  vim.api.nvim_buf_add_highlight(bufnr, nsnr, "MatchParen", left.row - 1, left.col - 1, left.col)
  vim.api.nvim_buf_add_highlight(bufnr, nsnr, "MatchParen", right.row - 1, right.col - 1, right.col)
end

---Find a right delimiter of a pair.
---
---@param portion                       ghc.dressing.autopairs.Portion `Portion` to look inside of.
---@return ghc.dressing.autopairs.IPos|nil
---@return string|nil
local function find_right_delimiter(portion)
  local remaining = 0 ---@type integer
  for cursor, char in portion:iter() do
    if config.left_to_right_pairs[char] ~= nil then
      remaining = remaining + 1
    elseif config.right_to_left_pairs[char] ~= nil then
      if remaining == 0 then
        return cursor, char
      end
      remaining = remaining - 1
    end
  end
  return nil, nil
end

---Find a left delimiter of a pair.
---
---@param portion                       ghc.dressing.autopairs.Portion `Portion` to look inside of.
---@return ghc.dressing.autopairs.IPos|nil
---@return string|nil
local function find_left_delimiter(portion)
  local remaining = 0 ---@type integer
  for cursor, char in portion:iter_reverse() do
    if config.right_to_left_pairs[char] ~= nil then
      remaining = remaining + 1
    elseif config.left_to_right_pairs[char] ~= nil then
      if remaining == 0 then
        return cursor, char
      end
      remaining = remaining - 1
    end
  end
  return nil, nil
end

---Find a right delimiter of a specific pair.
---
---@param portion                       ghc.dressing.autopairs.Portion `Portion` to look inside of.
---@param left_delimiter                string Left side of the desired pair.
---@param right_delimiter               string Right side of the desired pair.
---@return ghc.dressing.autopairs.IPos|nil
local function find_specific_right_delimiter(portion, left_delimiter, right_delimiter)
  local remaining = 0 ---@type integer
  for cursor, char in portion:iter() do
    if char == left_delimiter then
      remaining = remaining + 1
    elseif char == right_delimiter then
      if remaining == 0 then
        return cursor
      end
      remaining = remaining - 1
    end
  end
  return nil
end

---Find a left delimiter of a specific pair.
---
---@param portion                       ghc.dressing.autopairs.Portion `Portion` to look inside of.
---@param left_delimiter                string Left side of the desired pair.
---@param right_delimiter               string Right side of the desired pair.
---@return ghc.dressing.autopairs.IPos|nil
local function find_specific_left_delimiter(portion, left_delimiter, right_delimiter)
  local remaining = 0 ---@type integer
  for cursor, char in portion:iter_reverse() do
    if char == right_delimiter then
      remaining = remaining + 1
    elseif char == left_delimiter then
      if remaining == 0 then
        return cursor
      end
      remaining = remaining - 1
    end
  end
  return nil
end

---Find both sides of a pair.
---
---@param portion                       ghc.dressing.autopairs.Portion `Portion` to look inside of.
---@return ghc.dressing.autopairs.IPair|nil
local function find_pair(portion)
  local under_cursor = portion:get_current_char() ---@type string
  local cursor = portion:get_cursor() ---@type ghc.dressing.autopairs.IPos

  local left ---@type ghc.dressing.autopairs.IPos|nil
  local right ---@type ghc.dressing.autopairs.IPos|nil

  local right_delimiter = config.left_to_right_pairs[under_cursor] ---@type string|nil
  local left_delimiter = config.right_to_left_pairs[under_cursor] ---@type string|nil
  if right_delimiter ~= nil then
    left = cursor
    right = find_specific_right_delimiter(portion, under_cursor, right_delimiter)
  elseif left_delimiter ~= nil then
    left = find_specific_left_delimiter(portion, left_delimiter, under_cursor)
    right = cursor
  else
    local found_left = nil
    left, found_left = find_left_delimiter(portion)

    if found_left == nil then
      right = find_right_delimiter(portion)
    else
      local found_right = config.left_to_right_pairs[found_left] ---@type string|nil
      if found_right ~= nil then
        right = find_specific_right_delimiter(portion, found_left, found_right)
      end
    end
  end

  if left == nil or right == nil then
    return nil
  end

  local pair = { left = left, right = right } ---@type ghc.dressing.autopairs.IPair
  return pair
end

---@class ghc.dressing.autopairs.ux
local M = {}

---Clear `Pair` highlights.
---
---@param bufnr                         integer
---@return nil
function M.clear(bufnr)
  local nsnr = vim.api.nvim_create_namespace(config.NAMESPACE_PAIR) ---@type integer
  local ok, viewport = pcall(vim.api.nvim_buf_get_var, bufnr, config.VARIABLE_VIEWPORT)
  if ok then
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, viewport[1] - 1, viewport[2])
  end
end

---Calculate and draw the found `Pair`.
---
---@async
---@param winnr                         ?integer Window to be rendered inside.
---@return uv.uv_timer_t|nil
function M.render(winnr)
  winnr = winnr or vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  local mode = vim.fn.mode() ---@type string
  if not config.enabled_modes[mode] then
    M.clear(bufnr)
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  if not eve.filetype.is_plain_file(filetype) then
    M.clear(bufnr)
    return
  end

  local win_cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local cursor_row = win_cursor[1] --@type integer
  local cursor_col = win_cursor[2] + 1 --@type integer

  return vim.defer_fn(function()
    if not vim.api.nvim_win_is_valid(winnr) or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local portion = Portion.new(winnr, config.SEARCH_WINDOW_HALF_HEIGHT)
    local cursor = portion:get_cursor() ---@type ghc.dressing.autopairs.IPos
    if cursor.row ~= cursor_row or cursor.col ~= cursor_col then
      return
    end

    M.clear(bufnr)
    vim.api.nvim_buf_set_var(bufnr, config.VARIABLE_VIEWPORT, { portion:get_top(), portion:get_bottom() })
    local pair = find_pair(portion) ---@type ghc.dressing.autopairs.IPair|nil
    if pair ~= nil then
      local nsnr_pair = vim.api.nvim_create_namespace(config.NAMESPACE_PAIR) ---@type integer
      draw_pair(bufnr, nsnr_pair, pair)
    end
  end, config.DELAY)
end

return M
