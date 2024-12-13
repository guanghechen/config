local Scheduler = require("eve.lib.collection.scheduler")
local state = require("eve.state")

---@return nil
local function refresh_state()
  eve.buf.refresh_all()
  eve.win.refresh_all()
  eve.tab.refresh_all()
  eve.tab.remove_unrefereced_bufs(vim.api.nvim_list_bufs())
end

local scheduler = Scheduler.new({
  name = "fml.fn.refresh_state",
  delay = 16,
  silent = function()
    local devmode = state.state.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  task = function()
    refresh_state()
    return true
  end,
})

---@return nil
return function()
  scheduler:schedule()
end
