---@param cwd                           string
---@return boolean
local function check_could_reveal(cwd)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer|nil
  if bufnr ~= nil and eve.editor.is_buf_valid(bufnr) then
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    return eve.path.is_under(cwd, filepath)
  end
  return false
end

---@class ghc.action.neo_tree.ICreateWidgetParams
---@field public name                   string
---@field public source                 string
---@field public cwd                    fun(): string

---@param params                        ghc.action.neo_tree.ICreateWidgetParams
---@return eve.t.ux.IWidget
local function create_widget(params)
  local name = params.name ---@type string
  local source = params.source ---@type string

  ---@return integer|nil
  ---@return integer|nil
  local function locate_neotree_winnr()
    local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      if eve.editor.is_win_floating(winnr) then
        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        local filetype = vim.bo[bufnr].filetype ---@type string
        if filetype == eve.filetype.NEOTREE then
          return winnr, bufnr
        end
      end
    end
    return nil
  end

  return eve.state.widget.wrap({
    name = name,
    close = function()
      local winnr, bufnr = locate_neotree_winnr() ---@type integer|nil, integer|nil
      if winnr ~= nil and bufnr ~= nil then
        local next_source = vim.b[bufnr][eve.var.Names.NEO_TREE_SOURCE] ---@type string
        source = next_source
        vim.api.nvim_win_close(winnr, true)
      end
    end,
    focus = function()
      local cwd = params.cwd() ---@type string
      require("neo-tree.command").execute({
        action = "focus",
        source = source,
        dir = cwd,
        position = "float",
        reveal = check_could_reveal(cwd),
        toggle = false,
      })
    end,
    focused = function()
      local winnr = locate_neotree_winnr() ---@type integer|nil
      local winnr_current = vim.api.nvim_get_current_win() ---@type integer
      return winnr == winnr_current
    end,
    hide = function()
      local winnr, bufnr = locate_neotree_winnr() ---@type integer|nil, integer|nil
      if winnr ~= nil and bufnr ~= nil then
        local next_source = vim.b[bufnr][eve.var.Names.NEO_TREE_SOURCE] ---@type string
        source = next_source
        vim.api.nvim_win_close(winnr, true)
      end
    end,
    resize = function() end,
    status = function()
      local winnr = locate_neotree_winnr() ---@type integer|nil
      return winnr == nil and "hidden" or "visible"
    end,
  })
end

local widgets = {
  git_cwd = create_widget({
    name = "git-cwd",
    source = "git_status",
    cwd = eve.path.cwd,
  }),
  git_workspace = create_widget({
    name = "git-workspace",
    source = "git_status",
    cwd = eve.path.workspace,
  }),
}

---@class ghc.action.neo_tree
local M = {}

---@return nil
function M.fs_cwd()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == eve.filetype.NEOTREE ---@type boolean

  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = eve.path.cwd(),
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@return nil
function M.fs_workspace()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local ft_current = vim.bo[bufnr].filetype ---@type string
  local toggle = ft_current == eve.filetype.NEOTREE ---@type boolean

  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    dir = eve.path.workspace(),
    position = "left",
    reveal = false,
    toggle = toggle,
  })
end

---@return nil
function M.fs_reveal()
  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    position = "left",
    reveal = check_could_reveal(eve.path.workspace()),
    toggle = false,
  })
end

---@return nil
function M.git_cwd()
  local widget = widgets.git_cwd ---@type eve.t.ux.IWidget
  if widget:focused() then
    widget:hide()
  else
    widget:focus()
  end
end

---@return nil
function M.git_workspace()
  local widget = widgets.git_workspace ---@type eve.t.ux.IWidget
  if widget:focused() then
    widget:hide()
  else
    widget:focus()
  end
end

---@return nil
function M.last()
  require("neo-tree.command").execute({
    action = "focus",
    source = "last",
    reveal = false,
    toggle = true,
  })
end

---@return nil
function M.toggle()
  if eve.editor.find_winnr(eve.filetype.NEOTREE) ~= nil then
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
