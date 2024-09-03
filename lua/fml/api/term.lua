local Terminal = require("fml.ui.terminal")

local terminal_map = {} ---@type table<string, fml.types.ui.ITerminal>

---@class fml.api.term
local M = {}

---@class fml.api.term.ICreateParams
---@field public name                   string
---@field public command                ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public destroy_on_close       boolean

---@param params                        fml.api.term.ICreateParams
---@return integer|nil
function M.create(params)
  local name = params.name ---@type string
  local command = params.command or vim.env.SHELL or vim.o.shell ---@type string
  local cwd = params.cwd or eve.path.cwd() ---@type string
  local env = params.env ---@type table<string, string>|nil
  local destroy_on_close = params.destroy_on_close ---@type boolean

  local terminal = terminal_map[name] ---@type fml.types.ui.ITerminal|nil
  if terminal ~= nil then
    eve.reporter.error({
      from = "fml.api.term",
      subject = "create",
      message = "The term with the given name already exists.",
      details = { name = name, command = command, cwd = cwd, env = env },
    })
    return
  end

  ---@type fml.types.ui.ITerminal
  terminal = Terminal.new({
    command = command,
    command_cwd = cwd,
    command_env = env,
    destroy_on_close = destroy_on_close,
  })
  terminal_map[name] = terminal

  terminal:open()
end

---@param name                          string
---@return integer|nil
function M.toggle(name)
  local terminal = terminal_map[name] ---@type fml.types.ui.ITerminal
  if terminal == nil then
    eve.reporter.error({
      from = "fml.api.term",
      subject = "toggle",
      message = "Cannot find the term with the given name.",
      details = { name = name },
    })
    return
  end
  terminal:toggle()
end

---@param params                        fml.api.term.ICreateParams
---@return integer|nil
function M.toggle_or_create(params)
  if terminal_map[params.name] == nil then
    return M.create(params)
  else
    return M.toggle(params.name)
  end
end

return M
