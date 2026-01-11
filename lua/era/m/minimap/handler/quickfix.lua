---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.handler.quickfix" ---@type string

local util = require("era.m.minimap.util")

local HIGHLIGHT = "m_mm_quickfix"
local SYMBOLS = { "-", "=", "≡" } ---@type string[]
local SYMBOLS_COUNT = #SYMBOLS ---@type integer

---@class era.m.minimap.handler.quickfix : era.m.minimap.IHandler
local M = {
  name = "quickfix",
}

---@param bufnr                       integer
---@param winnr                       integer
---@return era.m.minimap.IMark[]
local function get_marks(bufnr, winnr)
  local marks = {} ---@type table<integer, { count: integer }>

  for _, item in ipairs(vim.fn.getqflist()) do
    if item.bufnr == bufnr then
      local pos = util.row_to_barpos(winnr, item.lnum - 1)

      local count = 1 ---@type integer
      if marks[pos] and marks[pos].count then
        count = marks[pos].count + 1
      end

      marks[pos] = { count = count }
    end
  end

  local ret = {} ---@type era.m.minimap.IMark[]

  for pos, mark in pairs(marks) do
    ret[#ret + 1] = {
      pos = pos,
      highlight = HIGHLIGHT,
      symbol = SYMBOLS[mark.count] or SYMBOLS[SYMBOLS_COUNT],
    }
  end

  return ret
end

---@param winnr                       integer
---@return nil
local function render(winnr)
  local view = require("era.m.minimap.view")
  if vim.api.nvim_win_is_valid(winnr) and view.is_attached(winnr) then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local marks = get_marks(bufnr, winnr)
    view.render_handler(winnr, M.ns, M.config, marks)
  end
end

---@param winnr                       integer
---@return nil
function M.attach(winnr)
  local gname = "era_minimap_quickfix_" .. tostring(winnr) ---@type string
  local group = vim.api.nvim_create_augroup(gname, { clear = true })

  vim.api.nvim_create_autocmd("QuickFixCmdPost", {
    group = group,
    callback = function()
      render(winnr)
    end,
  })

  render(winnr)
end

---@param winnr                       integer
---@return nil
function M.detach(winnr)
  local gname = "era_minimap_quickfix_" .. tostring(winnr) ---@type string
  vim.api.nvim_clear_autocmds({ group = gname })
end

return M
