---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.handler.git" ---@type string

local util = require("era.m.minimap.util")

local HIGHLIGHTS = {
  add = "m_mm_git_add",
  change = "m_mm_git_change",
  delete = "m_mm_git_delete",
} ---@type table<string, string>

local SYMBOLS = {
  add = "│",
  change = "│",
  delete = "-",
} ---@type table<string, string>

---@class era.m.minimap.handler.git : era.m.minimap.IHandler
local M = {
  name = "git",
}

---@type table<integer, stl.c.ISubscriber>
local subscribers = {}

---@async
---@param bufnr                       integer
---@param winnr                       integer
---@return era.m.minimap.IMark[]
local function get_marks(bufnr, winnr)
  local hunks = era.m.git.buffer.get_unstaged_hunks(bufnr)
  if not hunks or #hunks == 0 then
    return {}
  end

  local pred = util.winbuf_pred(bufnr, winnr)
  local marks = {} ---@type era.m.minimap.IMark[]

  for _, hunk in stl.async.ipairs(hunks) do
    if pred() == false then
      return {}
    end

    local hl = HIGHLIGHTS[hunk.type] or HIGHLIGHTS.change ---@type string
    local symbol = SYMBOLS[hunk.type] or SYMBOLS.change ---@type string

    local min_lnum = math.max(1, hunk.added.start) ---@type integer
    local min_pos = util.row_to_barpos(winnr, min_lnum - 1)

    local max_lnum = math.max(1, hunk.added.start + math.max(0, hunk.added.count - 1)) ---@type integer
    local max_pos = util.row_to_barpos(winnr, max_lnum - 1)

    for pos = min_pos, max_pos do
      marks[#marks + 1] = {
        pos = pos,
        symbol = symbol,
        highlight = hl,
      }
    end
  end

  return marks
end

---@param winnr                       integer
---@return nil
local function render(winnr)
  stl.async.run(function()
    local view = require("era.m.minimap.view")
    if not vim.api.nvim_win_is_valid(winnr) or not view.is_attached(winnr) then
      return
    end
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local marks = get_marks(bufnr, winnr)
    if vim.api.nvim_win_is_valid(winnr) then
      view.render_handler(winnr, M.ns, M.config, marks)
    end
  end)
end

---@param winnr                       integer
---@return nil
function M.attach(winnr)
  local subscriber = stl.c.Subscriber.new({
    on_next = function()
      vim.schedule(function()
        render(winnr)
      end)
    end,
  })
  subscribers[winnr] = subscriber
  era.m.git.buffer.ticker:subscribe(subscriber)

  render(winnr)
end

---@param winnr                       integer
---@return nil
function M.detach(winnr)
  local subscriber = subscribers[winnr]
  if subscriber then
    subscriber:dispose()
    subscribers[winnr] = nil
  end
end

---Find the hunk line number at a given bar position.
---Returns the top line of the hunk if clicking on the top half,
---or the bottom line if clicking on the bottom half.
---@param bufnr                       integer
---@param winnr                       integer
---@param bar_pos                     integer 0-based bar position
---@return integer|nil lnum 1-based line number, or nil if no hunk at position
function M.find_hunk_line_at_pos(bufnr, winnr, bar_pos)
  local hunks = era.m.git.buffer.get_unstaged_hunks(bufnr)
  if not hunks or #hunks == 0 then
    return nil
  end

  for _, hunk in ipairs(hunks) do
    local min_lnum = math.max(1, hunk.added.start) ---@type integer
    local min_pos = util.row_to_barpos(winnr, min_lnum - 1)

    local max_lnum = math.max(1, hunk.added.start + math.max(0, hunk.added.count - 1)) ---@type integer
    local max_pos = util.row_to_barpos(winnr, max_lnum - 1)

    if bar_pos >= min_pos and bar_pos <= max_pos then
      local mid_pos = (min_pos + max_pos) / 2
      if bar_pos <= mid_pos then
        return min_lnum
      else
        return max_lnum
      end
    end
  end

  return nil
end

return M
