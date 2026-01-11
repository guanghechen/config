---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.handler.cursor" ---@type string

local util = require("era.m.minimap.util")

local HIGHLIGHT = "m_mm_cursor"
local SYMBOLS = { "⎺", "⎻", "⎼", "⎽" } ---@type string[]
local SYMBOLS_COUNT = #SYMBOLS ---@type integer

---@class era.m.minimap.handler.cursor : era.m.minimap.IHandler
local M = {
  name = "cursor",
}

---@param symbols                     string[]
---@param f                           number
---@return string
local function get_symbol(symbols, f)
  local index = math.max(1, util.round((0.5 - f) * SYMBOLS_COUNT)) ---@type integer
  return symbols[index] or tostring(index)
end

---@param winnr                       integer
---@return era.m.minimap.IMark[]
local function get_marks(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local pos, f = util.row_to_barpos(winnr, cursor[1] - 1)

  return {
    {
      pos = pos,
      highlight = HIGHLIGHT,
      symbol = get_symbol(SYMBOLS, f),
    },
  }
end

---@param winnr                       integer
---@return nil
local function render(winnr)
  local view = require("era.m.minimap.view")
  if vim.api.nvim_win_is_valid(winnr) and view.is_attached(winnr) then
    local marks = get_marks(winnr)
    view.render_handler(winnr, M.ns, M.config, marks)
  end
end

---@param winnr                       integer
---@return nil
function M.attach(winnr)
  local gname = "era_minimap_cursor_" .. tostring(winnr) ---@type string
  local group = vim.api.nvim_create_augroup(gname, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      local winnr_current = vim.api.nvim_get_current_win() ---@type integer
      if winnr_current == winnr then
        render(winnr)
      end
    end,
  })

  render(winnr)
end

---@param winnr                       integer
function M.detach(winnr)
  local gname = "era_minimap_cursor_" .. tostring(winnr) ---@type string
  vim.api.nvim_clear_autocmds({ group = gname })
end

return M
