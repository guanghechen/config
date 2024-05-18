local path = require("ghc.core.util.path")

---@class ghc.core.action.explorer
local M = {}

function M.toggle_explorer_file_workspace()
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = path.workspace(),
    position = "left",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_file_cwd()
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = path.cwd(),
    position = "left",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_buffer_workspace()
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = path.workspace(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_buffer_cwd()
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = path.cwd(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_git_workspace()
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = path.workspace(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_git_cwd()
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = path.cwd(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_last()
  require("neo-tree.command").execute({
    action = "focus",
    source = "last",
    reveal = true,
    toggle = true,
  })
end

function M.reveal_file_explorer()
  local ft_current = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  if ft_current == "neo-tree" then
    require("neo-tree.command").execute({
      action = "close",
    })
  else
    require("neo-tree.command").execute({
      action = "focus",
      source = "filesystem",
      position = "left",
      reveal = true,
    })
  end
end

function M.close_all_explorers()
  require("neo-tree.command").execute({
    action = "close",
    source = "filesystem",
  })

  require("neo-tree.command").execute({
    action = "close",
    source = "buffers",
  })

  require("neo-tree.command").execute({
    action = "close",
    source = "git_status",
  })
end

return M
