local Scheduler = require("eve.lib.collection.scheduler")
local state = require("eve.state")

---@return nil
local function refresh_state()
  state.buf.refresh_all()
  state.win.refresh_all()
  state.tab.refresh_all()

  local unrefereced_bufnrs = state.tab.get_unrefereced_bufnrs() ---@type integer[]
  for _, bufnr in ipairs(unrefereced_bufnrs) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

local scheduler = Scheduler.new({
  name = "eve.fn.refresh_state",
  delay = 16,
  silent = function()
    local devmode = state.flight.devmode:snapshot() ---@type boolean
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
