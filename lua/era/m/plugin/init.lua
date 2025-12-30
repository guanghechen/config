local State = require("era.m.plugin.state")

---@class era.m.plugin
local M = {}

---@param specs                         era.m.plugin.IPluginSpec[]
---@return nil
function M.setup(specs)
  State.setup(specs)

  if #specs > 0 then
    require("era.m.plugin.loader").setup(specs)
  end

  vim.api.nvim_create_user_command("Plugin", function(cmd)
    local mode = "home" ---@type era.m.plugin.ViewModeEnum
    if cmd.args == "profile" then
      mode = "profile"
    elseif cmd.args == "update" then
      mode = "update"
    elseif cmd.args == "clean" then
      mode = "clean"
    end
    M.show(mode)
  end, {
    nargs = "?",
    complete = function()
      return { "home", "profile", "update", "clean" }
    end,
    desc = "Open plugin info window",
  })
end

---@param mode                          era.m.plugin.ViewModeEnum|nil
---@return nil
function M.show(mode)
  require("era.m.plugin.view").show(mode)
end

---@return nil
function M.close()
  require("era.m.plugin.view").close_view()
end

---@return boolean
function M.visible()
  return require("era.m.plugin.view").visible()
end

---@return table<string, era.m.plugin.ILockEntry>
function M.get_lock()
  State.load_lock()
  return State.lock
end

---@param plugins                       table<string, era.m.plugin.ILockEntry>
---@return nil
function M.update_lock(plugins)
  State.update_lock(plugins)
end

---@return nil
function M.reload_lock()
  State.reload_lock()
end

---@param name                          string
---@return boolean
function M.is_loaded(name)
  return require("era.m.plugin.loader").is_loaded(name)
end

---@param name                          string
---@return nil
function M.load(name)
  require("era.m.plugin.loader").load(name)
end

---@return table<string, era.m.plugin.IPluginState>
function M.get_plugins()
  return require("era.m.plugin.loader").get_all()
end

return M
