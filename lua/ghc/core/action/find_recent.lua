local context_session = require("ghc.core.context.session")
local util_path = require("guanghechen.util.path")

local autocmd = require("ghc.core.action.autocmd")

---@alias IFindRecentContext { workspace: string, cwd: string, directory: string, bufnr: number }

---@param find_recent_context IFindRecentContext
---@param scope ghc.core.types.enum.FIND_RECENT_SCOPE
local function get_cwd_by_scope(find_recent_context, scope)
  if scope == "W" then
    return find_recent_context.workspace
  end

  if scope == "C" then
    return find_recent_context.cwd
  end

  if scope == "D" then
    return find_recent_context.directory
  end

  return find_recent_context.cwd
end

---@param scope ghc.core.types.enum.FIND_RECENT_SCOPE
---@return string
local function get_display_name_of_scope(scope)
  if scope == "W" then
    return "workspace"
  end

  if scope == "C" then
    return "cwd"
  end

  if scope == "D" then
    return "directory"
  end

  return "cwd"
end

---@param scope ghc.core.types.enum.FIND_RECENT_SCOPE
---@return ghc.core.types.enum.FIND_RECENT_SCOPE
local function toggle_scope_carousel(scope)
  if scope == "W" then
    return "C"
  end

  if scope == "C" then
    return "D"
  end

  if scope == "D" then
    return "W"
  end

  return "C"
end

---@param opts? table
local function find_recent(opts)
  ---@type IFindRecentContext
  local find_recent_context = {
    workspace = util_path.workspace(),
    cwd = util_path.cwd(),
    directory = util_path.current_directory(),
    bufnr = vim.api.nvim_get_current_buf(),
  }
  context_session.caller_winnr:next(vim.api.nvim_get_current_win())
  context_session.caller_bufnr:next(vim.api.nvim_get_current_buf())

  opts = opts or {}
  opts.initial_mode = "normal"
  opts.bufnr = find_recent_context.bufnr
  opts.show_untracked = true
  opts.workspace = "CWD"

  ---@type fun():nil
  local open_picker

  ---@param scope_next ghc.core.types.enum.FIND_RECENT_SCOPE
  local function change_scope(scope_next)
    local scope_current = context_session.find_recent_scope:get_snapshot()
    if scope_next ~= scope_current then
      context_session.find_recent_scope:next(scope_next)
      open_picker()
    end
  end

  local actions = {
    change_scope_workspace = function()
      change_scope("W")
    end,
    change_scope_cwd = function()
      change_scope("C")
    end,
    change_scope_directory = function()
      change_scope("D")
    end,
    change_scope_carousel = function()
      ---@type ghc.core.types.enum.FIND_RECENT_SCOPE
      local scope = context_session.find_recent_scope:get_snapshot()
      local scope_next = toggle_scope_carousel(scope)
      change_scope(scope_next)
    end,
  }

  open_picker = function()
    ---@type ghc.core.types.enum.FIND_RECENT_SCOPE
    local scope = context_session.find_recent_scope:get_snapshot()
    opts.cwd = get_cwd_by_scope(find_recent_context, scope)
    opts.initial_mode = "normal"

    require("telescope").extensions.frecency.frecency(vim.tbl_deep_extend("force", {
      prompt_title = "Find recent (" .. get_display_name_of_scope(scope) .. ")",
      default_text = context_session.find_recent_keyword:get_snapshot(),
      show_untracked = true,
      workspace = "CWD",
      attach_mappings = function(prompt_bufnr)
        local function mapkey(mode, key, action, desc)
          vim.keymap.set(mode, key, action, { buffer = prompt_bufnr, silent = true, noremap = true, desc = desc })
        end

        if opts.mappings then
          for mode, mappings in pairs(opts.mappings) do
            for key, action in pairs(mappings) do
              mapkey(mode, key, action)
            end
          end
        end

        mapkey("n", "<leader>w", actions.change_scope_workspace)
        mapkey("n", "<leader>c", actions.change_scope_cwd)
        mapkey("n", "<leader>d", actions.change_scope_directory)
        mapkey("n", "<leader>s", actions.change_scope_carousel)

        ---@type ghc.core.types.enum.BUFTYPE_EXTRA
        local buftype_extra = "find_recent"
        context_session.buftype_extra:next(buftype_extra)

        autocmd.autocmd_clear_buftype_extra(prompt_bufnr)
        autocmd.autocmd_remember_telescope_prompt(prompt_bufnr, function(prompt)
          context_session.find_recent_keyword:next(prompt)
        end)

        return true
      end,
    }, opts))
  end

  open_picker()
end

---@class ghc.core.action.find_recent
local M = {}

function M.find_recent_workspace()
  context_session.find_recent_scope:next("W")
  find_recent()
end

function M.find_recent_cwd()
  context_session.find_recent_scope:next("C")
  find_recent()
end

function M.find_recent_current()
  context_session.find_recent_scope:next("D")
  find_recent()
end

function M.find_recent()
  find_recent()
end

return M
