local client = require("ghc.context.client")

local devmode = client.flight_devmode:snapshot() ---@type boolean
local hmr = devmode and eve.util.hmr or require

---@class ghc.ui.theme
local M = {}

---@type ghc.enum.ui.theme.HighlightIntegration[]
M.integrations = {
  --- orders as needed
  "basic",
  "default",
  "statusline",
  "tabline",
  "winline",

  --- plugins
  "treesitter",
  "mini-icons",
  "nvim-lspconfig",
  "lazy",

  "flash",
  "gitsigns",
  "indent-blank-line",
  "mason",
  "nvim-cmp",
  "nvim-dap",
  "nvim-dap-ui",
  "nvim-treesitter-context",
  "trouble",
  "vim-illuminate",
  "vim-notify",
  "which-key",
}

---@param scheme                        fml.types.ui.theme.IScheme
---@return nil
function M.set_term_colors(scheme)
  local c = scheme.palette ---@type fml.types.ui.theme.IPalette
  vim.g.terminal_color_0 = c.black
  vim.g.terminal_color_1 = c.red
  vim.g.terminal_color_2 = c.green
  vim.g.terminal_color_3 = c.yellow
  vim.g.terminal_color_4 = c.blue
  vim.g.terminal_color_5 = c.purple
  vim.g.terminal_color_6 = c.cyan
  vim.g.terminal_color_7 = c.white
  vim.g.terminal_color_8 = c.grey
  vim.g.terminal_color_9 = c.red
  vim.g.terminal_color_10 = c.green
  vim.g.terminal_color_11 = c.yellow
  vim.g.terminal_color_12 = c.blue
  vim.g.terminal_color_13 = c.purple
  vim.g.terminal_color_14 = c.cyan
  vim.g.terminal_color_15 = c.white
end

---@param mode                          fml.enums.theme.Mode
---@return fml.types.ui.theme.IScheme|nil
function M.get_scheme(mode)
  local present_scheme, scheme = pcall(hmr, "ghc.ui.theme.scheme." .. mode)
  if not present_scheme then
    eve.reporter.error({
      from = "ghc.ui.theme",
      subject = "get_scheme",
      message = "Cannot find scheme",
      details = { mode = mode },
    })
    return nil
  end
  return scheme
end

---@param params                        ghc.types.ui.theme.ILoadPartialThemeParams
---@return nil
function M.load_partial_theme(params)
  local mode = params.mode ---@type fml.enums.theme.Mode
  local transparency = params.transparency ---@type boolean
  local integration = params.integration ---@type ghc.enum.ui.theme.HighlightIntegration
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(mode)
  if scheme == nil then
    return
  end

  local theme = fml.ui.Theme.new()

  local gen_hlgroup_map = hmr("ghc.ui.theme.integration." .. integration)
  local hlgroup_map = gen_hlgroup_map({ scheme = scheme, transparency = transparency })
  theme:registers(hlgroup_map)

  theme:apply({ scheme = scheme, nsnr = nsnr })
end

---@param params                        ghc.types.ui.theme.ILoadThemeParams
---@return nil
function M.load_theme(params)
  local mode = params.mode ---@type fml.enums.theme.Mode
  local transparency = params.transparency ---@type boolean
  local persistent = params.persistent ---@type boolean
  local filepath = params.filepath ---@type string|nil
  local nsnr = params.nsnr or 0 ---@type integer

  local scheme = M.get_scheme(mode)
  if scheme == nil then
    return
  end

  local theme = fml.ui.Theme.new()
  local gen_tabline_hlgroup_map = hmr("ghc.ui.theme.integration.tabline")
  local gen_winline_hlgroup_map = hmr("ghc.ui.theme.integration.winline")

  ---@type ghc.ui.theme.integration.tabline.hlgroups
  local tabline_hlgroup_map = gen_tabline_hlgroup_map({ scheme = scheme, transparency = transparency })
  local winline_hlgroup_map = gen_winline_hlgroup_map({ scheme = scheme, transparency = transparency })

  for _, integration in ipairs(M.integrations) do
    local gen_hlgroup_map = hmr("ghc.ui.theme.integration." .. integration)
    ---@return table<string, fml.types.ui.theme.IHlgroup>
    local hlgroup_map = gen_hlgroup_map({ scheme = scheme, transparency = transparency })

    if integration == "mini-icons" then
      ---@return table<string, fml.types.ui.theme.IHlgroup>
      local additional = {}

      for hlname, hlgroup in pairs(hlgroup_map) do
        ---! Integrated  with tabline
        additional[hlname .. "_tl_buf"] = { fg = hlgroup.fg, bg = tabline_hlgroup_map.f_tl_buf_item.bg }
        additional[hlname .. "_tl_buf_cur"] = { fg = hlgroup.fg, bg = tabline_hlgroup_map.f_tl_buf_item_cur.bg }

        ---! Integrated  with winline
        additional[hlname .. "_wl"] = { fg = hlgroup.fg, bg = winline_hlgroup_map.f_wl_bg.bg }
      end

      for hlname, hlgroup in pairs(additional) do
        hlgroup_map[hlname] = hlgroup
      end
    end

    theme:registers(hlgroup_map)
  end

  theme:apply({ scheme = scheme, nsnr = nsnr })
  if persistent and filepath ~= nil then
    vim.schedule(function()
      theme:compile({ nsnr = 0, scheme = scheme, filepath = filepath })
    end)
  end

  M.set_term_colors(scheme)
end

return M
