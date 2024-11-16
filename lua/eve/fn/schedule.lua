local Scheduler = require("eve.collection.scheduler")

---@param name                          string
---@param fn                            fun(): nil
---@param delay                         ?integer|nil
---@return fun(): nil
local function schedule(name, fn, delay)
  local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
  local scheduler = Scheduler.new({
    name = name,
    delay = delay,
    silent = not devmode,
    task = function()
      fn()
      return true
    end,
  })

  ---@return nil
  local function wrapped()
    scheduler:schedule()
  end

  return wrapped
end

return schedule
