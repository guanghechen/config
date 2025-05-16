local __module_name__ = "ghc.action.profile" ---@type string

local log_filepath = std.path.locate_config_filepath("profile.log") ---@type string
local svg_filepath = std.path.locate_config_filepath("profile.svg") ---@type string

---@class ghc.action.profile
local M = {}

---@return nil
function M.start()
  std.reporter.info({
    from = __module_name__,
    subject = "start",
    details = {
      log = log_filepath,
      svg = svg_filepath,
    },
    silent = true,
  })

  require("plenary.profile").start(log_filepath, { flame = true })
end

---@return nil
function M.stop()
  require("plenary.profile").stop()

  ---@type string
  local command =
    string.format("inferno-flamegraph %s > %s", vim.fn.fnameescape(log_filepath), vim.fn.fnameescape(svg_filepath))
  vim.schedule(function()
    pcall(vim.fn.system, command)
  end)

  std.reporter.info({
    from = __module_name__,
    subject = "stop",
    details = {
      command = command,
      log = log_filepath,
      svg = svg_filepath,
    },
  })
end

return M
