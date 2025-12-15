local btn = ark.nvim.btn
local txt = ark.nvim.txt

local state = require("dot.ux.widget.ai.state")
local config = require("dot.ux.widget.ai.config")

---@type string
local fn_show_detach = dot.G.register_anonymous_fn(function()
  dot.ux.widget.ai.action.show_detach_picker()
end)

---@class dot.module.nvimbar.component.ai
local M = {}

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.status(position)
  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "ai:status",
    atomic = true,
    condition = function()
      return state.get_attached_count() > 0
    end,
    render = function()
      local attached = state.get_attached()
      local count = #attached

      if count == 0 then
        return "", "", false
      end

      local agent_counts = {} ---@type table<string, integer>
      for _, source in ipairs(attached) do
        local label = config.agent_labels[source.agent] or source.agent
        agent_counts[label] = (agent_counts[label] or 0) + 1
      end

      local names = {} ---@type string[]
      for label, cnt in pairs(agent_counts) do
        if cnt > 1 then
          names[#names + 1] = string.format("%s(%d)", label, cnt)
        else
          names[#names + 1] = label
        end
      end
      table.sort(names)

      local icon = dot.icon.status.attached ---@type string
      local agents_text = table.concat(names, ",")
      local text = string.format("%s %s", icon, agents_text)

      local hln_icon = position .. "_ai_status_icon" ---@type string
      local hln_text = position .. "_ai_status_text" ---@type string
      local hl_text = btn(txt(icon, hln_icon) .. " " .. txt(agents_text, hln_text), fn_show_detach)

      return text, hl_text, true
    end,
  }
  return component
end

return M
