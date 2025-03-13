local __module_name__ = "fml.action.tab" ---@type string

local reporter = require("eve.std.reporter")
local state = require("eve.state")

---@class fml.action.tab
local M = {}

---@return nil
function M.close()
  local N = vim.fn.tabpagenr("$") ---@type integer
  if N <= 1 then
    reporter.warn({
      from = __module_name__,
      subject = "close",
      message = "This is the last tab, cannot close it.",
    })
    return
  end
  vim.cmd.tabclose()
end

---@return nil
function M.close_to_leftest()
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = 1, tabid - 1, 1 do
    vim.cmd("-tabclose")
  end
end

---@return nil
function M.close_to_rightest()
  local N = vim.fn.tabpagenr("$") ---@type integer
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = tabid + 1, N, 1 do
    vim.cmd("+tabclose")
  end
end

---@return nil
function M.close_others()
  vim.cmd("tabonly")

  vim.schedule(function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    state.tab.tab_history:clear()
    state.tab.tab_history:push(tabnr)
  end)
end

return M
