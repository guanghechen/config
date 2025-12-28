local State = require("dot.module.plugin.state")

---@class dot.module.plugin
local M = {}

---@param specs                         dot.module.plugin.IPluginSpec[]
---@return nil
function M.setup(specs)
  State.setup(specs)

  if #specs > 0 then
    require("dot.module.plugin.loader").setup(specs)
  end

  vim.api.nvim_create_user_command("Plugin", function(cmd)
    local mode = "home" ---@type dot.module.plugin.ViewModeEnum
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

---@param mode                          dot.module.plugin.ViewModeEnum|nil
---@return nil
function M.show(mode)
  require("dot.module.plugin.view").show(mode)
end

---@return nil
function M.close()
  require("dot.module.plugin.view").close_view()
end

---@return boolean
function M.visible()
  return require("dot.module.plugin.view").visible()
end

---@return table<string, dot.module.plugin.ILockEntry>
function M.get_lock()
  State.load_lock()
  return State.lock
end

---@param plugins                       table<string, dot.module.plugin.ILockEntry>
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
  return require("dot.module.plugin.loader").is_loaded(name)
end

---@param name                          string
---@return nil
function M.load(name)
  require("dot.module.plugin.loader").load(name)
end

---@return table<string, dot.module.plugin.IPluginState>
function M.get_plugins()
  return require("dot.module.plugin.loader").get_all()
end

return M
