local __module_name__ = "eve.ux.nvimbar.component.ai" ---@type string

local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@type string
local fn_select_sidekick = eve.G.register_anonymous_fn(function()
  local ok, cli = pcall(require, "sidekick.cli")
  if ok and type(cli.select) == "function" then
    cli.select({ filter = { installed = true }, attach = true })
  else
    std.reporter.warn({
      from = __module_name__,
      message = "Sidekick CLI is not available.",
    })
  end
end)

---@class eve.ux.nvimbar.component.ai.icons
local icons = {
  attached = eve.icon.status.attached,
  detached = eve.icon.status.detached,
}

---@param attached table|nil
---@return string
local function format_attached_names(attached)
  if type(attached) ~= "table" then
    return "none"
  end

  local names = {} ---@type string[]
  for _, item in ipairs(attached) do
    local tool = item.tool
    local name = tool and tool.name or nil ---@type string|nil
    if type(name) == "string" and #name > 0 then
      names[#names + 1] = name
    end
  end

  if #names == 0 then
    return "unknown"
  end

  table.sort(names)
  return table.concat(names, "|")
end

---@return boolean, string, string
local function sidekick_status()
  local ok, state = pcall(require, "sidekick.cli.state")
  if not ok then
    return false, icons.detached, "none"
  end

  local attached = state.get({ attached = true })
  if type(attached) ~= "table" or #attached == 0 then
    return false, icons.detached, "none"
  end

  return true, icons.attached, format_attached_names(attached)
end

local augroup = eve.nvim.augroup("nvimbar_sidekick_status")
vim.api.nvim_create_autocmd("User", {
  group = augroup,
  pattern = { "SidekickCliAttach", "SidekickCliDetach" },
  callback = function()
    eve.status.dirtier_statusline:mark_dirty()
  end,
})

---@class eve.ux.nvimbar.component.ai
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.sidekick(position)
  local hln_icon_attached = position .. "_ai_sidekick_icon_attached" ---@type string
  local hln_icon_detached = position .. "_ai_sidekick_icon_detached" ---@type string
  local hln_text = position .. "_ai_sidekick_text" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "ai:sidekick",
    atomic = true,
    tight = true,
    condition = function()
      return eve.context.flight.ai:snapshot()
    end,
    render = function()
      local attached, icon, label = sidekick_status()
      local suffix = " " .. label .. "  " ---@type string
      local text = icon .. suffix ---@type string
      local hl_icon = attached and hln_icon_attached or hln_icon_detached ---@type string
      local hl_text = btn(txt(icon, hl_icon) .. txt(suffix, hln_text), fn_select_sidekick) ---@type string
      return text, hl_text, true
    end,
  }

  return component
end

return M
