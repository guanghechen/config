---@param uuid                          string
---@param desc                          string
---@param nargs                         ?0|1|"?"
---@param candidates                    ?string[]
---@return eve.builtin.command.ICommand
local function mc(uuid, desc, nargs, candidates)
  ---@type eve.builtin.command.ICommand
  local definition = {
    uuid = uuid,
    desc = desc,
    nargs = nargs or 0,
    candidates = candidates,
  }
  return definition
end

---@class eve.builtin.commands
local M = {}

---@class M.eve.builtin.commands.flight
M.flight = {
  autoload = mc("Fflightautoload", "flight: autoload"),
  autosave = mc("Fflightautosave", "flight: autosave"),
  copilot = mc("Fflightcopilot", "flight: copilot"),
  devmode = mc("Fflightdevmode", "flight: devmode"),
  lsp_inlay_hints = mc("Fflightlsp_inlay_hints", "flight: lsp_inlay_hints"),
  lsp_code_lens = mc("Fflightlsp_code_lens", "flight: lsp_code_lens"),
}

return M
