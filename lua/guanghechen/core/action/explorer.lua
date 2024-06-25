local cwd = fml.path.cwd() ---@type string

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

---@return boolean
local function check_could_reveal()
  local filepath = fml.path.current_filepath() ---@type string
  return fml.path.is_under(cwd, filepath)
end

---@class guanghechen.core.action.explorer
local M = {}

function M.toggle_explorer_file_workspace()
  cwd = fml.path.workspace()
  close_explorer_sources({ "git_status", "buffers" })
  local ft_current = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local toggle = ft_current == "neo-tree" ---@type boolean
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = cwd,
    position = "left",
    reveal = check_could_reveal(),
    toggle = toggle,
  })
end

function M.toggle_explorer_file_cwd()
  cwd = fml.path.cwd()

  close_explorer_sources({ "git_status", "buffers" })
  local ft_current = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  local toggle = ft_current == "neo-tree" ---@type boolean
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = cwd,
    position = "left",
    reveal = check_could_reveal(),
    toggle = toggle,
  })
end

function M.toggle_explorer_buffer_workspace()
  cwd = fml.path.workspace()
  close_explorer_sources({ "git_status" })
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = cwd,
    position = "float",
    reveal = check_could_reveal(),
    toggle = true,
  })
end

function M.toggle_explorer_buffer_cwd()
  cwd = fml.path.cwd()
  close_explorer_sources({ "git_status" })
  require("neo-tree.command").execute({
    action = "focus",
    source = "buffers",
    dir = cwd,
    position = "float",
    reveal = check_could_reveal(),
    toggle = true,
  })
end

function M.toggle_explorer_git_workspace()
  cwd = fml.path.workspace()
  close_explorer_sources({ "buffers" })
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = cwd,
    position = "float",
    reveal = check_could_reveal(),
    toggle = true,
  })
end

function M.toggle_explorer_git_cwd()
  cwd = fml.path.cwd()
  close_explorer_sources({ "buffers" })
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    dir = cwd,
    position = "float",
    reveal = check_could_reveal(),
    toggle = true,
  })
end

function M.toggle_explorer_last()
  require("neo-tree.command").execute({
    action = "focus",
    source = "last",
    dir = cwd,
    reveal = check_could_reveal(),
    toggle = true,
  })
end

function M.reveal_file_explorer()
  close_explorer_sources({ "git_status", "buffers" })

  local ft_current = vim.api.nvim_get_option_value("filetype", { buf = 0 })
  if ft_current == "neo-tree" then
    require("neo-tree.command").execute({
      action = "close",
    })
  else
    require("neo-tree.command").execute({
      action = "focus",
      source = "filesystem",
      dir = cwd,
      reveal = check_could_reveal(),
    })
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
