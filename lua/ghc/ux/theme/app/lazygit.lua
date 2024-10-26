local template = [[
git:
  autoFetch: false
  commit:
    signOff: false
  log:
    order: topo-order
    showGraph: "always"
    showWholeGraph: false
  paging:
    # cargo install git-delta
    colorArg: always
    useConfig: false
    pager: delta --paging=never
  parseEmoji: true
  skipHookPrefix: WIP
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
  border: "rounded"
  expandFocusedSidePanel: false
  mainPanelSplitMode: flexible
  mouseEvents: true
  nerdFontsVersion: "3"
  showBottomLine: true
  showCommandLog: true
  showFileTree: true
  showIcons: true
  showRandomTip: true
  splitDiff: auto
notARepository: skip
os:
  edit: "nvim"
  editAtLine: "nvim --line={{line}} {{filename}}"
  editAtLineAndWait: "nvim --block --line={{line}} {{filename}}"
  editInTerminal: true
  editPreset: "nvim-remote"
  openDirInEditor: "nvim {{dir}}"
promptToReturnFromSubprocess: true
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
      return c[key] or ("{{" .. key .. "}}")
    end)
    return text
  end,
}

return M
