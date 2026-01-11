---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap" ---@type string

local util = require("era.m.minimap.util")
local view = require("era.m.minimap.view")
local mouse = require("era.m.minimap.mouse")

---@class era.m.minimap
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local FOLDMAPS = {
  zF = true,
  zd = true,
  zD = true,
  zE = true,
  zo = true,
  zO = true,
  zc = true,
  zC = true,
  za = true,
  zA = true,
  zv = true,
  zx = true,
  zX = true,
  zm = true,
  zM = true,
  zr = true,
  zR = true,
  zn = true,
  zN = true,
  zi = true,
}

---@type stl.t.IKeymap[]
local KEYMAPS = {
  {
    modes = { "n", "v", "o", "i" },
    key = "<LeftMouse>",
    callback = mouse.handle_leftmouse,
    desc = "minimap: handle left mouse",
  },
}

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------

local did_dressing = false ---@type boolean
local on_key_ns = nil ---@type integer|nil
local gname = vim.api.nvim_create_augroup("era.m.minimap", {}) ---@type integer

----------------------------------------------------------------------------------------------------
-- Internal functions
----------------------------------------------------------------------------------------------------

local function remove_on_key()
  if on_key_ns then
    vim.on_key(nil, on_key_ns)
    on_key_ns = nil
  end
end

local function apply_on_key()
  if on_key_ns then
    return
  end

  local prev = ""
  on_key_ns = vim.on_key(function(_, typed)
    if typed == "z" then
      prev = "z"
      return
    end
    local seq = prev .. typed
    if FOLDMAPS[seq] or seq == "zf" then
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      util.invalidate_virtual_line_count_cache(winnr)
      vim.schedule(view.refresh)
    end
    prev = ""
  end)
end

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---Toggle minimap globally via context state.
function M.toggle()
  local flag = dot.context.plugin.minimap:snapshot() ---@type boolean
  dot.context.plugin.minimap:next(not flag)
end

---Attach minimap to a specific window.
---@param winnr                       integer
function M.attach(winnr)
  view.attach(winnr)
end

---Detach minimap from a specific window.
---@param winnr                       integer
function M.detach(winnr)
  view.detach(winnr)
end

---Toggle minimap for a specific window.
---@param winnr                       integer
function M.toggle_local(winnr)
  if view.is_attached(winnr) then
    view.detach(winnr)
  else
    view.attach(winnr)
  end
end

---Refresh all minimap bars.
function M.refresh()
  view.refresh()
end

---Check if minimap is globally enabled.
---@return boolean
function M.enabled()
  return view.enabled()
end

---Check if minimap is attached to a specific window.
---@param winnr                       integer
---@return boolean
function M.is_attached(winnr)
  return view.is_attached(winnr)
end

---Initialize minimap module. Call this once during startup.
function M.dressing()
  if did_dressing then
    return
  end
  did_dressing = true

  local function setup(flag)
    -- Cleanup first
    remove_on_key()
    vim.api.nvim_clear_autocmds({ group = gname })
    for _, keymap in ipairs(KEYMAPS) do
      for _, mode in ipairs(keymap.modes) do
        pcall(vim.keymap.del, mode, keymap.key)
      end
    end

    if flag then
      view.attach_global()
      apply_on_key()
      stl.nvim.fn.bindkeys(KEYMAPS, {})

      vim.api.nvim_create_autocmd("WinEnter", {
        group = gname,
        callback = function()
          if util.in_cmdline_win() then
            view.detach_all()
          end
        end,
      })

      vim.api.nvim_create_autocmd("WinLeave", {
        group = gname,
        callback = function()
          vim.defer_fn(view.refresh, 0)
        end,
      })

      vim.api.nvim_create_autocmd({
        "WinEnter",
        "TermEnter",
        "CmdwinLeave",
        "WinScrolled",
        "TextChanged",
        "BufWinEnter",
        "TabEnter",
        "VimResized",
      }, {
        group = gname,
        callback = vim.schedule_wrap(view.refresh),
      })
    else
      view.detach_global()
    end
  end

  -- Initial setup based on current value
  local initial_flag = dot.context.plugin.minimap:snapshot() ---@type boolean
  if initial_flag then
    setup(true)
  end

  -- Subscribe to future changes
  stl.fn.observe({ dot.context.plugin.minimap }, function()
    local flag = dot.context.plugin.minimap:snapshot() ---@type boolean
    setup(flag)
  end, true)
end

return M
