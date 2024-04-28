---@class ghc.core.action.explorer.util
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.core.action.explorer
local M = {}

function M.show_file_explorer_workspace()
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = util.path.workspace(),
  })
end

function M.show_file_explorer_cwd()
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = util.path.cwd(),
  })
end

function M.show_buffer_explorer_workspace()
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = util.path.workspace(),
  })
end

function M.show_buffer_explorer_cwd()
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = util.path.cwd(),
  })
end

function M.show_git_explorer_workspace()
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = util.path.workspace(),
  })
end

function M.show_git_explorer_cwd()
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = util.path.cwd(),
  })
end

function M.reveal_file_explorer()
  local ft_current = vim.api.nvim_buf_get_option(0, "filetype")
  if ft_current == "neo-tree" then
    require("neo-tree.command").execute({
      action = "close",
    })
  else
    require("neo-tree.command").execute({
      action = "focus",
      source = "filesystem",
      reveal = true,
    })
  end
end

function M.focus_or_toggle_explorer()
  local ft_current = vim.api.nvim_buf_get_option(0, "filetype")
  if ft_current == "neo-tree" then
    require("neo-tree.command").execute({
      action = "close",
    })
  else
    require("neo-tree.command").execute({
      action = "focus",
      source = "last",
    })
  end
end

function M.toggle_explorer()
  require("neo-tree.command").execute({
    toggle = true,
  })
end

return M
