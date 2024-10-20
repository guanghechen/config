local template = [[
set -g @GHC_SL_COLOR_BG_APP_SYM       "{{green}}"
set -g @GHC_SL_COLOR_BG_APP_TEXT      "{{bg0}}"
set -g @GHC_SL_COLOR_BG_BAR           "{{bg0_h}}"
set -g @GHC_SL_COLOR_BG_DATE_SYM      "{{green}}"
set -g @GHC_SL_COLOR_BG_DATE_TEXT     "{{bg0_h}}"
set -g @GHC_SL_COLOR_BG_MESSAGE       "{{yellow}}"
set -g @GHC_SL_COLOR_BG_SESSION       "{{green}}"
set -g @GHC_SL_COLOR_BG_USER          "{{blue}}"
set -g @GHC_SL_COLOR_BG_WIN_NAME      "{{bg0_h}}"
set -g @GHC_SL_COLOR_BG_WIN_NAME_CUR  "{{bg0_h}}"
set -g @GHC_SL_COLOR_BG_WIN_NUM       "{{bg4}}"
set -g @GHC_SL_COLOR_BG_WIN_NUM_CUR   "{{orange}}"
set -g @GHC_SL_COLOR_BORDER           "{{grey}}"
set -g @GHC_SL_COLOR_BORDER_CUR       "{{orange}}"
set -g @GHC_SL_COLOR_FG_APP_SYM       "{{bg0_s}}"
set -g @GHC_SL_COLOR_FG_APP_TEXT      "{{fg}}"
set -g @GHC_SL_COLOR_FG_DATE_SYM      "{{bg0_s}}"
set -g @GHC_SL_COLOR_FG_DATE_TEXT     "{{fg}}"
set -g @GHC_SL_COLOR_FG_MESSAGE       "{{bg0_s}}"
set -g @GHC_SL_COLOR_FG_WIN_NAME      "{{fg}}"
set -g @GHC_SL_COLOR_FG_WIN_NAME_CUR  "{{orange}}"
set -g @GHC_SL_COLOR_FG_WIN_NUM       "{{bg0_s}}"
set -g @GHC_SL_COLOR_FG_WIN_NUM_CUR   "{{bg0_s}}"
set -g @GHC_SL_COLOR_SESSION          "{{bg0_s}}"
set -g @GHC_SL_COLOR_USER             "{{bg0_s}}"
]]

---@type t.ghc.ux.theme.IApp
local M = {
  get_filepaths = function(context)
    local app_home = eve.path.locate_app_config_home("tmux")
    if vim.fn.isdirectory(app_home) == 0 then
      return {}
    end

    ---@type string[]
    local filepaths = {
      eve.path.join(app_home, "theme/" .. context.theme .. ".tmux.conf"),
      eve.path.join(app_home, "theme/local.tmux.conf"),
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
