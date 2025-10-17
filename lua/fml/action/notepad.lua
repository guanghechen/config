local __module_name__ = "fml.action.notepad" ---@type string

local Notepad = eve.ux.widget.Notepad ---@type table

local DEFAULT_KEY = "default" ---@type string
local instances = {} ---@type table<string, eve.ux.widget.Notepad>

---@param key                            ?string
---@param props                          ?eve.ux.widget.notepad.IProps
---@return eve.ux.widget.Notepad
local function ensure_instance(key, props)
  key = key or DEFAULT_KEY

  local widget = instances[key] ---@type eve.ux.widget.Notepad|nil
  if widget ~= nil then
    return widget
  end

  local merged_props = vim.tbl_extend("force", {
    name = string.format("notepad.%s", key),
  }, props or {})

  widget = Notepad.new(merged_props)
  instances[key] = widget
  return widget
end

---@class fml.action.notepad
local M = {}

---@param key                            ?string
---@param props                          ?eve.ux.widget.notepad.IProps
---@return eve.ux.widget.Notepad
function M.ensure(key, props)
  return ensure_instance(key, props)
end

---@param key                            ?string
---@param props                          ?eve.ux.widget.notepad.IProps
---@return nil
function M.toggle(key, props)
  ensure_instance(key, props):toggle()
end

return M
