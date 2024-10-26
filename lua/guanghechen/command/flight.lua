local uuids = eve.commander.uuids

---@type string[]
local flights = {
  "autoload",
  "autosave",
  "copilot",
  "devmode",
}

eve.commander.register({
  uuid = uuids.flight,
  desc = "flight: toggle",
  candidates = flights,
  nargs = 1,
  action = function(args)
    local flight = type(args) == "string" and args:lower() or ""
    local enabled ---@type boolean

    if flight == "autoload" then
      enabled = not eve.context.state.flight.autoload:snapshot() ---@type boolean
      eve.context.state.flight.autoload:next(enabled)
    elseif flight == "autosave" then
      enabled = not eve.context.state.flight.autosave:snapshot() ---@type boolean
      eve.context.state.flight.autosave:next(enabled)
    elseif flight == "copilot" then
      enabled = not eve.context.state.flight.copilot:snapshot() ---@type boolean
      eve.context.state.flight.copilot:next(enabled)
    elseif flight == "devmode" then
      enabled = not eve.context.state.flight.devmode:snapshot() ---@type boolean
      eve.context.state.flight.devmode:next(enabled)
    else
      eve.reporter.warn({
        from = "guanghechen.command.flight",
        message = "Unknown flight.",
        details = { flight = flight },
      })
      return
    end

    eve.reporter.info({
      from = "guanghechen.command.flight",
      message = flight .. " flight has been " .. (enabled and "enabled" or "disabled") .. ".",
    })
  end,
})
