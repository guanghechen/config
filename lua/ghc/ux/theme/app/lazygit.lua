local template = [[
gui:
  authorColors:
    guanghechen: "{{lavender}}"
  branchColors:
    main: "{{blue}}"
  theme:
    activeBorderColor:
      - bold
      - "{{orange}}"
    inactiveBorderColor:
      - default
      - "{{grey}}"
    searchingActiveBorderColor:
      - default
      - "{{blue}}"
    optionsTextColor:
      - default
      -  "{{orange}}"
    selectedLineBgColor:
      - default
      - "{{bg2}}"
    cherryPickedCommitFgColor:
      - default
      - "{{blue}}"
    cherryPickedCommitBgColor:
      - default
      - "{{aqua}}"
    markedBaseCommitFgColor:
      - default
      - "{{green}}"
    markedBaseCommitBgColor:
      - default
      - "{{neutral_purple}}"
    unstagedChangesColor:
      - default
      - "{{red}}"
    defaultFgColor:
      - default
      - "{{fg}}"
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
      eve.path.join(app_home, "theme/local.yaml"),
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
