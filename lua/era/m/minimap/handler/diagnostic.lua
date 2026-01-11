---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.handler.diagnostic" ---@type string

local util = require("era.m.minimap.util")

local HIGHLIGHTS = {
  [vim.diagnostic.severity.ERROR] = "m_mm_diagnostic_error",
  [vim.diagnostic.severity.WARN] = "m_mm_diagnostic_warn",
  [vim.diagnostic.severity.INFO] = "m_mm_diagnostic_info",
  [vim.diagnostic.severity.HINT] = "m_mm_diagnostic_hint",
} ---@type table<integer, string>

local SYMBOLS = { "-", "=", "≡" } ---@type string[]
local SYMBOLS_COUNT = #SYMBOLS ---@type integer

local MIN_SEVERITY = vim.diagnostic.severity.HINT ---@type integer

---@class era.m.minimap.handler.diagnostic : era.m.minimap.IHandler
local M = {
  name = "diagnostic",
}

---@type table<integer, stl.c.ISubscriber>
local subscribers = {}

---@param severity                    integer
---@param count                       integer
---@return string
local function get_symbol(severity, count)
  _ = severity
  return SYMBOLS[count] or SYMBOLS[SYMBOLS_COUNT]
end

---@async
---@param bufnr                       integer
---@param winnr                       integer
---@return era.m.minimap.IMark[]
local function get_marks(bufnr, winnr)
  local diags = vim.diagnostic.get(bufnr)
  local pred = util.winbuf_pred(bufnr, winnr)

  local marks = {} ---@type table<integer, { count: integer, severity: integer }>

  for _, diag in stl.async.auto_ipairs(diags) do
    if pred() == false then
      return {}
    end
    if diag.severity <= MIN_SEVERITY then
      local pos = util.row_to_barpos(winnr, diag.lnum)

      local count = 1 ---@type integer
      if marks[pos] and marks[pos].count then
        count = marks[pos].count + 1
      end

      local severity = diag.severity or vim.diagnostic.severity.HINT ---@type integer
      if marks[pos] and marks[pos].severity and marks[pos].severity < severity then
        severity = marks[pos].severity
      end

      marks[pos] = {
        count = count,
        severity = severity,
      }
    end
  end

  local ret = {} ---@type era.m.minimap.IMark[]

  for pos, mark in pairs(marks) do
    ret[#ret + 1] = {
      pos = pos,
      highlight = HIGHLIGHTS[mark.severity],
      symbol = get_symbol(mark.severity, mark.count),
    }
  end

  return ret
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
  era.m.lsp.diagnostic.subscribe_all(subscriber)

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

return M
