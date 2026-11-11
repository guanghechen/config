---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.theme" ---@type string

-- Highlight maps of the theme pipeline, read back from namespaces of their own. Suites declare the real `yoz`, `stl`
-- and `dot` globals the pipeline reads.

local M = {}

-- The highlight categories of `dot.theme.hlgroup`, each with a unified implementation for themes without their own.
M.CATEGORIES = { "basic", "explorer", "lsp", "module", "nvimbar", "plugin", "treesitter", "widget" } ---@type string[]

---The theme context of the scheme `name`, opaque unless `transparency` is true.
---@param name                          string
---@param transparency                  ?boolean
---@return stl.t.theme.IContext
function M.context_for(name, transparency)
  local scheme = require("dot.theme.scheme." .. name)
  return { scheme = scheme, theme = scheme.theme, variant = scheme.variant, transparency = transparency == true }
end

---Sets `map` in a new namespace and returns the highlights it holds, as `nvim_get_hl` reads them.
---@param map                           table<string, stl.t.theme.IHlgroup>
---@return table<string, vim.api.keyset.get_hl_info>
function M.render_hlgroup_map(map)
  local nsnr = vim.api.nvim_create_namespace("")
  for name, hlgroup in pairs(map) do
    vim.api.nvim_set_hl(nsnr, name, hlgroup)
  end
  return vim.api.nvim_get_hl(nsnr, { link = true })
end

---Applies `integration` for the scheme of `context` to a new namespace and returns the highlights it holds.
---@param t                             __test__.support.Harness
---@param integration                   dot.e.ThemeIntegration
---@param context                       stl.t.theme.IContext
---@return table<string, vim.api.keyset.get_hl_info>
function M.apply_integration(t, integration, context)
  local theme = dot.context.theme
  local restore = t:patch_table(theme, "get_scheme", function()
    return context.scheme
  end)
  local nsnr = vim.api.nvim_create_namespace("")
  theme.apply_integration({
    theme = "vsc-dark-modern",
    transparency = context.transparency,
    integration = integration,
    nsnr = nsnr,
  })
  restore()
  return vim.api.nvim_get_hl(nsnr, { link = true })
end

return M
