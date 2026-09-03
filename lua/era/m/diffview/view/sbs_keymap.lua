---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.sbs_keymap" ---@type string

---Side-by-side buffers are shared across Diffview tabs. Resolve their actions from the current tab
---instead of retaining the context of whichever view most recently installed buffer-local keymaps.
---@class era.m.diffview.view.sbs_keymap
local M = {}

local DESCRIPTIONS = {
  ["<C-a>r"] = "diffview(sbs): Refresh current view",
  ["<C-j>"] = "diffview(sbs): Next item in active preview",
  ["<C-k>"] = "diffview(sbs): Previous item in active preview",
  ["P"] = "diffview(sbs): Previous standalone commits layout",
  ["g?"] = "diffview(sbs): Show current view keymap help",
  ["gF"] = "diffview(sbs): Open active preview file in new tab",
  ["gf"] = "diffview(sbs): Open active preview file in previous tab",
  ["ghu"] = "diffview(sbs): Unstage selected workspace index lines",
  ["gs"] = "diffview(sbs): Stage active workspace file",
  ["gu"] = "diffview(sbs): Unstage active workspace file",
  ["p1"] = "diffview(sbs): Use standalone commits layout 1",
  ["p2"] = "diffview(sbs): Use standalone commits layout 2",
  ["p3"] = "diffview(sbs): Use standalone commits layout 3",
  ["p4"] = "diffview(sbs): Use standalone commits layout 4",
  ["p5"] = "diffview(sbs): Use standalone commits layout 5",
  ["pp"] = "diffview(sbs): Next standalone commits layout",
  ["t0"] = "diffview(sbs): Cycle standalone commits layout",
  ["t3"] = "diffview(sbs): Toggle active preview default folds",
  ["t4"] = "diffview(sbs): Toggle workspace untracked files",
  ["zC"] = "diffview(sbs): Close all active preview folds",
  ["zM"] = "diffview(sbs): Close all active preview folds",
  ["zO"] = "diffview(sbs): Open all active preview folds",
  ["zR"] = "diffview(sbs): Open all active preview folds",
  ["za"] = "diffview(sbs): Toggle active preview item",
  ["zc"] = "diffview(sbs): Collapse active preview item",
  ["zo"] = "diffview(sbs): Expand active preview item",
} ---@type table<string, string>

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
---@return boolean handled
function M.dispatch(mode, key)
  local keymap = get_current_mapping(mode, key)
  if not keymap then
    return false
  end
  keymap.callback()
  return true
end

---@param mode                           string
---@param key                            string
---@return string
local function plug_name(mode, key)
  local encoded_key = key:gsub(".", function(char)
    return string.format("%02x", string.byte(char))
  end)
  return string.format("<Plug>(diffview-sbs-%s-%s)", mode, encoded_key)
end

---Install the explicit union of keys used by each view as the shared SBS buffer encounters them.
---An expression mapping preserves counts/registers while selecting either the original key or a
---non-expression <Plug> callback, keeping action side effects outside expression-map textlock.
---@param keymaps                        stl.t.IKeymap[]
---@param bufnr                          integer
local function setup(keymaps, bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, keymap in ipairs(keymaps) do
    for _, mode in ipairs(keymap.modes) do
      local plug = plug_name(mode, keymap.key) ---@type string
      vim.keymap.set(mode, plug, function()
        M.dispatch(mode, keymap.key)
      end, {
        buffer = bufnr,
        silent = true,
      })

      local function bind(key)
        vim.keymap.set(mode, key, function()
          if get_current_mapping(mode, keymap.key) then
            return plug
          end
          return key
        end, {
          buffer = bufnr,
          desc = DESCRIPTIONS[keymap.key] or keymap.desc,
          expr = true,
          nowait = true,
          replace_keycodes = true,
          silent = true,
        })
      end
      bind(keymap.key)
      for _, alias in ipairs(keymap.aliases or {}) do
        bind(alias)
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
