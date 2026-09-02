---@class dot.state.maximized.IOriginalFloatWindow
---@field public winnr                  integer
---@field public winblend               integer
---@field public winhighlight           string
---@field public wincfg                 vim.api.keyset.win_config

---@class dot.state.maximized.INormalContext
---@field public source_tabnr           integer
---@field public source_winnr           integer
---@field public maximize_tabnr         integer
---@field public maximize_winnr         integer
---@field public augroup                integer
---@field public closing                boolean

---@class dot.state.maximized.IContext
---@field public original_float         ?dot.state.maximized.IOriginalFloatWindow
---@field public normal                 ?dot.state.maximized.INormalContext

---@class dot.state.maximized.ResolveResizeOpts
---@field public winblend               ?integer

---@class dot.state.maximized.ResolveResizeResult
---@field public cfg                    vim.api.keyset.win_config
---@field public winblend               integer
---@field public maximized              boolean

---@type dot.state.maximized.IContext
local context = {
  original_float = nil,
  normal = nil,
}

---@class dot.state.maximized
---@field public context                dot.state.maximized.IContext
local M = {
  context = context,
}

---@param original                      dot.state.maximized.IOriginalFloatWindow
---@return nil
function M.set_original_float(original)
  context.original_float = original
end

---@return dot.state.maximized.IOriginalFloatWindow|nil
function M.get_original_float()
  return context.original_float
end

---@return nil
function M.clear_original_float()
  context.original_float = nil
end

---@param normal                        dot.state.maximized.INormalContext
---@return nil
function M.set_normal(normal)
  context.normal = normal
end

---@return dot.state.maximized.INormalContext|nil
function M.get_normal()
  return context.normal
end

---Synchronize the maximize projection back to its source window.
---@param normal                        dot.state.maximized.INormalContext
---@return nil
function M.sync_normal(normal)
  if
    context.normal ~= normal
    or not vim.api.nvim_win_is_valid(normal.maximize_winnr)
    or not vim.api.nvim_win_is_valid(normal.source_winnr)
  then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(normal.maximize_winnr) ---@type integer
  local view_ok, view = pcall(vim.api.nvim_win_call, normal.maximize_winnr, function()
    return vim.fn.winsaveview()
  end)
  if not view_ok then
    return
  end

  local buf_ok = pcall(vim.api.nvim_win_set_buf, normal.source_winnr, bufnr) ---@type boolean
  if not buf_ok then
    return
  end

  if vim.api.nvim_tabpage_is_valid(normal.source_tabnr) then
    dot.tab.add_buf(normal.source_tabnr, bufnr, false)
  end
  pcall(vim.api.nvim_win_call, normal.source_winnr, function()
    vim.fn.winrestview(view)
  end)
end

---Dispose the active normal context only when identity still matches.
---@param normal                        dot.state.maximized.INormalContext
---@return boolean
function M.dispose_normal(normal)
  if context.normal ~= normal then
    return false
  end

  context.normal = nil
  pcall(vim.api.nvim_del_augroup_by_id, normal.augroup)
  return true
end

---@return nil
function M.clear_normal()
  context.normal = nil
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
  local top_offset = stl.nvim.fn.is_tabline_visible() and 1 or 0 ---@type integer
  local bottom_offset = stl.nvim.fn.is_statusline_visible() and 1 or 0 ---@type integer
  local available_height = math.max(1, editor_height - top_offset - bottom_offset) ---@type integer

  ---@type integer, integer
  local fitted_width, fitted_height = stl.box.fit_editor(
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
---@param opts                          ?dot.state.maximized.ResolveResizeOpts
---@return dot.state.maximized.ResolveResizeResult
function M.resolve_resize_config(winnr, desired_cfg, opts)
  local winblend = opts and opts.winblend or nil ---@type integer|nil

  local original = context.original_float ---@type dot.state.maximized.IOriginalFloatWindow|nil
  if original ~= nil and original.winnr == winnr then
    original.wincfg = vim.deepcopy(desired_cfg)
    original.winblend = original.winblend or winblend

    local maximize_cfg = M.compute_float_maximized_wincfg(desired_cfg) ---@type vim.api.keyset.win_config
    return {
      cfg = maximize_cfg,
      winblend = dot.context.theme.get_float_winblend(),
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
