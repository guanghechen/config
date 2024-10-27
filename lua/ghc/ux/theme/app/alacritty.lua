local template = [[
# Default colors
[colors.primary]
# hard contrast background = "{{bg0_h}}"
background = "{{bg0}}"
# soft contrast background = "{{bg0_s}}"
foreground = "{{fg}}"

# Normal colors
[colors.normal]
black   = "{{bg0}}"
red     = "{{neutral_red}}"
green   = "{{neutral_green}}"
yellow  = "{{neutral_yellow}}"
blue    = "{{neutral_blue}}"
magenta = "{{neutral_purple}}"
cyan    = "{{neutral_aqua}}"
white   = "{{fg4}}"

# Bright colors
[colors.bright]
black   = "{{fg4}}"
red     = "{{red}}"
green   = "{{green}}"
yellow  = "{{yellow}}"
blue    = "{{blue}}"
magenta = "{{purple}}"
cyan    = "{{aqua}}"
white   = "{{fg}}"
]]

local app_home = eve.path.locate_app_config_home("alacritty")

---@type t.ghc.ux.theme.IApp
local M = {
  get_filepaths = function(context)
    if vim.fn.isdirectory(app_home) == 0 then
      return {}
    end

    ---@type string[]
    local filepaths = {
      eve.path.join(app_home, "theme/" .. context.theme .. ".toml"),
      eve.path.join(app_home, "local/theme.toml"),
    }
    return filepaths
  end,
  gen_theme = function(context)
    local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette
    local text = template:gsub("{{(.-)}}", function(key)
      return c[key] or ("{{" .. key .. "}}")
    end)
    return text
  end,
  after_written = function()
    local main_config_path = eve.path.join(app_home, "alacritty.toml") ---@type string
    eve.fs.touch(main_config_path)
  end,
}

return M
