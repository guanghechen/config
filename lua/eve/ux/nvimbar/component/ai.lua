local __module_name__ = "eve.ux.nvimbar.component.ai" ---@type string

local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@param provider                    eve.e.AiProvider
---@return string
local function get_status(provider)
  if provider == "copilot" then
    if package.loaded["copilot"] then
      local status = require("copilot.status").data.status or ""
      return status == "Normal" and "" or status
    end
  end
  return ""
end

---@type string
local fn_show_message = eve.G.register_anonymous_fn(function()
  local enabled = eve.state.flight.ai:snapshot() ---@type boolean
  local provider = eve.state.flight.ai_provider:snapshot() ---@type string
  local status = "NIL" ---@type unknown

  if provider == "copilot" then
    if package.loaded["copilot"] then
      status = require("copilot.status").data.status or "NIL"
    end
  end

  eve.reporter.info({
    from = __module_name__,
    details = { enabled = enabled, provider = provider, status = status },
  })

  vim.cmd(eve.command.definitions.toggle.ai_provider.uuid)
end)

---@class eve.ux.nvimbar.component.ai
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.provider(position)
  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "ai:provider",
    atomic = true,
    condition = function()
      return eve.state.flight.ai:snapshot()
    end,
    render = function()
      local enabled = eve.state.flight.ai:snapshot() ---@type boolean
      local provider = eve.state.flight.ai_provider:snapshot() ---@type eve.e.AiProvider

      if not enabled then
        local text = "󱙻 " .. provider .. " " ---@type string
        local hl_text = btn(text, fn_show_message)
        return text, hl_text, true
      end

      local status = get_status(provider)
      local text = "󱚟 " .. provider .. " " ---@type string
      local hln_text = position .. "_ai_provider_text" ---@type string
      if #status > 0 then
        text = text .. "(" .. status .. ") " ---@type string
        hln_text = position .. "_ai_provider_status_" .. status ---@type string
      end

      local hl_text = btn(txt(text, hln_text), fn_show_message)
      return text, hl_text, true
    end,
  }
  return component
end

return M
