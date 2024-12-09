local path = require("eve.lib.path")
local constant = require("eve.builtin.constant")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

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

eve.commander
  .register({
    uuid = uuids.explorer_filesystem_cwd,
    tabtype = constant.TT_NORMAL,
    desc = "explorer: filesystem (cwd)",
    action = function()
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
    end,
  })
  .register({
    uuid = uuids.explorer_filesystem_workspace,
    tabtype = constant.TT_NORMAL,
    desc = "explorer: filesystem (workspace)",
    action = function()
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
    end,
  })
  .register({
    uuid = uuids.explorer_git_cwd,
    desc = "explorer: git (cwd)",
    action = function()
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
    end,
  })
  .register({
    uuid = uuids.explorer_git_workspace,
    desc = "explorer: git (workspace)",
    action = function()
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
    end,
  })
  .register({
    uuid = uuids.explorer_last,
    desc = "explorer: last",
    action = function()
      require("neo-tree.command").execute({
        action = "focus",
        source = "last",
        dir = cwd,
        reveal = false,
        toggle = true,
      })
    end,
  })
  .register({
    uuid = uuids.explorer_reveal,
    desc = "explorer: reveal",
    action = function()
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
    end,
  })
  .register({
    uuid = uuids.explorer_toggle,
    desc = "explorer: toggle",
    action = function()
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
        eve.commander.execute(uuids.explorer_last)
      end
    end,
  })
