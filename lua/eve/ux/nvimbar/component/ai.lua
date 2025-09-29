local __module_name__ = "eve.ux.nvimbar.component.ai" ---@type string

local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@return string
local function get_status()
  local clients = vim.lsp.get_clients({ name = "copilot" })
  if #clients > 0 then
    local client = clients[1]
    if client:is_stopped() then
      return "Stopped"
    end

    -- Check tracked status from centralized status system
    local client_status = eve.status.copilots[client.id]
    if client_status == "error" then
      return "Error"
    elseif client_status == "pending" then
      return "Busy"
    elseif client_status == "ok" then
      return ""
    end

    -- Return empty for normal operation (connected)
    return ""
  else
    return "Disconnected"
  end
end

---@type string
local fn_show_message = eve.G.register_anonymous_fn(function()
  local enabled = eve.context.flight.ai:snapshot() ---@type boolean
  local status = "NIL" ---@type unknown

  -- Check native Copilot LSP status
  local clients = vim.lsp.get_clients({ name = "copilot" })
  if #clients > 0 then
    local client = clients[1]
    status = client:is_stopped() and "Stopped" or "Connected"
  else
    status = "Disconnected"
  end

  std.reporter.info({
    from = __module_name__,
    details = { enabled = enabled, status = status },
  })
end)

---@class eve.ux.nvimbar.component.ai
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.copilot(position)
  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "ai:copilot",
    atomic = true,
    condition = function()
      return eve.context.flight.ai:snapshot()
    end,
    render = function()
      local enabled = eve.context.flight.ai:snapshot() ---@type boolean
      if not enabled then
        local text = eve.icon.app.Copilot .. " Copilot" ---@type string
        local hl_text = btn(text, fn_show_message)
        return text, hl_text, true
      end

      local status = get_status()
      local icon = eve.icon.app.Copilot ---@type string

      -- Use different icons based on status
      if status == "Error" or status == "Stopped" or status == "Disconnected" then
        icon = eve.icon.app.CopilotError
      elseif status == "Busy" then
        icon = eve.icon.app.CopilotWarn
      end

      local text = icon .. " Copilot" ---@type string
      local hln_text = position .. "_ai_copilot_text" ---@type string
      if #status > 0 then
        text = text .. "(" .. status .. ") " ---@type string
        hln_text = position .. "_ai_copilot_status_" .. status ---@type string
      end

      local hl_text = btn(txt(text, hln_text), fn_show_message)
      return text, hl_text, true
    end,
  }
  return component
end

return M
