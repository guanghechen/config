---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.util" ---@type string

local M = {}

----------------------------------------------------------------------------------------------------
-- Cache
----------------------------------------------------------------------------------------------------

---@type table<integer, table<integer, table<integer, integer>>>
local virtual_line_count_cache = vim.defaulttable()

---@type table<integer, integer[]>
local virtual_topline_lookup_cache = vim.defaulttable()

----------------------------------------------------------------------------------------------------
-- Cache invalidation
----------------------------------------------------------------------------------------------------

---@param winid                       integer
function M.invalidate_virtual_line_count_cache(winid)
  virtual_line_count_cache[winid] = nil
end

function M.invalidate_virtual_topline_lookup()
  virtual_topline_lookup_cache = vim.defaulttable()
end

----------------------------------------------------------------------------------------------------
-- Window utilities
----------------------------------------------------------------------------------------------------

---Returns the height of a window excluding the winbar.
---@param winid                       integer
---@return integer
function M.get_winheight(winid)
  local winheight = vim.api.nvim_win_get_height(winid)
  if vim.api.nvim_get_option_value("winbar", { win = winid }) ~= "" then
    winheight = winheight - 1
  end
  return winheight
end

---Return top line and bottom line in window. For folds, the top line
---represents the start of the fold and the bottom line represents the end of
---the fold.
---@param winid                       integer
---@return integer topline
---@return integer botline
function M.visible_line_range(winid)
  ---@diagnostic disable-next-line: missing-return-value
  return unpack(vim.api.nvim_win_call(winid, function()
    local topline = vim.fn.line("w0")
    local botline = math.max(vim.fn.line("w$"), topline)
    ---@diagnostic disable-next-line: redundant-return-value
    return { topline, botline }
  end))
end

---Returns true for ordinary windows (not floating and not external), and false
---otherwise.
---@param winid                       integer
---@return boolean
function M.is_ordinary_window(winid)
  local cfg = vim.api.nvim_win_get_config(winid)
  local not_external = not cfg["external"]
  local not_floating = cfg["relative"] == ""
  return not_external and not_floating
end

---@param winid                       integer|nil
---@return boolean
function M.in_cmdline_win(winid)
  winid = winid or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  if vim.fn.win_gettype(winid) == "command" then
    return true
  end
  local bufnr = vim.api.nvim_win_get_buf(winid)
  return vim.api.nvim_buf_get_name(bufnr) == "[Command Line]"
end

----------------------------------------------------------------------------------------------------
-- Virtual line calculation (fold support)
----------------------------------------------------------------------------------------------------

---Returns the count of virtual lines between the specified start and end lines
---(both inclusive), in the specified window. A closed fold counts as one
---virtual line.
---@param winid                       integer
---@param start                       integer
---@param vend                        integer|nil
---@return integer
function M.virtual_line_count(winid, start, vend)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local max_vend = vim.api.nvim_buf_line_count(bufnr) - 1
  vend = vend or max_vend

  if vend == 0 then
    return 0
  end

  local win_cache = rawget(virtual_line_count_cache, winid)
  if win_cache then
    local start_cache = rawget(win_cache, start)
    if start_cache then
      local cached = rawget(start_cache, vend)
      if cached then
        return cached
      end
    end
  end

  if vim.api.nvim_win_text_height then
    local res = vim.api.nvim_win_text_height(winid, {
      start_row = start,
      end_row = math.min(vend, max_vend),
    })
    ---@cast res -string
    virtual_line_count_cache[winid][start][vend] = res.all
    return res.all
  end

  return vim.api.nvim_win_call(winid, function()
    local vline = 0
    local line = start
    while line <= vend do
      vline = vline + 1
      local foldclosedend = vim.fn.foldclosedend(line)
      if foldclosedend ~= -1 then
        line = foldclosedend
      end
      virtual_line_count_cache[winid][start][line] = vline
      line = line + 1
    end
    return vline
  end)
end

----------------------------------------------------------------------------------------------------
-- Position mapping
----------------------------------------------------------------------------------------------------

---Round to the nearest integer.
---WARN: .5 rounds to the right on the number line, including for negatives
---(which would not result in rounding up in magnitude).
---(e.g., round(3.5) == 3, round(-3.5) == -3 != -4)
---@param x                           number
---@return integer
function M.round(x)
  return math.floor(x + 0.5)
end

---@param winid                       integer
---@param row                         integer
---@param row2                        integer
---@return number
local function height_to_virtual(winid, row, row2)
  local vlinecount0 = M.virtual_line_count(winid, 1) - 1
  local vheight = M.virtual_line_count(winid, row, row2)
  local winheight0 = M.get_winheight(winid) - 1
  return winheight0 * vheight / vlinecount0
end

---@param winid                       integer
---@param row                         integer
---@param row2                        integer
---@return integer
function M.height_to_virtual(winid, row, row2)
  local height = M.round(height_to_virtual(winid, row, row2))
  if height < 1 then
    height = 1
  end
  return height
end

---@param winid                       integer
---@param row                         integer
---@return integer pos
---@return number fraction
function M.row_to_barpos(winid, row)
  local v = height_to_virtual(winid, 1, row)
  local vr = M.round(v)
  return vr, vr - v
end

---Returns an array that maps window rows to the topline that corresponds to a
---scrollbar at that row under virtual satellite mode, in the current window.
---The computation primarily loops over lines, but may loop over virtual spans
---as part of calling 'virtual_line_count', so the cursor may be moved.
---@param winid                       integer
---@return table<integer, integer>
function M.virtual_topline_lookup(winid)
  if rawget(virtual_topline_lookup_cache, winid) then
    return virtual_topline_lookup_cache[winid]
  end

  local winheight = M.get_winheight(winid)
  local total_vlines = M.virtual_line_count(winid, 1)
  if not (total_vlines > 1 and winheight > 1) then
    virtual_topline_lookup_cache[winid] = {}
    return virtual_topline_lookup_cache[winid]
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  local last_line = vim.api.nvim_buf_line_count(bufnr)

  virtual_topline_lookup_cache[winid] = vim.api.nvim_win_call(winid, function()
    local result = {} ---@type integer[]
    local count = 1
    local line = 1
    local best = line
    local best_distance = math.huge
    local best_count = count
    for row = 1, winheight do
      local proportion = (row - 1) / (winheight - 1)
      while line <= last_line do
        local current = (count - 1) / (total_vlines - 1)
        local distance = math.abs(current - proportion)
        if distance <= best_distance then
          best = line
          best_distance = distance
          best_count = count
        elseif distance > best_distance then
          line = best
          best_distance = math.huge
          count = best_count
          break
        end
        local foldclosedend = vim.fn.foldclosedend(line)
        if foldclosedend ~= -1 then
          line = foldclosedend
        end
        line = line + 1
        count = count + 1
      end
      local value = best
      local foldclosed = vim.fn.foldclosed(value)
      if foldclosed ~= -1 then
        value = foldclosed
      end
      table.insert(result, value)
    end
    return result
  end)

  return virtual_topline_lookup_cache[winid]
end

----------------------------------------------------------------------------------------------------
-- Utility functions
----------------------------------------------------------------------------------------------------

---Run callback when command is run.
---@param cmd                         string
---@param augroup                     string|integer
---@param f                           fun()
function M.on_cmd(cmd, augroup, f)
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = augroup,
    callback = function()
      if vim.fn.getcmdtype() == ":" and vim.startswith(vim.fn.getcmdline(), cmd) then
        f()
      end
    end,
  })
end

---@generic F: function
---@param f                           F
---@return F
function M.noautocmd(f)
  return function(...)
    local eventignore = vim.o.eventignore
    vim.o.eventignore = "all"
    local r = { pcall(f, ...) }
    vim.o.eventignore = eventignore
    if not r[1] then
      error(r[2])
    end
    return unpack(r, 2, table.maxn(r))
  end
end

---Predicate function to check whether a bufnr and winid are valid.
---@param bufnr                       integer
---@param winid                       integer|nil
---@return fun(): false|nil
function M.winbuf_pred(bufnr, winid)
  local buftick = vim.b[bufnr].changedtick

  return function()
    if bufnr then
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return false
      end
      if vim.b[bufnr].changedtick ~= buftick then
        return false
      end
    end
    if winid and not vim.api.nvim_win_is_valid(winid) then
      return false
    end
  end
end

return M
