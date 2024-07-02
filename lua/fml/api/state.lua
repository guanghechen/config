local History = require("fml.collection.history")

---@class fml.api.state.ITabItem
---@field public tabnr                  integer
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public buf_history            fml.types.collection.IHistory
---@field public wins                   table<integer, fml.api.state.ITabWinItem>
---@field public winnr_cur              integer

---@class fml.api.state.ITabWinItem
---@field public buf_history            fml.types.collection.IHistory

---@class fml.api.state.IBufItem
---@field public bufnr                  integer
---@field public alive                  boolean
---@field public pinned                 boolean
---@field public filepath               string
---@field public filename               string

---@class fml.api.state.IState
---@field public bufs                   table<integer, fml.api.state.IBufItem>
---@field public tabs                   table<integer, fml.api.state.ITabItem>
---@field public tab_history            fml.types.collection.IHistory
local M = {
  bufs = {},
  tabs = {},
  tab_history = History.new({
    name = "tabs",
    max_count = 100,
    comparator = function(x, y)
      return x - y
    end,
  }),
}

return M
