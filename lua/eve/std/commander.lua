local reporter = require("eve.std.reporter")

---@class t.eve.ICommand
---@field public uuid                   string
---@field public action                 function(args?: string): nil
---@field public candidates             ?string[]

---@type table<string, t.eve.ICommand>
local command_map = {}

---@class eve.std.commander.uuids
local uuids = {
  buf_close = "f-buf-close",
  buf_close_to_leftest = "f-buf-close-to-leftest",
  buf_close_to_rightest = "f-buf-close-to-rightest",
}

---@class eve.std.commander
---@field public uuids                  eve.std.commander.uuids
local M = {
  uuids = uuids,
}

---@param uuid                          string
---@param args                          ?string
---@param silent                        ?boolean
---@return t.eve.ICommand|nil
function M.execute(uuid, args, silent)
  local command = M.resolve(uuid, true) ---@type t.eve.ICommand|nil
  if command == nil then
    if not silent then
      reporter.error({
        from = "eve.std.commander",
        subject = "execute",
        message = "Cannot resolve the command by the given uuid",
        details = { uuid = uuid },
      })
      return
    end
  end
  command.action(args)
end

---@param uuid                          string
---@param action                        function(args?: string): nil
---@param candidates                    ?string[]
---@param overwrite                     ?boolean
---@return nil
function M.register(uuid, action, candidates, overwrite)
  local has_existed = command_map[uuid] ~= nil ---@type boolean

  if has_existed and not overwrite then
    reporter.warn({
      from = "eve.std.commander",
      subject = "register",
      message = "The command has been registered, please set the `overwrite` param to true if you want to replace it",
      details = { uuid = uuid, overwrite = overwrite },
    })
    return
  end

  ---@type t.eve.ICommand
  local command = {
    uuid = uuid,
    action = action,
    candidates = candidates,
  }
  command_map[uuid] = command

  if not has_existed then
    vim.api.nvim_create_user_command(uuid, function(opts)
      M.execute(uuid, opts.args, false)
    end, {
      nargs = "?",
      complete = function(argLead)
        local cmd = M.resolve(uuid, true)
        if cmd ~= nil and cmd.candidates ~= nil then
          local pattern = "^" .. argLead ---@type string
          local options = cmd.candidates ---@type string[]

          local matches = {}
          for _, option in ipairs(options) do
            if option:match(pattern) then
              table.insert(matches, option)
            end
          end
          return matches
        end
      end,
    })
  end
end

---@param uuid                          string
---@param silent                        ?boolean
---@return t.eve.ICommand|nil
function M.resolve(uuid, silent)
  local command = command_map[uuid] ---@type t.eve.ICommand|nil
  if command == nil and not silent then
    reporter.warn({
      from = "eve.std.commander",
      subject = "resolve",
      message = "Cannot resolve the command by the given uuid",
      details = { uuid = uuid },
    })
  end
  return command
end

return M
