---@type string
local fn_show_message = eve.G.register_anonymous_fn(function()
  if package.loaded["copilot"] then
    local status = require("copilot.api").status.data
    eve.debug.log({ status = status or "nil" })
  end
end)

local status_icon_map = {
  Inactive = eve.icons.cmp.copilot_error,
  InProgress = eve.icons.cmp.copilot,
  Normal = eve.icons.cmp.copilot,
  Warning = eve.icons.cmp.copilot_warn,
}

local last_status = nil ---@type string|nil

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "copilot",
  condition = function()
    return not not package.loaded["copilot"]
  end,
  will_change = function()
    local status = require("copilot.api").status.data.status ---@type string|nil
    local changed = status ~= last_status
    last_status = status
    return changed
  end,
  render = function()
    local status = last_status or "Normal" ---@type string
    local icon = status_icon_map[status] or eve.icons.cmp.copilot ---@type string
    local text = icon .. " " ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    local hl_text = eve.nvimbar.txt(text, (status == nil or #status < 1) and "f_sl_text" or ("f_sl_copilot_" .. status))
    hl_text = eve.nvimbar.btn(hl_text, fn_show_message)
    return hl_text, width
  end,
}

return M
