---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    ---syntax
    Boolean = { fg = c.base09 },
    Character = { fg = c.base08 },
    Conditional = { fg = c.base0E },
    Constant = { fg = c.base08 },
    Define = { fg = c.base0E, sp = "none" },
    Delimiter = { fg = c.base0F },
    Float = { fg = c.base09 },
    Variable = { fg = c.base05 },
    Function = { fg = c.base0D },
    Identifier = { fg = c.base08, sp = "none" },
    Include = { fg = c.base0D },
    Keyword = { fg = c.base0E },
    Label = { fg = c.base0A },
    Number = { fg = c.base09 },
    Operator = { fg = c.base05, sp = "none" },
    PreProc = { fg = c.base0A },
    Repeat = { fg = c.base0A },
    Special = { fg = c.base0C },
    SpecialChar = { fg = c.base0F },
    Statement = { fg = c.base08 },
    StorageClass = { fg = c.base0A },
    String = { fg = c.base0B },
    Structure = { fg = c.base0E },
    Tag = { fg = c.base0A },
    Todo = { fg = c.base0A, bg = c.base01 },
    Type = { fg = c.base0A, sp = "none" },
    Typedef = { fg = c.base0A },

    ---misc
    Added = { fg = c.green },
    Bold = { bold = true },
    Changed = { fg = c.yellow },
    ColorColumn = { bg = c.black2 },
    Comment = { fg = c.grey_fg },
    Conceal = { bg = "none" },
    Cursor = { fg = c.base00, bg = c.base05 },
    CursorColumn = { bg = c.base01, sp = "none" },
    CursorLine = { bg = c.one_bg2 },
    CursorLineNr = { fg = c.white },
    Debug = { fg = c.base08 },
    DevIconDefault = { fg = c.red },
    Directory = { fg = c.base0D },
    Error = { fg = c.base00, bg = c.base08 },
    ErrorMsg = { fg = c.base08, bg = c.base00 },
    Exception = { fg = c.base08 },
    FloatBorder = { fg = c.blue },
    Folded = { fg = c.light_grey, bg = c.black2 },
    FoldColumn = { fg = c.base0C, bg = c.base01 },
    IncSearch = { fg = c.base01, bg = c.base09 },
    Italic = { italic = true },
    LineNr = { fg = c.grey },
    Macro = { fg = c.base08 },
    MatchParen = { link = "MatchWord" },
    MatchWord = { bg = c.grey, fg = c.white },
    ModeMsg = { fg = c.base0B },
    MoreMsg = { fg = c.base0B },
    NonText = { fg = c.base03 },
    Normal = { fg = c.base05, bg = c.base00 },
    NormalFloat = { bg = c.darker_black },
    NvimInternalError = { fg = c.red },
    Pmenu = { bg = c.one_bg },
    PmenuSbar = { bg = c.one_bg },
    PmenuSel = { bg = c.pmenu_bg, fg = c.black },
    Question = { fg = c.base0D },
    QuickFixLine = { bg = c.base01, sp = "none" },
    PmenuThumb = { bg = c.grey },
    Removed = { fg = c.red },
    Search = { fg = c.base01, bg = c.base0A },
    SignColumn = { fg = c.base03, sp = "none" },
    SpecialKey = { fg = c.base03 },
    Substitute = { fg = c.base01, bg = c.base0A, sp = "none" },
    Title = { fg = c.base0D, sp = "none" },
    TooLong = { fg = c.base08 },
    UnderLined = { underline = true },
    Visual = { bg = c.light_grey },
    VisualNOS = { fg = c.base08 },
    WarningMsg = { fg = c.base08 },
    WinSeparator = { fg = c.line },
    WildMenu = { fg = c.base08, bg = c.base0A },
  }
end

return gen_hlgroup
