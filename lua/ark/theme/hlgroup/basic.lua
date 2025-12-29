---@class ark.theme.hlgroup.basic
local M = {}

---@param context                       ark.t.theme.IContext
---@return ark.theme.hlgroup.common.modes_color_map
function M.gen_modes_color_map(context)
  local md = string.format("ark.theme.hlgroup.%s.basic", context.scheme.theme) ---@type string
  local ok, mod = pcall(require, md)
  if ok and mod then
    return mod.gen_modes_color_map(context)
  end

  return M.default_gen_modes_color_map(context)
end

---@param context                       ark.t.theme.IContext
---@return table<string, ark.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local md = string.format("ark.theme.hlgroup.%s.basic", context.scheme.theme) ---@type string
  local ok, mod = pcall(require, md)
  if ok and mod then
    return mod.gen_hlgroup_map(context)
  end

  return M.default_gen_hlgroup_map(context)
end

---@param context                       ark.t.theme.IContext
---@return ark.theme.hlgroup.common.modes_color_map
function M.default_gen_modes_color_map(context)
  local c = context.scheme.palette.unified ---@type ark.t.theme.IUnifiedPalette
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

---@param context                       ark.t.theme.IContext
---@return table<string, ark.t.theme.IHlgroup>
function M.default_gen_hlgroup_map(context)
  local cs = stl.color
  local c = context.scheme.palette.unified ---@type ark.t.theme.IUnifiedPalette
  local t = context.transparency ---@type boolean
  local bg = t and c.none or c.bg0 ---@type string

  ---@type table<string, ark.t.theme.IHlgroup>
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
    DiagnosticFloatingOk = { fg = c.green },
    DiagnosticFloatingWarn = { fg = c.orange },
    DiagnosticUnderlineError = { undercurl = true, sp = c.red },
    DiagnosticUnderlineHint = { undercurl = true, sp = c.purple },
    DiagnosticUnderlineInfo = { undercurl = true, sp = c.green },
    DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow },
    DiagnosticVirtualTextError = { fg = c.red },
    DiagnosticVirtualTextHint = { fg = c.purple },
    DiagnosticVirtualTextInfo = { fg = c.green },
    DiagnosticVirtualTextOk = { fg = c.green },
    DiagnosticVirtualTextWarn = { fg = c.yellow },
    DiagnosticVirtualLinesError = { fg = c.red, bg = t and c.none or cs.mix(c.bg0, c.red, 12), italic = true },
    DiagnosticVirtualLinesHint = { fg = c.purple, bg = t and c.none or cs.mix(c.bg0, c.purple, 12), italic = true },
    DiagnosticVirtualLinesInfo = { fg = c.green, bg = t and c.none or cs.mix(c.bg0, c.green, 12), italic = true },
    DiagnosticVirtualLinesWarn = { fg = c.yellow, bg = t and c.none or cs.mix(c.bg0, c.yellow, 12), italic = true },
    DiagnosticVirtualLinesOk = { fg = c.green, bg = t and c.none or cs.mix(c.bg0, c.green, 12), italic = true },
    DiagnosticOk = { fg = c.green },
    DiagnosticSignError = { fg = c.red },
    DiagnosticSignHint = { fg = c.purple },
    DiagnosticSignInfo = { fg = c.green },
    DiagnosticSignOk = { fg = c.green },
    DiagnosticSignWarn = { fg = c.yellow },

    ---diff
    DiffAddLeft = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffAddRight = { bg = c.diffAdd or cs.mix(bg, c.aqua, 30) },
    DiffDelLeft = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffDelRight = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffModLeft = { bg = c.diffDel or cs.mix(bg, c.red, 30) },
    DiffModRight = { bg = c.diffAdd or cs.mix(bg, c.aqua, 30) },
    DiffWordLeft = { bg = c.diffDelInline or cs.mix(bg, c.brightRed, 60) },
    DiffWordRight = { bg = c.diffAddInline or cs.mix(bg, c.brightGreen, 60) },

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
    LspCodeLens = { fg = c.bg4, bg = c.none, italic = true },
    LspInlayHint = { fg = c.fg4, bg = c.none, italic = true },
    LspReferenceRead = { bold = true, underline = true, sp = c.purple },
    LspReferenceText = { bold = true, underline = true, sp = c.purple },
    LspReferenceWrite = { bold = true, underline = true, sp = c.purple },
    LspSignatureActiveParameter = { italic = true, bold = true, underline = true, sp = c.pink },

    RenamerBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    RenamerTitle = { link = t and "ms_b_bg0" or "ms_b_none" },

    ---msg
    ErrorMsg = { fg = c.red, bold = true },
    ModeMsg = { fg = c.yellow, bold = true },
    MoreMsg = { fg = c.yellow, bold = true },
    MsgArea = { fg = c.orange, bg = c.bg2 },
    WarningMsg = { fg = c.red, bold = true },

    ---spell
    healthError = { fg = c.red },
    healthSuccess = { fg = c.bg0, bg = c.green },
    healthWarning = { fg = c.yellow },
    SpellBad = { undercurl = true, sp = c.red },
    SpellCap = { undercurl = true, sp = c.blue },
    SpellLocal = { undercurl = true, sp = c.aqua },
    SpellRare = { undercurl = true, sp = c.purple },

    ---special
    Delimiter = { fg = c.orange },
    EndOfBuffer = { fg = c.bg2 },
    NonText = { fg = cs.mix(bg, c.bg2, 45), italic = true },
    Whitespace = { fg = c.bg4 },

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
    Include = { fg = c.purple },
    Keyword = { fg = c.purple },
    Label = { fg = c.red },
    Macro = { fg = c.aqua },
    Member = { fg = c.aqua },
    Method = { fg = c.blue, bold = true },
    Number = { fg = c.purple },
    Operator = { fg = c.fg1 },
    Parameter = { fg = c.blue },
    PreCondit = { fg = c.aqua },
    PreProc = { fg = c.yellow },
    Repeat = { fg = c.red },
    Special = { fg = c.aqua },
    SpecialChar = { fg = c.brightRed },
    Statement = { fg = c.red },
    StorageClass = { fg = c.orange },
    String = { fg = c.green },
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
    ColorColumn = { fg = c.fg2, bg = cs.mix(c.bg0, c.pink, 20) },
    Comment = { fg = c.grey, italic = true },
    Conceal = { fg = c.blue },
    CurSearch = { fg = c.bg0, bg = c.orange },
    Debug = { fg = c.red },
    DevIconDefault = { fg = c.red },
    Directory = { fg = c.blue, bold = true },
    Exception = { fg = c.red },
    FloatActiveBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    FloatActiveTitle = { link = "ms_b_bg0" },
    FloatBorder = { fg = c.bg2, bg = t and c.bg0 or c.none, bold = true, blend = t and 50 or 0 },
    FloatNormal = { fg = c.fg1, bg = t and c.bg0 or c.none, blend = t and 50 or 0 },
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
    SpecialKey = { fg = c.fg4 },
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
