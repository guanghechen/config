---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.binding" ---@type string

---@class era.m.diffview.view.binding
---@field public resolve                 fun(mode: string, key: string): stl.t.IKeymap|nil
local M = {}

---@class era.m.diffview.view.binding.ICommitsContext : era.m.diffview.view.commits.IContext
---@field public get_keymaps             fun(): stl.t.IKeymap[]
---@field public setup_commits           fun(): nil
---@field public setup_filetree          fun(): nil
---@field public setup_keymaps           fun(): nil
---@field public setup_sbs               fun(bufnr: integer): nil

---@class era.m.diffview.view.binding.IWorkspaceContext : era.m.diffview.view.workspace.IContext
---@field public get_keymaps             fun(): stl.t.IKeymap[]
---@field public setup_changes           fun(): nil
---@field public setup_history           fun(): nil
---@field public setup_keymaps           fun(): nil
---@field public setup_sbs               fun(bufnr: integer): nil

---@param keymaps                       stl.t.IKeymap[]
---@param mode                          string
---@param key                           string
---@return stl.t.IKeymap|nil
local function find_keymap(keymaps, mode, key)
  for _, keymap in ipairs(keymaps) do
    if keymap.key == key and vim.tbl_contains(keymap.modes, mode) then
      return keymap
    end
  end
end

---@param layout                        { sbs_left_winnr: integer|nil, sbs_right_winnr: integer|nil }
---@param setup                         fun(bufnr: integer): nil
---@return nil
local function setup_sbs_windows(layout, setup)
  if layout.sbs_left_winnr ~= nil and vim.api.nvim_win_is_valid(layout.sbs_left_winnr) then
    setup(vim.api.nvim_win_get_buf(layout.sbs_left_winnr))
  end
  if layout.sbs_right_winnr ~= nil and vim.api.nvim_win_is_valid(layout.sbs_right_winnr) then
    setup(vim.api.nvim_win_get_buf(layout.sbs_right_winnr))
  end
end

---@param mode                          string
---@param key                           string
---@return stl.t.IKeymap|nil
local function resolve_current_keymap(mode, key)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local commits_state = require("era.m.diffview.view.commits.state")
    local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")
    local state = workspace_state.get(tabnr)
    local layout = workspace_view.get_layout(tabnr)
    if state ~= nil and layout ~= nil then
      local history_state = commits_state.get(tabnr)
      local history = history_state and workspace_view.history_context(layout, state, history_state) or nil
      local ctx = M.workspace({ layout = layout, state = state, history = history })
      return find_keymap(workspace_keymap.gen_sbs(ctx), mode, key)
    end
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_keymap = require("era.m.diffview.view.commits.keymap")
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")
    local state = commits_state.get(tabnr)
    local layout = commits_view.get_layout(tabnr)
    if state ~= nil and layout ~= nil then
      local ctx = M.commits({ layout = layout, state = state })
      return find_keymap(commits_keymap.gen_sbs(ctx), mode, key)
    end
  end
end

M.resolve = resolve_current_keymap

---@param ctx                           era.m.diffview.view.commits.IContext
---@return era.m.diffview.view.binding.ICommitsContext
function M.commits(ctx)
  local commits_keymap = require("era.m.diffview.view.commits.keymap")
  local sbs_keymap = require("era.m.diffview.view.sbs_keymap")
  ctx.get_keymaps = function()
    return commits_keymap.get_help_keymaps(ctx)
  end
  local function setup_sbs(bufnr)
    sbs_keymap.setup(commits_keymap.gen_sbs(ctx), bufnr, resolve_current_keymap)
  end
  local function setup_commits()
    commits_keymap.setup_commits(ctx)
  end
  local function setup_filetree()
    commits_keymap.setup_filetree(ctx)
  end
  ctx.setup_commits = setup_commits
  ctx.setup_filetree = setup_filetree
  ctx.setup_sbs = setup_sbs
  ctx.setup_keymaps = function()
    setup_commits()
    setup_filetree()
    setup_sbs_windows(ctx.layout, setup_sbs)
  end
  ---@cast ctx era.m.diffview.view.binding.ICommitsContext
  return ctx
end

---@param ctx                           era.m.diffview.view.workspace.IContext
---@return era.m.diffview.view.binding.IWorkspaceContext
function M.workspace(ctx)
  local sbs_keymap = require("era.m.diffview.view.sbs_keymap")
  local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
  ctx.get_keymaps = function()
    return workspace_keymap.get_help_keymaps(ctx)
  end
  local function setup_sbs(bufnr)
    sbs_keymap.setup(workspace_keymap.gen_sbs(ctx), bufnr, resolve_current_keymap)
  end
  local function setup_changes()
    workspace_keymap.setup_changes(ctx)
  end
  local function setup_history()
    workspace_keymap.setup_history(ctx)
  end
  ctx.setup_changes = setup_changes
  ctx.setup_history = setup_history
  ctx.setup_sbs = setup_sbs
  ctx.setup_keymaps = function()
    setup_changes()
    setup_history()
    setup_sbs_windows(ctx.layout, setup_sbs)
  end

  if ctx.history ~= nil then
    ctx.history.get_keymaps = ctx.get_keymaps
    ctx.history.setup_commits = setup_history
    ctx.history.setup_sbs = ctx.setup_sbs
    ctx.history.setup_keymaps = ctx.setup_keymaps
  end
  ---@cast ctx era.m.diffview.view.binding.IWorkspaceContext
  return ctx
end

return M
