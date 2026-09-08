---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.sbs_keymap" ---@type string

---Side-by-side buffers are shared across Diffview tabs. Their binding receives a resolver owned by
---the higher-level view composition so this adapter retains no view or action dependency.
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

---@alias era.m.diffview.view.sbs_keymap.IResolve
---| fun(mode: string, key: string): stl.t.IKeymap|nil

---@param resolve                       era.m.diffview.view.sbs_keymap.IResolve
---@param mode                          string
---@param key                           string
---@return boolean handled
function M.dispatch(resolve, mode, key)
  local keymap = resolve(mode, key)
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
---@param resolve                        era.m.diffview.view.sbs_keymap.IResolve
---@return nil
function M.setup(keymaps, bufnr, resolve)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, keymap in ipairs(keymaps) do
    -- Generated callbacks close over their view context; mappings retain only scalar metadata.
    local canonical_key = keymap.key
    local description = DESCRIPTIONS[canonical_key] or keymap.desc
    local aliases = keymap.aliases or {}
    for _, mode in ipairs(keymap.modes) do
      local plug = plug_name(mode, canonical_key) ---@type string
      vim.keymap.set(mode, plug, function()
        M.dispatch(resolve, mode, canonical_key)
      end, {
        buffer = bufnr,
        silent = true,
      })

      local function bind(key)
        vim.keymap.set(mode, key, function()
          if resolve(mode, canonical_key) then
            return plug
          end
          return key
        end, {
          buffer = bufnr,
          desc = description,
          expr = true,
          nowait = true,
          replace_keycodes = true,
          silent = true,
        })
      end
      bind(canonical_key)
      for _, alias in ipairs(aliases) do
        bind(alias)
      end
    end
  end
end

return M
