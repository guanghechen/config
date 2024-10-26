local reporter = require("eve.std.reporter")

---@class t.eve.ICommand
---@field public uuid                   string
---@field public desc                   string
---@field public action                 fun(args?: string): nil
---@field public candidates             ?string[]

---@class t.eve.IRawCommand
---@field public uuid                   string
---@field public desc                   string
---@field public action                 fun(args?: string): nil
---@field public candidates             ?string[]
---@field public nargs                  ?0|1|"?"

---@type table<string, t.eve.ICommand>
local command_map = {}

---@class eve.std.commander
local M = {}

---@class eve.std.commander.uuids
M.uuids = {
  buf_close = "Fbufclose",
  buf_close_to_leftest = "Fbufclosetoleftest",
  buf_close_to_rightest = "Fbufclosetorightest",
  find_buffers = "Ffindbuffers",
  find_explorer = "Ffindexplorer",
  find_highlights = "Ffindhighlights",
  find_vim_options = "Ffindvimoptions",
  flight = "Fflight",
  select_theme = "Fselecttheme",
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
    end
    return
  end
  command.action(args)
end

---@param raw_command                   t.eve.IRawCommand
---@param overwrite                     ?boolean
---@return eve.std.commander
function M.register(raw_command, overwrite)
  local uuid = raw_command.uuid ---@type string
  local desc = raw_command.desc ---@type string
  local action = raw_command.action ---@type fun(args?: string): nil
  local candidates = raw_command.candidates ---@type string[]|nil
  local nargs = raw_command.nargs or 0 ---@type 0|1|"?"
  local has_existed = command_map[uuid] ~= nil ---@type boolean

  if has_existed and not overwrite then
    reporter.warn({
      from = "eve.std.commander",
      subject = "register",
      message = "The command has been registered, please set the `overwrite` param to true if you want to replace it",
      details = { uuid = uuid, overwrite = overwrite },
    })
    return M
  end

  if not has_existed then
    vim.api.nvim_create_user_command(uuid, function(opts)
      M.execute(uuid, opts.args, false)
    end, {
      desc = desc,
      nargs = nargs,
      complete = nargs ~= 0
          and function(argLead)
            local command = M.resolve(uuid, true)
            if command ~= nil and command.candidates ~= nil then
              local pattern = "^" .. argLead ---@type string
              local options = command.candidates ---@type string[]

              local matches = {}
              for _, option in ipairs(options) do
                if option:match(pattern) then
                  table.insert(matches, option)
                end
              end
              return matches
            end
          end
        or nil,
    })
  end

  ---@type t.eve.ICommand
  local command = {
    uuid = uuid,
    desc = desc,
    action = action,
    candidates = candidates,
  }
  command_map[uuid] = command
  return M
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
