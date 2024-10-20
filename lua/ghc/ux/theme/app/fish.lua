local template = [[
set -gx color_bg0_h           '{{bg0_h}}'
set -gx color_bg0             '{{bg0}}'
set -gx color_bg0_s           '{{bg0_s}}'
set -gx color_bg1             '{{bg1}}'
set -gx color_bg2             '{{bg2}}'
set -gx color_bg3             '{{bg3}}'
set -gx color_bg4             '{{bg4}}'

set -gx color_fg              '{{fg}}'
set -gx color_fg0             '{{fg0}}'
set -gx color_fg1             '{{fg1}}'
set -gx color_fg2             '{{fg2}}'
set -gx color_fg3             '{{fg3}}'
set -gx color_fg4             '{{fg4}}'

set -gx color_red             '{{red}}'
set -gx color_green           '{{green}}'
set -gx color_yellow          '{{yellow}}'
set -gx color_blue            '{{blue}}'
set -gx color_purple          '{{purple}}'
set -gx color_aqua            '{{aqua}}'
set -gx color_orange          '{{orange}}'
set -gx color_grey            '{{grey}}'

set -gx color_neutral_red     '{{neutral_red}}'
set -gx color_neutral_green   '{{neutral_green}}'
set -gx color_neutral_yellow  '{{neutral_yellow}}'
set -gx color_neutral_blue    '{{neutral_blue}}'
set -gx color_neutral_purple  '{{neutral_purple}}'
set -gx color_neutral_aqua    '{{neutral_aqua}}'
set -gx color_neutral_orange  '{{neutral_orange}}'
set -gx color_neutral_grey    '{{neutral_grey}}'
]]

---@type t.ghc.ux.theme.IApp
local M = {
  get_filepaths = function(context)
    local app_home = eve.path.locate_app_config_home("fish")
    if vim.fn.isdirectory(app_home) == 0 then
      return {}
    end

    ---@type string[]
    local filepaths = {
      eve.path.join(app_home, "theme/" .. context.theme .. ".fish"),
      eve.path.join(app_home, "theme/local.fish"),
    }
    return filepaths
  end,
  gen_theme = function(context)
    local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette
    local text = template:gsub("{{(.-)}}", function(key)
      return c[key] or c.red
    end)
    return text
  end,
}

return M
