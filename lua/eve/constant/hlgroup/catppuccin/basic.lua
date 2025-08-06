---@class eve.constant.hlgroup.catppuccin.basic
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.catppuccin ---@type std.t.theme.CatppuccinPalette

  local bg = t and c.none or c.base ---@type string

  ---@type table<string, std.t.theme.IHlgroup>
  local hlgroup_map = {
    ---cursor
    Cursor = { fg = c.base, bg = c.rosewater },
    CursorColumn = { bg = c.mantle },
    CursorLine = { bg = c.surface0 },
    CursorLineNr = { fg = c.lavender, bold = true },
    vCursor = { link = "Cursor" },
    iCursor = { link = "Cursor" },
    lCursor = { link = "Cursor" },

    ---diagnostic
    Error = { fg = c.red, bold = true },
    Diagnostic_ERROR = { fg = c.red },
    Diagnostic_HINT = { fg = c.mauve },
    Diagnostic_INFO = { fg = c.green },
    Diagnostic_WARN = { fg = c.yellow },
    DiagnosticError = { fg = c.red },
    DiagnosticHint = { fg = c.mauve },
    DiagnosticInfo = { fg = c.green },
    DiagnosticWarn = { fg = c.yellow },
    DiagnosticFloatingError = { fg = c.red },
    DiagnosticFloatingHint = { fg = c.mauve },
    DiagnosticFloatingInfo = { fg = c.green },
    DiagnosticFloatingWarn = { fg = c.peach },
    DiagnosticUnderlineError = { undercurl = true, sp = c.red },
    DiagnosticUnderlineHint = { undercurl = true, sp = c.mauve },
    DiagnosticUnderlineInfo = { undercurl = true, sp = c.green },
    DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow },
    DiagnosticVirtualTextError = { fg = c.red },
    DiagnosticVirtualTextHint = { fg = c.mauve },
    DiagnosticVirtualTextInfo = { fg = c.green },
    DiagnosticVirtualTextWarn = { fg = c.yellow },
    DiagnosticOk = { fg = c.green },
    DiagnosticSignError = { fg = c.red },
    DiagnosticSignHint = { fg = c.mauve },
    DiagnosticSignInfo = { fg = c.green },
    DiagnosticSignWarn = { fg = c.yellow },

    ---diff
    DiffAddLeft = { bg = cs.mix(bg, c.red, 30) },
    DiffAddRight = { bg = cs.mix(bg, c.green, 30) },
    DiffDelLeft = { bg = cs.mix(bg, c.red, 30) },
    DiffDelRight = { bg = cs.mix(bg, c.red, 30) },
    DiffModLeft = { bg = cs.mix(bg, c.red, 30) },
    DiffModRight = { bg = cs.mix(bg, c.green, 30) },
    DiffWordLeft = { bg = cs.mix(bg, c.red, 60) },
    DiffWordRight = { bg = cs.mix(bg, c.green, 60) },

    DiffAdd = { link = "DiffAddRight" },
    DiffChange = { link = "DiffModRight" },
    DiffDelete = { link = "DiffDelRight" },
    DiffText = { link = "DiffWordRight" },
    DiffAdded = { link = "DiffAdd" },
    DiffRemoved = { link = "DiffDelete" },
    DiffChanged = { link = "DiffChange" },
    DiffFile = { fg = c.peach },
    DiffNewFile = { fg = c.yellow },
    DiffOldFile = { fg = c.peach },
    DiffLine = { fg = c.blue },
    DiffIndexLine = { link = "diffChanged" },

    ---lsp
    LspCodeLens = { fg = c.overlay1, bg = c.base, italic = true },
    LspInlayHint = { fg = c.subtext0, bg = c.base, italic = true },
    LspReferenceRead = { bold = true, underline = true, sp = c.mauve },
    LspReferenceText = { bold = true, underline = true, sp = c.mauve },
    LspReferenceWrite = { bold = true, underline = true, sp = c.mauve },
    LspSignatureActiveParameter = { italic = true, bold = true, underline = true, sp = c.pink },

    RenamerBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    RenamerTitle = { link = t and "ms_b_bg0" or "ms_b_none" },

    ---msg
    ErrorMsg = { fg = c.red, bold = true },
    ModeMsg = { fg = c.text, bold = true },
    MoreMsg = { fg = c.blue },
    MsgArea = { fg = c.peach, bg = c.surface0 },
    WarningMsg = { fg = c.yellow },

    ---spell
    healthSuccess = { fg = c.teal },
    SpellBad = { undercurl = true, sp = c.red },
    SpellCap = { undercurl = true, sp = c.yellow },
    SpellLocal = { undercurl = true, sp = c.blue },
    SpellRare = { undercurl = true, sp = c.green },

    ---special
    Delimiter = { fg = c.overlay2 },
    EndOfBuffer = { fg = c.surface1 },
    NonText = { fg = c.overlay0 },
    Whitespace = { fg = c.surface1 },

    ---syntax
    Boolean = { fg = c.peach },
    Builtin = { fg = c.peach },
    Character = { fg = c.teal },
    Conditional = { fg = c.mauve },
    Constant = { fg = c.peach },
    Define = { fg = c.pink },
    Float = { fg = c.peach },
    Function = { fg = c.blue },
    Identifier = { fg = c.flamingo },
    Include = { fg = c.mauve },
    Keyword = { fg = c.mauve },
    Label = { fg = c.sapphire },
    Macro = { fg = c.mauve },
    Member = { fg = c.text },
    Method = { fg = c.blue },
    Number = { fg = c.peach },
    Operator = { fg = c.sky },
    Parameter = { fg = c.maroon },
    PreCondit = { fg = c.pink },
    PreProc = { fg = c.pink },
    Repeat = { fg = c.mauve },
    Special = { fg = c.pink },
    SpecialChar = { fg = c.pink },
    Statement = { fg = c.mauve },
    StorageClass = { fg = c.yellow },
    String = { fg = c.green },
    Structure = { fg = c.yellow },
    Type = { fg = c.yellow },
    Typedef = { fg = c.yellow },
    Variable = { fg = c.text },

    ---tag
    Tag = { fg = c.lavender, bold = true },
    Todo = { fg = c.base, bg = c.flamingo, bold = true },
    Done = { fg = c.peach, bold = true, italic = true },

    ---misc
    Added = { fg = c.green },
    Bold = { bold = true },
    Changed = { fg = c.yellow },
    ColorColumn = { bg = c.surface0 },
    Comment = { fg = c.overlay2, italic = true },
    Conceal = { fg = c.overlay1 },
    CurSearch = { bg = c.red, fg = c.mantle },
    Debug = { fg = c.red },
    DevIconDefault = { fg = c.red },
    Directory = { fg = c.blue, bold = true },
    Exception = { fg = c.mauve },
    FloatActiveBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    FloatActiveTitle = { link = "ms_b_bg0" },
    FloatBorder = { fg = c.blue, bg = t and c.none or c.mantle },
    FloatNormal = { fg = c.text, bg = c.mantle },
    FloatTitle = { fg = c.subtext0, bg = c.mantle },
    FoldColumn = { fg = c.overlay0 },
    Folded = { fg = c.blue, bg = c.surface1 },
    IncSearch = { bg = cs.change_hex_lightness(c.sky, -70), fg = c.mantle },
    Italic = { italic = true },
    LineNr = { fg = c.surface1 },
    MatchParen = { fg = c.peach, bg = c.surface1, bold = true },
    MatchWord = { fg = c.text, bg = c.surface1 },
    Normal = { fg = c.text, bg = t and c.none or c.base },
    NormalFloat = { link = "FloatNormal" },
    NormalNC = { link = "Normal" },
    NvimInternalError = { fg = c.red },
    Pmenu = { fg = c.overlay2, bg = c.mantle },
    PmenuSbar = { bg = c.surface0 },
    PmenuSel = { bg = c.surface0, bold = true },
    PmenuThumb = { bg = c.overlay0 },
    Question = { fg = c.blue },
    QuickFixLine = { bg = c.surface1, bold = true },
    Removed = { fg = c.red },
    Search = { bg = cs.change_hex_lightness(c.sky, -30), fg = c.text },
    SignColumn = { fg = c.surface1 },
    SpecialKey = { fg = c.overlay0 },
    StatusLine = { fg = c.text, bg = t and c.none or c.mantle },
    StatusLineNC = { fg = c.surface1, bg = t and c.none or c.mantle },
    Substitute = { bg = c.surface1, fg = c.pink },
    TabLine = { bg = c.crust, fg = c.overlay0 },
    TabLineFill = { bg = t and c.none or c.mantle },
    TabLineSel = { link = "Normal" },
    Title = { fg = c.blue, bold = true },
    TooLong = { fg = c.red },
    UnderLined = { underline = true },
    VertSplit = { fg = t and c.surface1 or c.crust },
    VertSplitActive = { fg = c.peach },
    Visual = { bg = c.surface1, bold = true },
    VisualNOS = { bg = c.surface1, bold = true },
    WildMenu = { bg = c.overlay0 },
    WinBar = { fg = c.rosewater },
    WinBarNC = { link = "WinBar" },
    WinSeparator = { fg = t and c.surface1 or c.crust },
  }

  return hlgroup_map
end

return M
