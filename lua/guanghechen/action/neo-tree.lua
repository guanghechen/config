local constant = require("eve.lib.constant")
local path = require("eve.lib.path")

local cwd = path.cwd() ---@type string

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
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == "neo-tree" then
      return true
    end
  end
  return false
end

---@return boolean
local function check_could_reveal()
  local filepath = path.current_filepath() ---@type string
  return path.is_under(cwd, filepath)
end

---@class guanghechen.action.neo_tree
local M = {}

---@return nil
function M.fs_cwd()
  cwd = path.cwd()
  close_explorer_sources({ "git_status", "buffers" })

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == constant.FT_NEOTREE ---@type boolean
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = cwd,
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@return nil
function M.fs_workspace()
  cwd = path.workspace()
  close_explorer_sources({ "git_status", "buffers" })

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == constant.FT_NEOTREE ---@type boolean
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = cwd,
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@return nil
function M.fs_reveal()
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

---@return nil
function M.git_cwd()
  cwd = path.cwd()
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

---@return nil
function M.git_workspace()
  cwd = path.workspace()
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

---@return nil
function M.last()
  require("neo-tree.command").execute({
    action = "focus",
    source = "last",
    dir = cwd,
    reveal = false,
    toggle = true,
  })
end

---@return nil
function M.toggle()
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
    M.last()
  end
end

return M
