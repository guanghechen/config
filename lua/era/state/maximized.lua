---@class era.state.maximized.IOriginalFloatWindow
---@field public winnr                  integer
---@field public winblend               integer
---@field public winhighlight           string
---@field public wincfg                 vim.api.keyset.win_config

---@class era.state.maximized.IOriginalNormalWindow
---@field public parent_winnr           integer
---@field public float_winnr            integer
---@field public augroup                integer

---@class era.state.maximized.IContext
---@field public original_float         era.state.maximized.IOriginalFloatWindow|nil
---@field public original_normal        era.state.maximized.IOriginalNormalWindow|nil

---@class era.state.maximized.ResolveResizeOpts
---@field public winblend               integer|nil

---@class era.state.maximized.ResolveResizeResult
---@field public cfg                    vim.api.keyset.win_config
---@field public winblend               integer
---@field public maximized              boolean

---@type era.state.maximized.IContext
local context = {
  original_float = nil,
  original_normal = nil,
}

---@class era.state.maximized
---@field public context                era.state.maximized.IContext
local M = {
  context = context,
}

---@param original                      era.state.maximized.IOriginalFloatWindow
---@return nil
function M.set_original_float(original)
  context.original_float = original
end

---@return era.state.maximized.IOriginalFloatWindow|nil
function M.get_original_float()
  return context.original_float
end

---@return nil
function M.clear_original_float()
  context.original_float = nil
end

---@param original                      era.state.maximized.IOriginalNormalWindow
---@return nil
function M.set_original_normal(original)
  context.original_normal = original
end

---@return era.state.maximized.IOriginalNormalWindow|nil
function M.get_original_normal()
  return context.original_normal
end

---@return nil
function M.clear_original_normal()
  context.original_normal = nil
end

---@param wincfg                        vim.api.keyset.win_config
---@return vim.api.keyset.win_config
function M.compute_float_maximized_wincfg(wincfg)
  local maximize_cfg = vim.deepcopy(wincfg) ---@type vim.api.keyset.win_config
  maximize_cfg.relative = "editor"
  maximize_cfg.anchor = "NW"
  maximize_cfg.col = 0
  maximize_cfg.zindex = (wincfg.zindex or 100) + 1
  maximize_cfg.border = "rounded"

  local editor_width = vim.o.columns ---@type integer
  local editor_height = vim.o.lines ---@type integer
  local top_offset = ark.nvim.is_tabline_visible() and 1 or 0 ---@type integer
  local bottom_offset = ark.nvim.is_statusline_visible() and 1 or 0 ---@type integer
  local available_height = math.max(1, editor_height - top_offset - bottom_offset) ---@type integer

  ---@type integer, integer
  local fitted_width, fitted_height = ark.box.fit_editor(
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

---@param winnr                         integer
---@param desired_cfg                   vim.api.keyset.win_config
---@param opts                          era.state.maximized.ResolveResizeOpts|nil
---@return era.state.maximized.ResolveResizeResult
function M.resolve_resize_config(winnr, desired_cfg, opts)
  local winblend = opts and opts.winblend or nil ---@type integer|nil

  local original = context.original_float ---@type era.state.maximized.IOriginalFloatWindow|nil
  if original ~= nil and original.winnr == winnr then
    original.wincfg = vim.deepcopy(desired_cfg)
    original.winblend = original.winblend or winblend

    local maximize_cfg = M.compute_float_maximized_wincfg(desired_cfg) ---@type vim.api.keyset.win_config
    return {
      cfg = maximize_cfg,
      winblend = era.context.theme.get_float_winblend(),
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
