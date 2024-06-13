local guanghechen = require("guanghechen")

local have_set_cwd = false ---@type boolean

---@param sources ("buffers"|"filesystem"|"git_status")[]
---@return nil
local function close_explorer_sources(sources)
  for _, source in ipairs(sources) do
    require("neo-tree.command").execute({
      source = source,
      action = "close",
    })
  end
end

---@return boolean
local function has_explorer_window_opened()
  for _, winnr in pairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type number
    if vim.bo[bufnr].ft == "neo-tree" then
      return true
    end
  end
  return false
end

---@class ghc.core.action.explorer
local M = {}

function M.toggle_explorer_file_workspace()
  close_explorer_sources({ "git_status", "buffers" })

  have_set_cwd = true

  local ft_current = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local toggle = ft_current == "neo-tree" ---@type boolean
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = guanghechen.util.path.workspace(),
    position = "left",
    reveal = true,
    toggle = toggle,
  })
end

function M.toggle_explorer_file_cwd()
  close_explorer_sources({ "git_status", "buffers" })

  have_set_cwd = true

  local ft_current = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local toggle = ft_current == "neo-tree" ---@type boolean
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = guanghechen.util.path.cwd(),
    position = "left",
    reveal = true,
    toggle = toggle,
  })
end

function M.toggle_explorer_buffer_workspace()
  close_explorer_sources({ "git_status" })

  have_set_cwd = true
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = guanghechen.util.path.workspace(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_buffer_cwd()
  close_explorer_sources({ "git_status" })

  have_set_cwd = true
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = guanghechen.util.path.cwd(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_git_workspace()
  close_explorer_sources({ "buffers" })

  have_set_cwd = true
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = guanghechen.util.path.workspace(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_git_cwd()
  close_explorer_sources({ "buffers" })

  have_set_cwd = true
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = guanghechen.util.path.cwd(),
    position = "float",
    reveal = true,
    toggle = true,
  })
end

function M.toggle_explorer_last()
  local opts = {
    action = "focus",
    source = "last",
    reveal = true,
    toggle = true,
  }
  if not have_set_cwd then
    opts.dir = guanghechen.util.path.cwd()
  end
  require("neo-tree.command").execute(opts)
end

function M.reveal_file_explorer()
  close_explorer_sources({ "git_status", "buffers" })

  local ft_current = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  if ft_current == "neo-tree" then
    require("neo-tree.command").execute({
      action = "close",
    })
  else
    local opts = {
      action = "focus",
      source = "filesystem",
      position = "left",
      reveal = true,
    }
    if not have_set_cwd then
      opts.dir = guanghechen.util.path.cwd()
    end
    require("neo-tree.command").execute(opts)
  end
end

function M.toggle_explorers()
  if has_explorer_window_opened() then
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
  else
    M.toggle_explorer_last()
  end
end

return M
