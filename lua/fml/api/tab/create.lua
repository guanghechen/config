local state = require("fml.api.state")
local History = require("fml.collection.history")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

---@param name                          string
---@param bufnr                         integer
---@return nil
function M.create(name, bufnr)
  vim.cmd("$tabnew")

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)

  ---@type fml.api.state.ITabWinItem
  local win = {
    buf_history = History.new({
      name = name .. "#wins",
      max_count = 1000,
      comparator = state.compare_bufnr,
      validate = state.validate_buf,
    }),
  }
  win.buf_history:push(bufnr)

  ---@type fml.api.state.ITabItem
  local tab = {
    name = name,
    bufnrs = { bufnr },
    wins = { winnr = win },
  }
  state.tabs[tabnr] = tab
  state.tab_history:push(tabnr)
  state.schedule_refresh_tabs()
end

function M.create_with_buf()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)

  M.create("unnamed", bufnr)

  vim.api.nvim_win_set_cursor(winnr, cursor)
end
