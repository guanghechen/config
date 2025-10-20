---@class eve.state.maximized.IOriginalWindow
---@field public winnr                   integer
---@field public winblend                integer
---@field public wincfg                  vim.api.keyset.win_config

---@class eve.state.maximized.IContext
---@field public MAXIMIZED_ZINDEX        integer
---@field public original                eve.state.maximized.IOriginalWindow|nil

---@class eve.state.maximized.ResolveResizeOpts
---@field public winblend                integer|nil

---@class eve.state.maximized.ResolveResizeResult
---@field public cfg                     vim.api.keyset.win_config
---@field public winblend                integer
---@field public maximized               boolean

---@type eve.state.maximized.IContext
local context = {
  MAXIMIZED_ZINDEX = 2000,
  original = nil,
}

---@module 'eve.state.maximized'
---@class eve.state.maximized
---@field public context                 eve.state.maximized.IContext
local M = {
  context = context,
}

---@param original                      eve.state.maximized.IOriginalWindow
---@return nil
function M.set_original(original)
  context.original = original
end

---@return eve.state.maximized.IOriginalWindow|nil
function M.get_original()
  return context.original
end

---@return nil
function M.clear_original()
  context.original = nil
end

---@param wincfg                         vim.api.keyset.win_config
---@return vim.api.keyset.win_config
function M.compute_maximized_wincfg(wincfg)
  local maximize_cfg = vim.deepcopy(wincfg) ---@type vim.api.keyset.win_config
  maximize_cfg.relative = "editor"
  maximize_cfg.anchor = "NW"
  maximize_cfg.col = 0
  maximize_cfg.zindex = context.MAXIMIZED_ZINDEX

  local editor_width = vim.o.columns ---@type integer
  local editor_height = vim.o.lines ---@type integer
  local top_offset = eve.nvim.is_tabline_visible() and 1 or 0 ---@type integer
  local bottom_offset = eve.nvim.is_statusline_visible() and 1 or 0 ---@type integer
  local available_height = math.max(1, editor_height - top_offset - bottom_offset) ---@type integer

  ---@type integer, integer
  local fitted_width, fitted_height = eve.box.fit_editor(
    editor_width,
    available_height,
    maximize_cfg.border,
    { cols = editor_width, rows = available_height }
  )

  maximize_cfg.row = top_offset
  maximize_cfg.width = fitted_width
  maximize_cfg.height = fitted_height

  return maximize_cfg
end

---@param winnr                          integer
---@param desired_cfg                    vim.api.keyset.win_config
---@param opts                           eve.state.maximized.ResolveResizeOpts|nil
---@return eve.state.maximized.ResolveResizeResult
function M.resolve_resize_config(winnr, desired_cfg, opts)
  local winblend = opts and opts.winblend or nil ---@type integer|nil

  local original = context.original ---@type eve.state.maximized.IOriginalWindow|nil
  if original ~= nil and original.winnr == winnr then
    original.wincfg = vim.deepcopy(desired_cfg)
    original.winblend = original.winblend or winblend

    local maximize_cfg = M.compute_maximized_wincfg(desired_cfg) ---@type vim.api.keyset.win_config
    return {
      cfg = maximize_cfg,
      winblend = 0,
      maximized = true,
    }
  end

  return {
    cfg = desired_cfg,
    winblend = winblend or 0,
    maximized = false,
  }
end

return M
