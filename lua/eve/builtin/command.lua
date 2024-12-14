local __module_name__ = "eve.builtin.command" ---@type string

local reporter = require("eve.lib.reporter")

---@class eve.builtin.command.IDefinition
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  ?0|1|"?"
---@field public candidates             ?string[]

---@class eve.builtin.command.ICommand
---@field public uuid                   string
---@field public desc                   string
---@field public implemented            boolean
---@field public nargs                  0|1|"?"
---@field public candidates             ?string[]
---@field public action                 fun(args?: string): nil

local command_map = {} ---@type table<string, eve.builtin.command.ICommand>

---@class eve.builtin.command
local M = {}

---@param definition                eve.builtin.command.IDefinition
---@return eve.builtin.command
function M.define(definition)
  if command_map[definition.uuid] ~= nil then
    reporter.warn({
      from = __module_name__,
      subject = "define",
      message = "The definition with the uuid is already exists.",
      details = { definition = definition },
    })
    return M
  end

  ---@type eve.builtin.command.ICommand
  local command = {
    uuid = definition.uuid,
    desc = definition.desc,
    implemented = false,
    nargs = definition.nargs or 0,
    candidates = definition.candidates,
    action = function()
      reporter.error({
        from = __module_name__,
        subject = "action",
        message = "The action is not implemented.",
        details = { definition = definition },
      })
    end,
  }

  command_map[command.uuid] = command
  return M
end

---@param uuid                          string
---@param action                        fun(args?: string): nil
---@return eve.builtin.command
function M.implement(uuid, action)
  local command = command_map[uuid] ---@type eve.builtin.command.ICommand|nil
  if command == nil then
    reporter.error({
      from = __module_name__,
      subject = "register",
      message = "The definition with the uuid is already exists.",
      details = { uuid = uuid, action = action },
    })
    return M
  end

  if command.implemented then
    reporter.warn({
      from = __module_name__,
      subject = "implement",
      message = "The command has been implemented. skipped",
      details = { uuid = uuid, action = action, command = command },
    })
    return M
  end

  command.action = action
  command.implemented = true
  return M
end

function M.execute(uuid, args, silent)
  return M
end

return M
