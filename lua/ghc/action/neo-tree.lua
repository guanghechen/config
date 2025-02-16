local path = require("eve.builtin.path")
local ft = require("eve.constant.filetype")
local editor = require("eve.module.editor")
local state = require("eve.state")
local command = require("eve.command")

---@param cwd                           string
---@return boolean
local function check_could_reveal(cwd)
  local bufnr = command.context_bufnr() ---@type integer|nil
  if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    return path.is_under(cwd, filepath)
  end
  return false
end

---@class ghc.action.neo_tree.ICreateWidgetParams
---@field public name                   string
---@field public source                 string
---@field public position               "float"|"left"|"right"
---@field public cwd                    fun(): string

---@param params                        ghc.action.neo_tree.ICreateWidgetParams
---@return eve.t.ux.IWidget
local function create_widget(params)
  local name = params.name ---@type string
  local source = params.source ---@type string
  local position = params.position ---@type "float"|"left"|"right"

  return state.widget.wrap({
    name = name,
    close = function()
      require("neo-tree.command").execute({
        source = source,
        action = "close",
      })
    end,
    focus = function()
      local cwd = params.cwd() ---@type string
      require("neo-tree.command").execute({
        action = "focus",
        source = source,
        dir = cwd,
        position = position,
        reveal = check_could_reveal(cwd),
        toggle = false,
      })
    end,
    focused = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local filetype = vim.bo[bufnr].filetype ---@type string
      return filetype == ft.NEOTREE and vim.b[bufnr].neo_tree_source == source
    end,
    hide = function()
      require("neo-tree.command").execute({
        source = source,
        action = "close",
      })
    end,
    resize = function() end,
    status = function()
      local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        local filetype = vim.bo[bufnr].filetype ---@type string
        if filetype == ft.NEOTREE and vim.b[bufnr].neo_tree_source == source then
          return "visible"
        end
      end
      return "hidden"
    end,
  })
end

local widgets = {
  fs_cwd = create_widget({
    name = "fs-cwd",
    source = "filesystem",
    position = "float",
    cwd = path.cwd,
  }),
  fs_workspace = create_widget({
    name = "fs-workspace",
    source = "filesystem",
    position = "float",
    cwd = path.workspace,
  }),
  git_cwd = create_widget({
    name = "git-cwd",
    source = "git_status",
    position = "float",
    cwd = path.cwd,
  }),
  git_workspace = create_widget({
    name = "git-workspace",
    source = "git_status",
    position = "float",
    cwd = path.workspace,
  }),
}

---@class ghc.action.neo_tree
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.fs_cwd(context)
  local bufnr = context.bufnr ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == ft.NEOTREE ---@type boolean

  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = path.cwd(),
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.fs_workspace(context)
  local bufnr = context.bufnr ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == ft.NEOTREE ---@type boolean

  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = path.workspace(),
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.fs_reveal(context)
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    position = "left",
    reveal = check_could_reveal(path.workspace()),
    toggle = false,
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.git_cwd(context)
  widgets.git_cwd:focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.git_workspace(context)
  widgets.git_workspace:focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.last(context)
  require("neo-tree.command").execute({
    action = "focus",
    source = "last",
    reveal = false,
    toggle = true,
  })
end

---@param context                       eve.command.IContext
---@return nil
function M.toggle(context)
  if editor.find_winnr(ft.NEOTREE) ~= nil then
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
