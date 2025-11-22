---@class eve.constant.hlgroup.gruvbox.basic
local M = {}

---@param context                       std.t.theme.IContext
---@return eve.constant.hlgroup.common.modes_color_map
function M.gen_modes_color_map(context)
  local c = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette
  local mc = {
    command = c.brightBlue,
    confirm = c.brightAqua,
    insert = c.brightPurple,
    normal = c.brightAqua,
    nterminal = c.yellow,
    replace = c.brightYellow,
    select = c.brightOrange,
    terminal = c.brightBlue,
    visual = c.brightOrange,
  }
  return mc
end

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local c = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette
  local t = context.transparency ---@type boolean
  local bg = t and c.none or c.bg0 ---@type string

  local function mix_bg(color, ratio)
    return cs.mix(bg, color, ratio or 20)
  end

  ---@type table<string, std.t.theme.IHlgroup>
  local hlgroup_map = {
    ---Completion
    ComplHint = { fg = c.bg4, italic = true },
    ComplHintMore = { fg = c.bg3, italic = true },

    ---cursor
    Cursor = { fg = c.bg1, bg = c.pink },
    CursorColumn = { bg = c.bg1, blend = t and 50 or 0 },
    CursorLine = { bg = c.bg1, blend = t and 50 or 0 },
    CursorLineNr = { fg = c.fg2, bg = c.bg1, bold = true, blend = t and 50 or 0 },
    vCursor = { link = "Cursor" },
    iCursor = { link = "Cursor" },
    lCursor = { link = "Cursor" },

    ---diagnostic
    Error = { fg = c.red, bold = true },
    Diagnostic_ERROR = { fg = c.red },
    Diagnostic_HINT = { fg = c.purple },
    Diagnostic_INFO = { fg = c.green },
    Diagnostic_WARN = { fg = c.yellow },
    DiagnosticError = { fg = c.red },
    DiagnosticHint = { fg = c.purple },
    DiagnosticInfo = { fg = c.green },
    DiagnosticWarn = { fg = c.yellow },
    DiagnosticFloatingError = { fg = c.red },
    DiagnosticFloatingHint = { fg = c.purple },
    DiagnosticFloatingInfo = { fg = c.green },
    DiagnosticFloatingWarn = { fg = c.yellow },
    DiagnosticFloatingOk = { fg = c.green },
    DiagnosticUnderlineError = { undercurl = true, sp = c.red },
    DiagnosticUnderlineHint = { undercurl = true, sp = c.purple },
    DiagnosticUnderlineInfo = { undercurl = true, sp = c.green },
    DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow },
    DiagnosticVirtualTextError = { fg = c.red },
    DiagnosticVirtualTextHint = { fg = c.purple },
    DiagnosticVirtualTextInfo = { fg = c.green },
    DiagnosticVirtualTextWarn = { fg = c.yellow },
    DiagnosticVirtualTextOk = { fg = c.green },
    DiagnosticOk = { fg = c.green },
    DiagnosticSignError = { fg = c.red },
    DiagnosticSignHint = { fg = c.purple },
    DiagnosticSignInfo = { fg = c.green },
    DiagnosticSignWarn = { fg = c.yellow },
    DiagnosticSignOk = { fg = c.green },

    ---diff
    DiffAddLeft = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffAddRight = { bg = c.diffAdd or cs.mix(bg, c.aqua, 30) },
    DiffDelLeft = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffDelRight = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffModLeft = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffModRight = { bg = c.diffAdd or cs.mix(bg, c.aqua, 30) },
    DiffWordLeft = { bg = c.diffDelInline or cs.mix(bg, c.brightRed, 60) },
    DiffWordRight = { bg = c.diffAddInline or cs.mix(bg, c.brightGreen, 60) },

    DiffAdd = { bg = mix_bg(c.green, 25) },
    DiffChange = { bg = mix_bg(c.yellow, 25) },
    DiffDelete = { bg = mix_bg(c.red, 25) },
    DiffText = { bg = mix_bg(c.green, 45) },
    DiffAdded = { link = "DiffAdd" },
    DiffRemoved = { link = "DiffDelete" },
    DiffChanged = { link = "DiffChange" },
    DiffFile = { fg = c.orange },
    DiffNewFile = { fg = c.yellow },
    DiffOldFile = { fg = c.orange },
    DiffLine = { fg = c.blue },
    DiffIndexLine = { link = "diffChanged" },

    ---lsp
    LspCodeLens = { fg = c.bg4, italic = true },
    LspInlayHint = { fg = c.bg4, bg = t and c.none or c.bg1, italic = true },
    LspReferenceRead = { fg = c.yellow, bold = true },
    LspReferenceText = { fg = c.yellow, bold = true },
    LspReferenceWrite = { fg = c.orange, bold = true },
    LspSignatureActiveParameter = { link = "Search" },

    RenamerBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    RenamerTitle = { link = t and "ms_b_bg0" or "ms_b_none" },

    ---msg
    ErrorMsg = { fg = c.red, bold = true },
    ModeMsg = { fg = c.yellow, bold = true },
    MoreMsg = { fg = c.yellow, bold = true },
    MsgArea = { link = "Normal" },
    WarningMsg = { fg = c.red, bold = true },

    ---spell
    healthError = { fg = c.red },
    healthSuccess = { fg = c.green },
    healthWarning = { fg = c.yellow },
    SpellBad = { undercurl = true, sp = c.red },
    SpellCap = { undercurl = true, sp = c.blue },
    SpellLocal = { undercurl = true, sp = c.aqua },
    SpellRare = { undercurl = true, sp = c.purple },

    ---special
    Delimiter = { fg = c.aqua },
    EndOfBuffer = { fg = c.bg2 },
    NonText = { fg = cs.mix(bg, c.bg2, 45), italic = true },
    Whitespace = { fg = c.bg4 },

    ---syntax
    Boolean = { fg = c.brightPurple },
    Builtin = { fg = c.brightPurple },
    Character = { fg = c.brightPurple },
    Conditional = { fg = c.brightRed },
    Constant = { fg = c.brightPurple },
    Define = { fg = c.brightAqua },
    Float = { fg = c.brightPurple },
    Function = { fg = c.brightAqua },
    Identifier = { fg = c.brightBlue },
    Include = { fg = c.brightRed },
    Keyword = { fg = c.brightRed, bold = true },
    Label = { fg = c.brightRed },
    Macro = { fg = c.brightAqua },
    Member = { fg = c.brightBlue },
    Method = { fg = c.brightBlue },
    Number = { fg = c.brightPurple },
    Operator = { fg = c.brightRed },
    Parameter = { fg = c.brightBlue },
    PreCondit = { fg = c.brightAqua },
    PreProc = { fg = c.brightYellow },
    Repeat = { fg = c.brightRed },
    Special = { fg = c.brightAqua },
    SpecialChar = { fg = c.brightRed },
    Statement = { fg = c.brightRed },
    StorageClass = { fg = c.brightOrange },
    String = { fg = c.brightGreen },
    Structure = { fg = c.brightAqua },
    Type = { fg = c.brightYellow },
    Typedef = { fg = c.brightYellow },
    Variable = { fg = c.fg2 },

    ---tag
    Tag = { fg = c.yellow },
    Todo = { fg = c.bg0, bg = c.yellow, bold = true, italic = true },
    Done = { fg = c.orange, bold = true, italic = true },

    ---misc
    Added = { fg = c.green },
    Bold = { bold = true },
    Changed = { fg = c.yellow },
    ColorColumn = { fg = c.fg2, bg = cs.mix(c.bg0, c.pink, 20) },
    Comment = { fg = c.grey, italic = true },
    Conceal = { fg = c.blue },
    CurSearch = { fg = c.bg0, bg = c.orange },
    Debug = { fg = c.red },
    DevIconDefault = { fg = c.red },
    Directory = { fg = c.brightBlue, bold = true },
    Exception = { fg = c.red },
    FloatActiveBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    FloatActiveTitle = { link = "ms_b_bg0" },
    FloatBorder = { fg = c.bg2, bg = c.bg0, bold = true, blend = t and 50 or 0 },
    FloatNormal = { fg = c.fg1, bg = c.bg0, blend = t and 50 or 0 },
    FloatTitle = { link = "ms_b_bg0" },
    FoldColumn = { fg = c.fg4, bg = c.none },
    Folded = { fg = c.fg4 },
    IncSearch = { fg = c.bg0, bg = c.orange },
    Italic = { italic = true },
    LineNr = { fg = c.bg4 },
    MatchParen = { bg = c.bg3, bold = true },
    MatchWord = { fg = c.fg1, bg = c.bg4 },
    Normal = { fg = c.fg1, bg = c.bg0, blend = t and 50 or 0 },
    NormalFloat = { link = "FloatNormal" },
    NormalNC = { fg = c.fg1, bg = c.bg1, blend = t and 50 or 0 },
    NvimInternalError = { fg = c.red },
    Pmenu = { fg = c.fg1, bg = c.bg2 },
    PmenuSbar = { bg = c.bg2 },
    PmenuSel = { fg = c.fg1, bg = cs.mix(c.bg0, c.blue, 70), bold = true, italic = true },
    PmenuThumb = { bg = cs.mix(c.bg0, c.blue, 60) },
    Question = { fg = c.blue, bold = true },
    QuickFixLine = { fg = c.purple },
    Removed = { fg = c.red },
    Search = { fg = c.bg0, bg = c.yellow, reverse = false },
    SignColumn = { bg = c.none },
    SpecialKey = { link = "NonText" },
    StatusColumnMark = { link = "DiagnosticHint", default = true },
    StatusLine = { fg = c.fg2, bg = c.none, reverse = false },
    StatusLineNC = { link = "StatusLine" },
    Substitute = { fg = c.bg1, bg = c.yellow, sp = c.none },
    TabLine = { fg = c.fg2, bg = c.none, reverse = false },
    TabLineFill = { link = "TabLine" },
    TabLineSel = { link = "TabLine" },
    Title = { link = t and "ms_b_none" or "ms_b_bg0" },
    TooLong = { fg = c.red },
    UnderLined = { fg = c.blue, underline = true },
    VertSplit = { fg = c.bg2 },
    VertSplitActive = { fg = c.brightOrange },
    Visual = { bg = cs.mix(c.bg0, c.purple, 65), blend = 0, reverse = false },
    VisualNOS = { link = "Visual" },
    WildMenu = { fg = c.blue, bg = c.bg2, bold = true },
    WinBar = { fg = c.blue, bg = c.bg0 },
    WinBarNC = { fg = c.blue, bg = c.bg1 },
    WinSeparator = { fg = c.bg2, bg = c.none },
  }

  return hlgroup_map
end

return M
