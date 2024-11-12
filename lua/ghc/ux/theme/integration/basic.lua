local cs = require("eve.std.color")

---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.eve.collection.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local theme = context.scheme.theme ---@type t.eve.e.Theme
  local c = context.scheme.palette ---@type t.eve.collection.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_main = c.bg0 ---@type string

  ---@type table<string, t.eve.collection.theme.IHlgroup>
  local hlgroup_map = {
    ---cursor
    Cursor = { fg = c.bg1, bg = c.fg1 },
    CursorColumn = { bg = c.bg1 },
    CursorLine = { bg = c.bg1 },
    CursorLineNr = { fg = c.fg2, bg = c.bg1 },
    vCursor = { link = "Cursor" },
    iCursor = { link = "Cursor" },
    lCursor = { link = "Cursor" },

    ---diagnostic
    Error = { fg = c.bg0, bg = c.red },
    DiagnosticError = { fg = c.red },
    DiagnosticHint = { fg = c.purple },
    DiagnosticInfo = { fg = c.green },
    DiagnosticWarn = { fg = c.yellow },
    DiagnosticFloatingError = { fg = c.red },
    DiagnosticFloatingHint = { fg = c.purple },
    DiagnosticFloatingInfo = { fg = c.green },
    DiagnosticFloatingWarn = { fg = c.orange },
    DiagnosticUnderlineError = { undercurl = true, sp = c.red },
    DiagnosticUnderlineHint = { undercurl = true, sp = c.purple },
    DiagnosticUnderlineInfo = { undercurl = true, sp = c.green },
    DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow },
    DiagnosticVirtualTextError = { fg = c.red },
    DiagnosticVirtualTextHint = { fg = c.purple },
    DiagnosticVirtualTextInfo = { fg = c.green },
    DiagnosticVirtualTextWarn = { fg = c.yellow },
    DiagnosticOk = { fg = c.green, bg = t and "none" or c.bg1 },
    DiagnosticSignError = { fg = c.red, bg = t and "none" or c.bg1 },
    DiagnosticSignHint = { fg = c.purple, bg = t and "none" or c.bg1 },
    DiagnosticSignInfo = { fg = c.green, bg = t and "none" or c.bg1 },
    DiagnosticSignWarn = { fg = c.yellow, bg = t and "none" or c.bg1 },

    ---diff
    DiffAddLeft = { bg = cs.mix(bg_main, c.red, 30) },
    DiffAddRight = { bg = cs.mix(bg_main, c.aqua, 30) },
    DiffDelLeft = { bg = cs.mix(bg_main, c.red, 30) },
    DiffDelRight = { bg = cs.mix(bg_main, c.red, 30) },
    DiffModeLeft = { bg = cs.mix(bg_main, c.red, 30) },
    DiffModeRight = { bg = cs.mix(bg_main, c.aqua, 30) },
    DiffWordLeft = { bg = cs.mix(bg_main, c.neutral_red, 60) },
    DiffWordRight = { bg = cs.mix(bg_main, c.neutral_green, 60) },

    DiffAdd = { link = "DiffAddRight" },
    DiffChange = { link = "DiffModRight" },
    DiffDelete = { link = "DiffDelRight" },
    DiffText = { link = "DiffWordRight" },
    DiffAdded = { link = "DiffAdd" },
    DiffRemoved = { link = "DiffDelete" },
    DiffChanged = { link = "DiffChange" },
    DiffFile = { fg = c.orange },
    DiffNewFile = { fg = c.yellow },
    DiffOldFile = { fg = c.orange },
    DiffLine = { fg = c.blue },
    DiffIndexLine = { link = "diffChanged" },

    ---lsp
    LspInlayHint = { fg = c.fg4, bg = c.bg1 },
    LspReferenceRead = { bold = true, underline = true, sp = c.neutral_purple },
    LspReferenceText = { bold = true, underline = true, sp = c.neutral_purple },
    LspReferenceWrite = { bold = true, underline = true, sp = c.neutral_purple },
    LspSignatureActiveParameter = { fg = c.bg1, bg = c.green },
    RenamerBorder = { fg = c.red },
    RenamerTitle = { fg = c.bg0, bg = c.red },

    ---msg
    ErrorMsg = { fg = c.bg0, bg = c.red, bold = true },
    ModeMsg = { fg = c.yellow, bold = true },
    MoreMsg = { fg = c.yellow, bold = true },
    MsgArea = { fg = c.orange, bg = c.bg2 },
    WarningMsg = { fg = c.red, bold = true },

    ---spell
    healthSuccess = { fg = c.bg0, bg = c.green },
    SpellBad = { undercurl = true, sp = c.red },
    SpellCap = { undercurl = true, sp = c.blue },
    SpellLocal = { undercurl = true, sp = c.aqua },
    SpellRare = { undercurl = true, sp = c.purple },

    ---special
    Delimiter = { fg = c.orange },
    EndOfBuffer = { fg = c.bg2 },
    NonText = { fg = c.bg2 },
    Whitespace = { fg = c.bg2 },

    ---syntax
    Boolean = { fg = c.purple },
    Builtin = { fg = c.purple },
    Character = { fg = c.purple },
    Conditional = { fg = c.red },
    Constant = { fg = c.purple },
    Define = { fg = c.aqua },
    Float = { fg = c.purple },
    Function = { fg = c.yellow, bold = true },
    Identifier = { fg = c.blue },
    Include = { fg = c.aqua },
    Keyword = { fg = c.purple },
    Label = { fg = c.red },
    Macro = { fg = c.aqua },
    Member = { fg = c.aqua },
    Method = { fg = c.blue, bold = true },
    Number = { fg = c.purple },
    Operator = { fg = c.fg1 },
    Parameter = { fg = c.red },
    PreCondit = { fg = c.aqua },
    PreProc = { fg = c.yellow },
    Repeat = { fg = c.red },
    Special = { fg = c.aqua },
    SpecialChar = { fg = c.neutral_red },
    Statement = { fg = c.red },
    StorageClass = { fg = c.orange },
    String = { fg = c.yellow },
    Structure = { fg = c.aqua },
    Type = { fg = c.yellow },
    Typedef = { fg = c.yellow },
    Variable = { fg = c.fg2 },

    ---tag
    Tag = { fg = c.yellow },
    Todo = { fg = c.bg0, bg = c.yellow, bold = true, italic = true },
    Done = { fg = c.orange, bold = true, italic = true },

    ---misc
    Added = { fg = c.green },
    Bold = { bold = true },
    Changed = { fg = c.yellow },
    ColorColumn = { bg = c.bg1 },
    Comment = { fg = c.bg4, italic = true },
    Conceal = { fg = c.blue },
    CurSearch = { fg = c.bg0, bg = c.orange },
    Debug = { fg = c.red },
    DevIconDefault = { fg = c.red },
    Directory = { fg = c.blue, bold = true },
    Exception = { fg = c.red },
    FloatTitle = { fg = c.bg0, bg = c.red },
    FloatBorder = { fg = c.bg4 },
    FoldColumn = { fg = c.fg4, bg = t and "none" or c.bg1 },
    Folded = { fg = c.fg4, bg = c.bg1 },
    IncSearch = { fg = c.bg0, bg = c.orange },
    Italic = { italic = true },
    LineNr = { fg = c.bg4 },
    MatchParen = { bg = c.bg3, bold = true },
    MatchWord = { fg = c.fg1, bg = c.bg4 },
    Normal = { fg = c.fg1, bg = t and "none" or c.bg0 },
    NormalFloat = { fg = c.fg1, bg = t and "none" or c.bg1 },
    NormalNC = { link = "Normal" },
    NvimInternalError = { fg = c.red },
    Pmenu = { fg = c.fg1, bg = c.bg2 },
    PmenuSbar = { bg = c.bg2 },
    PmenuSel = { fg = c.bg2, bg = c.blue, bold = true },
    PmenuThumb = { bg = c.bg4 },
    Question = { fg = c.blue, bold = true },
    QuickFixLine = { fg = c.purple },
    Removed = { fg = c.red },
    Search = { fg = c.bg0, bg = c.yellow, reverse = false },
    SignColumn = { bg = "none" },
    SpecialKey = { fg = c.bg4 },
    StatusLine = { fg = c.bg2, bg = c.fg1, reverse = false },
    StatusLineNC = { fg = c.bg1, bg = c.bg4, reverse = false },
    Substitute = { fg = c.bg1, bg = c.yellow, sp = "none" },
    TabLine = { fg = c.bg4, bg = c.bg1, reverse = false },
    TabLineFill = { fg = c.bg4, bg = c.bg1, reverse = false },
    TabLineSel = { fg = c.green, bg = c.bg1, reverse = false },
    Title = { fg = c.blue, bold = true },
    TooLong = { fg = c.red },
    UnderLined = { fg = c.blue, underline = true },
    VertSplit = { fg = c.fg2 },
    VertSplitActive = { fg = c.neutral_orange },
    Visual = { bg = c.bg4, reverse = false },
    VisualNOS = { link = "Visual" },
    WildMenu = { fg = c.blue, bg = c.bg2, bold = true },
    WinBar = { fg = c.bg2, bg = c.bg2 },
    WinBarNC = { fg = c.fg3, bg = c.bg3 },
    WinSeparator = { fg = c.bg4, bg = t and "none" or c.bg0 },
    WinSeparatorActive = { fg = c.neutral_orange, bg = t and "none" or c.bg0 },
  }

  if theme == "gruvbox" then
  elseif theme == "one_half" then
    hlgroup_map.Comment.fg = cs.change_hex_lightness(c.bg4, 20)
    hlgroup_map.CursorLine.bg = c.bg2
    hlgroup_map.CursorLineNr.bg = c.bg2
    hlgroup_map.Identifier.fg = c.red
  end

  return hlgroup_map
end

return gen_hlgroup_map
