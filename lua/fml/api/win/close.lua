local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.close_current()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  vim.cmd("close")

  if #winnrs == 1 then
    state.refresh()
  else
    state.schedule_refresh_tab(tabnr)
  end
end

---@return nil
function M.close_others()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer

  vim.cmd("only")

  state.schedule_refresh_tab(tabnr)
end
