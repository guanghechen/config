local path = require("eve.builtin.path")
local fts = require("eve.constant.filetype")

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

---@param context                       eve.command.IContext
---@return nil
function M.fs_cwd(context)
  local bufnr = context.bufnr ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == fts.NEOTREE ---@type boolean

  cwd = path.cwd()
  close_explorer_sources({ "git_status", "buffers" })
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = cwd,
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@param context                       eve.command.IContext
---@return nil
function M.fs_workspace(context)
  local bufnr = context.bufnr ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == fts.NEOTREE ---@type boolean

  cwd = path.workspace()
  close_explorer_sources({ "git_status", "buffers" })
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = cwd,
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@param context                       eve.command.IContext
---@return nil
function M.fs_reveal(context)
  local bufnr = context.bufnr ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
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

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.git_cwd(context)
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

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.git_workspace(context)
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

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.last(context)
  require("neo-tree.command").execute({
    action = "focus",
    source = "last",
    dir = cwd,
    reveal = false,
    toggle = true,
  })
end

---@param context                       eve.command.IContext
---@return nil
function M.toggle(context)
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
    M.last(context)
  end
end

return M
