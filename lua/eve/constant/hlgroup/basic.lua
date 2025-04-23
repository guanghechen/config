---@class eve.constant.hlgroup.basic
local M = {}

---@param context                       eve.t.theme.IContext
---@return table<string, eve.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = eve.std.color
  local theme = context.scheme.theme ---@type eve.e.Theme
  local c = context.scheme.palette ---@type eve.t.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_main = t and c.none or c.bg0 ---@type string

  ---@type table<string, eve.t.theme.IHlgroup>
  local hlgroup_map = {
    ---cursor
    Cursor = { fg = c.bg1, bg = c.pink },
    CursorColumn = { bg = c.bg1 },
    CursorLine = { bg = c.bg1 },
    CursorLineNr = { fg = c.fg2, bg = c.bg1, bold = true },
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
    DiagnosticOk = { fg = c.green },
    DiagnosticSignError = { fg = c.red },
    DiagnosticSignHint = { fg = c.purple },
    DiagnosticSignInfo = { fg = c.green },
    DiagnosticSignWarn = { fg = c.yellow },

    ---diff
    DiffAddLeft = { bg = c.diffDel or cs.mix(bg_main, c.red, 30) },
    DiffAddRight = { bg = c.diffAdd or cs.mix(bg_main, c.aqua, 30) },
    DiffDelLeft = { bg = c.diffDel or cs.mix(bg_main, c.red, 30) },
    DiffDelRight = { bg = c.diffDel or cs.mix(bg_main, c.red, 30) },
    DiffModLeft = { bg = c.diffDel or cs.mix(bg_main, c.red, 30) },
    DiffModRight = { bg = c.diffAdd or cs.mix(bg_main, c.aqua, 30) },
    DiffWordLeft = { bg = c.diffDelInline or cs.mix(bg_main, c.brightRed, 60) },
    DiffWordRight = { bg = c.diffAddInline or cs.mix(bg_main, c.brightGreen, 60) },

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
    LspReferenceRead = { bold = true, underline = true, sp = c.purple },
    LspReferenceText = { bold = true, underline = true, sp = c.purple },
    LspReferenceWrite = { bold = true, underline = true, sp = c.purple },
    LspSignatureActiveParameter = { fg = c.bg1, bg = c.green },
    RenamerBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    RenamerTitle = { link = t and "ms_b_bg0" or "ms_b_none" },

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
    ColorColumn = { bg = c.bg1 },
    Comment = { fg = c.grey, italic = true },
    Conceal = { fg = c.blue },
    CurSearch = { fg = c.bg0, bg = c.orange },
    Debug = { fg = c.red },
    DevIconDefault = { fg = c.red },
    Directory = { fg = c.blue, bold = true },
    Exception = { fg = c.red },
    FloatActiveBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    FloatActiveTitle = { link = t and "ms_b_bg0" or "ms_b_none" },
    FloatBorder = { fg = c.bg2, bg = t and c.bg0 or c.none, bold = true },
    FloatNormal = { fg = c.fg1, bg = c.bg1, blend = t and 50 or nil },
    FloatTitle = { link = t and "ms_b_bg0" or "ms_b_none" },
    FoldColumn = { fg = c.fg4, bg = t and c.none or c.bg1 },
    Folded = { fg = c.fg4 },
    IncSearch = { fg = c.bg0, bg = c.orange },
    Italic = { italic = true },
    LineNr = { fg = c.bg4 },
    MatchParen = { bg = c.bg3, bold = true },
    MatchWord = { fg = c.fg1, bg = c.bg4 },
    Normal = { fg = c.fg1, bg = t and c.none or c.bg0 },
    NormalFloat = { link = "FloatNormal" },
    NormalNC = { link = "Normal" },
    NvimInternalError = { fg = c.red },
    Pmenu = { fg = c.fg1, bg = c.bg2 },
    PmenuSbar = { bg = c.bg2 },
    PmenuSel = { fg = c.fg1, bg = cs.mix(c.bg0, c.blue, 70), bold = true },
    PmenuThumb = { bg = cs.mix(c.bg0, c.blue, 60) },
    Question = { fg = c.blue, bold = true },
    QuickFixLine = { fg = c.purple },
    Removed = { fg = c.red },
    Search = { fg = c.bg0, bg = c.yellow, reverse = false },
    SignColumn = { bg = c.none },
    SpecialKey = { fg = c.bg4 },
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
    WinBar = { fg = c.blue, bg = c.none },
    WinBarNC = { fg = c.blue, bg = c.none },
    WinSeparator = { fg = c.bg2, bg = c.none },
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

return M
