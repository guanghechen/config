local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---@type string
local fn_show_detach = dot.G.register_anonymous_fn(function()
  era.m.ai.action.show_detach_picker()
end)

---@class era.m.nvimbar.component.ai
local M = {}

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.status(position)
  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "ai:status",
    atomic = true,
    condition = function()
      return era.m.ai.state.get_attached_count() > 0
    end,
    render = function()
      local attached = era.m.ai.state.get_attached()
      local count = #attached

      if count == 0 then
        return "", "", false
      end

      local pane_ids = {} ---@type integer[]
      local agent_names = {} ---@type string[]
      for _, source in ipairs(attached) do
        if source.type == "tmux" and source.tmux_pane then
          local num = tonumber(source.tmux_pane.pane_id:match("%%(%d+)"))
          if num then
            pane_ids[#pane_ids + 1] = num
          end
        else
          agent_names[#agent_names + 1] = era.m.ai.config.agent_labels[source.agent] or source.agent
        end
      end
      table.sort(pane_ids)
      table.sort(agent_names)

      local parts = {} ---@type string[]
      if #pane_ids > 0 then
        local ids_str = table.concat(pane_ids, "|")
        parts[#parts + 1] = #pane_ids > 1 and string.format("%%(%s)", ids_str) or string.format("%%%d", pane_ids[1])
      end
      for _, name in ipairs(agent_names) do
        parts[#parts + 1] = name
      end

      local icon = stl.icon.status.attached ---@type string
      local agents_text = table.concat(parts, ",")
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
