local util_terminal = require("ghc.core.util.terminal")

---@class ghc.core.action.terminal
local M = {}

function M.open_terminal_workspace()
  util_terminal.toggle_terminal(nil, {
    id = "workspace-terminal",
    cwd = fml.path.workspace(),
  })
end

function M.open_terminal_cwd()
  util_terminal.toggle_terminal(nil, {
    id = "cwd-terminal",
    cwd = fml.path.cwd(),
  })
end

function M.open_terminal_current()
  util_terminal.toggle_terminal(nil, {
    id = fml.path.current_directory(),
    cwd = fml.path.current_directory(),
  })
end

function M.open_terminal_workspace_tmux()
  if fml.os.is_windows() then
    M.open_terminal_workspace()
  else
    local cwd = fml.path.workspace()
    local cmd = { "bash", fml.path.locate_script_filepath("tmux.sh"), cwd } ---@type string[]
    ---@type LazyTermOpts
    local opts = {
      id = "popup-terminal",
      cwd = cwd,
      float = {
        ft = "term",
        width = 0.8,
        height = 0.8,
        border = "none",
      },
    }
    util_terminal.toggle_terminal(cmd, opts)
  end
end

return M

