---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    ---syntax
    Boolean = { fg = c.dark_yellow },
    Character = { fg = c.red },
    Conditional = { fg = c.dark_red },
    Constant = { fg = c.red },
    Define = { fg = c.purple, sp = "none" },
    Delimiter = { fg = c.dark_red },
    Float = { fg = c.dark_yellow },
    Function = { fg = c.blue },
    Identifier = { fg = c.red, sp = "none" },
    Include = { fg = c.blue },
    Keyword = { fg = c.purple },
    Label = { fg = c.yellow },
    Number = { fg = c.dark_yellow },
    Operator = { fg = c.fg0, sp = "none" },
    PreProc = { fg = c.yellow },
    Repeat = { fg = c.yellow },
    Special = { fg = c.cyan },
    SpecialChar = { fg = c.dark_red },
    Statement = { fg = c.red },
    StorageClass = { fg = c.yellow },
    String = { fg = c.green },
    Structure = { fg = c.purple },
    Tag = { fg = c.yellow },
    Todo = { fg = c.yellow, bg = c.bg2 },
    Type = { fg = c.yellow, sp = "none" },
    Typedef = { fg = c.yellow },
    Variable = { fg = c.fg0 },

    ---spell
    healthSuccess = { bg = c.green, fg = c.black },
    SpellBad = { undercurl = true, sp = c.red },
    SpellCap = { undercurl = true, sp = c.blue },
    SpellLocal = { undercurl = true, sp = c.cyan },
    SpellRare = { undercurl = true, sp = c.purple },

    ---misc
    Added = { fg = c.green },
    Bold = { bold = true },
    Changed = { fg = c.yellow },
    ColorColumn = { bg = c.bg1 },
    Comment = { fg = c.grey },
    Conceal = { bg = "none" },
    Cursor = { fg = c.black, bg = c.white },
    CursorColumn = { bg = c.bg2, sp = "none" },
    CursorLine = { bg = c.bg3 },
    CursorLineNr = { fg = c.fg0 },
    Debug = { fg = c.red },
    DevIconDefault = { fg = c.red },
    Directory = { fg = c.blue },
    Error = { fg = c.black, bg = c.red },
    ErrorMsg = { fg = c.red, bg = c.bg1 },
    Exception = { fg = c.red },
    FloatTitle = { fg = c.fg0, bg = "none" },
    FloatBorder = { fg = c.dark_pink },
    FoldColumn = { fg = c.cyan, bg = c.bg2 },
    Folded = { fg = c.grey, bg = c.bg1 },
    IncSearch = { fg = c.bg2, bg = c.dark_yellow },
    Italic = { italic = true },
    LineNr = { fg = c.grey },
    Macro = { fg = c.red },
    MatchParen = { bg = c.grey, fg = c.fg0 },
    MatchWord = { bg = c.grey, fg = c.fg0 },
    ModeMsg = { fg = c.green },
    MoreMsg = { fg = c.green },
    NonText = { fg = c.fg3 },
    Normal = { fg = c.fg0, bg = c.bg1 },
    NormalFloat = { bg = c.dark_black },
    NvimInternalError = { fg = c.red },
    Pmenu = { bg = c.bg1 },
    PmenuSbar = { bg = c.bg1 },
    PmenuSel = { bg = c.bg_blue, fg = c.black },
    PmenuThumb = { bg = c.grey },
    Question = { fg = c.blue },
    QuickFixLine = { bg = c.bg2, sp = "none" },
    Removed = { fg = c.red },
    Search = { fg = c.dark_white, bg = c.yellow },
    SignColumn = { fg = c.grey, sp = "none" },
    SpecialKey = { fg = c.grey },
    Substitute = { fg = c.black, bg = c.yellow, sp = "none" },
    Title = { fg = c.blue, sp = "none" },
    TooLong = { fg = c.red },
    UnderLined = { underline = true },
    VertSplit = { fg = c.fg2 },
    VertSplitActive = { fg = c.dark_pink },
    Visual = { bg = c.grey },
    VisualNOS = { fg = c.red },
    WarningMsg = { fg = c.red },
    WildMenu = { fg = c.red, bg = c.yellow },
    WinSeparator = { fg = c.fg3 },
    WinSeparatorActive = { fg = c.dark_pink },
  }
end

return gen_hlgroup_map
