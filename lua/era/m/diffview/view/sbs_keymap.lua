---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.sbs_keymap" ---@type string

---Side-by-side buffers are shared across Diffview tabs. Resolve their actions from the current tab
---instead of retaining the context of whichever view most recently installed buffer-local keymaps.
---@class era.m.diffview.view.sbs_keymap
local M = {}

---@param mode                           string
---@param key                            string
---@return stl.t.IKeymap|nil
local function get_current_mapping(mode, key)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil
  local keymaps = nil ---@type stl.t.IKeymap[]|nil

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local commits_state = require("era.m.diffview.view.commits.state")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")
    local state = workspace_state.get(tabnr)
    local layout = workspace_view.get_layout(tabnr)
    if state and layout then
      local history_state = commits_state.get(tabnr)
      local history = history_state and workspace_view.history_context(layout, state, history_state) or nil
      keymaps = require("era.m.diffview.view.workspace.keymap").gen_sbs({
        layout = layout,
        state = state,
        history = history,
      })
    end
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")
    local state = commits_state.get(tabnr)
    local layout = commits_view.get_layout(tabnr)
    if state and layout then
      keymaps = require("era.m.diffview.view.commits.keymap").gen_sbs({ layout = layout, state = state })
    end
  end

  for _, keymap in ipairs(keymaps or {}) do
    if keymap.key == key and vim.tbl_contains(keymap.modes, mode) then
      return keymap
    end
  end
end

---@param mode                           string
---@param key                            string
function M.dispatch(mode, key)
  local keymap = get_current_mapping(mode, key)
  if keymap then
    return keymap.callback()
  end
end

---Install one view's SBS key set. Reused buffers may accumulate both sets, but every callback is
---dispatched against the view in the current tab.
---@param keymaps                        stl.t.IKeymap[]
---@param bufnr                          integer
local function setup(keymaps, bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, keymap in ipairs(keymaps) do
    for _, mode in ipairs(keymap.modes) do
      local function callback()
        M.dispatch(mode, keymap.key)
      end
      vim.keymap.set(mode, keymap.key, callback, {
        buffer = bufnr,
        desc = keymap.desc,
        nowait = true,
        silent = true,
      })
      for _, alias in ipairs(keymap.aliases or {}) do
        vim.keymap.set(mode, alias, callback, {
          buffer = bufnr,
          desc = keymap.desc,
          nowait = true,
          silent = true,
        })
      end
    end
  end
end

---@param ctx                            era.m.diffview.view.workspace.IContext
---@param bufnr                          integer
function M.setup_workspace(ctx, bufnr)
  setup(require("era.m.diffview.view.workspace.keymap").gen_sbs(ctx), bufnr)
end

---@param ctx                            era.m.diffview.view.commits.IContext
---@param bufnr                          integer
function M.setup_commits(ctx, bufnr)
  setup(require("era.m.diffview.view.commits.keymap").gen_sbs(ctx), bufnr)
end

return M
