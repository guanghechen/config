local buffer = require("fml.api.buffer")
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

  ---@type table<integer, fml.api.state.ITabWinItem>
  local wins = {
    winnr = {
      buf_history = History.new({
        name = name .. "#wins",
        max_count = 100,
        comparator = function(x, y)
          return x - y
        end,
      }),
    },
  }
  wins[winnr].buf_history:push(bufnr)

  ---@type fml.api.state.ITabItem
  local tab = {
    tabnr = tabnr,
    name = name,
    bufnrs = { bufnr },
    buf_history = History.new({
      name = name .. "#bufs",
      max_count = 100,
      comparator = function(x, y)
        return x - y
      end,
    }),
    wins = wins,
    winnr_cur = winnr,
  }

  state.tabs[tabnr] = tab
  state.tab_history:push(tabnr)
end

function M.create_with_buf()
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)

  M.create("unnamed", bufnr)

  vim.api.nvim_win_set_cursor(winnr, cursor)
  buffer.close_others()
end
