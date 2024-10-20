local template = [[
gui:
  authorColors:
    guanghechen: "{{blue}}"
    "*": "{{fg2}}"
  branchColors:
    main: "{{blue}}"
  theme:
    defaultFgColor:
      - "{{fg2}}"
    activeBorderColor:
      - "{{orange}}"
      - bold
    inactiveBorderColor:
      - "{{fg4}}"
    optionsTextColor:
      -  "{{orange}}"
    selectedLineBgColor:
      - "{{bg2}}"
    cherryPickedCommitFgColor:
      - "{{blue}}"
    cherryPickedCommitBgColor:
      - "{{aqua}}"
    markedBaseCommitFgColor:
      - "{{green}}"
    markedBaseCommitBgColor:
      - "{{neutral_purple}}"
    searchingActiveBorderColor:
      - "{{blue}}"
    unstagedChangesColor:
      - "{{red}}"
]]

---@type t.ghc.ux.theme.IApp
local M = {
  get_filepaths = function(context)
    local app_home = eve.path.locate_app_config_home("lazygit")
    if vim.fn.isdirectory(app_home) == 0 then
      return {}
    end

    ---@type string[]
    local filepaths = {
      eve.path.join(app_home, "theme/" .. context.theme .. ".yaml"),
      eve.path.join(app_home, "local/theme.yaml"),
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
