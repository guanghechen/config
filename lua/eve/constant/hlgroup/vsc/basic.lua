---@class eve.constant.hlgroup.vsc.basic
local M = {}

---@param context                       std.t.theme.IContext
---@return eve.constant.hlgroup.common.modes_color_map
function M.gen_modes_color_map(context)
  local palette = context.scheme.palette ---@type std.t.theme.IPalette
  local c = palette.vsc ---@type std.t.theme.IVscPalette|nil
  local u = palette.unified ---@type std.t.theme.UnifiedPalette
  if not c then
    return require("eve.constant.hlgroup.basic").default_gen_modes_color_map(context)
  end

  local accent_blue = c.accentBlue or u.brightBlue
  local accent_aqua = c.accentAqua or u.brightAqua
  local accent_purple = c.accentPurple or u.brightPurple
  local accent_yellow = c.accentYellow or u.yellow
  local accent_orange = c.accentOrange or u.brightOrange

  return {
    command = accent_blue,
    confirm = accent_aqua,
    insert = accent_purple,
    normal = accent_aqua,
    nterminal = accent_yellow,
    replace = c.brightYellow or accent_yellow,
    select = accent_orange,
    terminal = accent_blue,
    visual = accent_orange,
  }
end

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local palette = context.scheme.palette ---@type std.t.theme.IPalette
  local c = palette.vsc ---@type std.t.theme.IVscPalette|nil
  if not c then
    return require("eve.constant.hlgroup.basic").default_gen_hlgroup_map(context)
  end

  local u = palette.unified ---@type std.t.theme.UnifiedPalette
  local t = context.transparency ---@type boolean

  local bg = t and c.none or (c.editor_background or c.base or u.bg0)
  local bg_alt = t and c.none or (c.panel_background or c.sideBar_background or c.surface or u.bg1)
  local bg_popup =
    t and c.none
    or (c.dropdown_background or c.quickInput_background or c.menu_background or c.editorWidget_background or c.overlay or u.bg2)
  local border = c.focusBorder or c.editorGroup_border or c.widget_border or c.border or u.bg3
  local border_strong = c.panel_border or c.borderStrong or border
  local popup_border = c.dropdown_border or c.menu_border or border
  local fg = c.editor_foreground or c.text or c.foreground or u.fg1
  local fg_dim = c.descriptionForeground or c.textDim or c.subtle or u.fg3
  local fg_muted = c.muted or c.textMuted or c.textSeparator_foreground or u.fg4
  local line_nr_fg = c.editorLineNumber_foreground or fg_muted
  local line_nr_active_fg = c.editorLineNumber_activeForeground or c.tab_activeForeground or fg

  local accent_blue = c.accentBlue or u.brightBlue
  local accent_green = c.accentGreen or u.brightGreen
  local accent_yellow = c.accentYellow or u.brightYellow
  local accent_red = c.accentRed or u.brightRed
  local accent_purple = c.accentPurple or u.brightPurple
  local accent_orange = c.accentOrange or u.brightOrange
  local accent_aqua = c.accentAqua or u.brightAqua

  local bright_blue = c.brightBlue or accent_blue
  local bright_aqua = c.brightAqua or accent_aqua
  local bright_green = c.brightGreen or accent_green
  local bright_yellow = c.brightYellow or accent_yellow
  local bright_red = c.brightRed or accent_red
  local bright_orange = c.brightOrange or accent_orange
  local diff_add = c.editorGutter_addedBackground or accent_green
  local diff_change = c.editorGutter_modifiedBackground or accent_blue
  local diff_delete = c.editorGutter_deletedBackground or accent_red
  local indent_guide = c.editorIndentGuide_background1 or border
  local indent_guide_active = c.editorIndentGuide_activeBackground1 or accent_blue

  local selection =
    c.selection
    or c.editor_inactiveSelectionBackground
    or c.editor_selectionHighlightBackground
    or cs.mix(bg, accent_blue, 18)
  local cursorline_bg =
    c.editor_selectionHighlightBackground
    or c.editor_inactiveSelectionBackground
    or c.list_dropBackground
    or (bg == c.none and selection)
    or cs.mix(bg, selection, 16)
  local cursorline_nr_fg = line_nr_active_fg
  local menu_fg = c.menu_foreground or c.dropdown_foreground or fg
  local popup_fg = c.dropdown_foreground or c.quickInput_foreground or fg
  local menu_bg = t and c.none or (c.menu_background or c.dropdown_background or bg_popup)
  local menu_sel_bg = c.menu_selectionBackground or selection
  local menu_sbar_bg = c.menu_separatorBackground or cs.mix(menu_bg, border, 20)
  local menu_thumb_bg = c.menu_border or cs.mix(menu_bg, border_strong, 45)
  local status_fg = c.statusBar_foreground or fg
  local status_bg = t and c.none or (c.statusBar_background or bg_alt)
  local status_nc_bg = t and c.none or (c.statusBar_noFolderBackground or cs.mix(status_bg, border, 6))
  local tab_inactive_fg = c.tab_inactiveForeground or status_fg
  local tab_inactive_bg = t and c.none or (c.tab_inactiveBackground or c.editorGroupHeader_tabsBackground or status_bg)
  local tab_active_fg = c.tab_activeForeground or fg
  local tab_active_bg = t and c.none or (c.tab_activeBackground or c.tab_selectedBackground or cs.mix(bg, selection, 50))
  local tab_fill_bg = t and c.none or (c.editorGroupHeader_tabsBackground or tab_inactive_bg)
  local winbar_fg = c.titleBar_activeForeground or tab_active_fg
  local winbar_bg = t and c.none or (c.titleBar_activeBackground or bg)
  local winbar_nc_fg = c.titleBar_inactiveForeground or tab_inactive_fg
  local winbar_nc_bg = t and c.none or (c.titleBar_inactiveBackground or bg)
  local vert_split_fg = c.editorGroupHeader_tabsBorder or c.sideBarSectionHeader_border or border
  local vert_split_active_fg = c.tab_activeBorder or c.tab_activeBorderTop or c.focusBorder or bright_orange
  local win_separator_fg = c.editorGroup_border or border_strong
  local search_bg = c.editor_findMatchBackground or selection
  local inc_search_bg = c.editor_findMatchBackground or c.editor_selectionHighlightBackground or selection
  local quickfix_bg = c.list_dropBackground or c.peekViewResult_background or cs.mix(bg, selection, 30)
  local quickfix_fg = c.quickInput_foreground or menu_fg

  local comment = c.tokenComment or c.status or c.textMuted or fg_muted
  local constant = c.tokenConstantsAndEnums or c.tokenConstantNumeric or bright_aqua
  local string_color = c.semanticStringLiteral or c.tokenString or accent_orange
  local number_color = c.semanticNumberLiteral or c.tokenConstantNumeric or accent_green
  local boolean_color = c.tokenConstantLanguage or c.tokenKeyword or accent_purple
  local function_color = c.tokenFunctionDeclarations or accent_blue
  local keyword_color = c.tokenKeyword or c.tokenControlFlowSpecialKeywords or accent_purple
  local operator_color = c.semanticNewOperator or c.tokenKeywordOperator or (c.text or u.fg1)
  local type_color = c.tokenTypesDeclarationAndReferences or accent_blue
  local builtin_color = c.tokenThisSelf or keyword_color
  local diagnostic_error = c.errorForeground or c.tokenInvalid or c.accentRed or u.red
  local diagnostic_warn = c.warning or c.tokenMarkupDeleted or accent_yellow
  local diagnostic_info = c.accentBlue or c.tokenMarkupChanged or bright_blue
  local diagnostic_hint = c.accentAqua or c.tokenMarkupInserted or bright_aqua
  local diagnostic_ok = c.success or accent_green

  local function diag_bg(color)
    if t then
      return c.none
    end
    return cs.mix(bg, color, 18)
  end

  ---@type table<string, std.t.theme.IHlgroup>
  local hlgroup_map = {
    ComplHint = { fg = fg_muted, italic = true },
    ComplHintMore = { fg = fg_dim, italic = true },
    Added = { fg = diagnostic_ok },
    Changed = { fg = accent_yellow },
    Bold = { fg = fg, bold = true },
    Boolean = { fg = boolean_color },
    Builtin = { fg = builtin_color, italic = true },
    Character = { fg = string_color },
    ColorColumn = { bg = c.editorWidget_background or cs.mix(bg, selection, 30) },
    Comment = { fg = comment, italic = true },
    Conceal = { fg = fg_muted },
    Conditional = { fg = keyword_color },
    Constant = { fg = constant },
    CurSearch = { fg = bg, bg = inc_search_bg, bold = true },
    Cursor = { fg = bg, bg = accent_orange },
    CursorColumn = { bg = c.editor_inactiveSelectionBackground or cursorline_bg },
    CursorLine = { bg = cursorline_bg },
    CursorLineNr = { fg = cursorline_nr_fg, bg = cursorline_bg, bold = true },
    iCursor = { link = "Cursor" },
    lCursor = { link = "Cursor" },
    vCursor = { link = "Cursor" },
    Debug = { fg = diagnostic_warn },
    Define = { fg = keyword_color },
    Delimiter = { fg = operator_color },
    Diagnostic_ERROR = { fg = diagnostic_error },
    Diagnostic_HINT = { fg = diagnostic_hint },
    Diagnostic_INFO = { fg = diagnostic_info },
    Diagnostic_WARN = { fg = diagnostic_warn },
    DiagnosticError = { fg = diagnostic_error },
    DiagnosticFloatingError = { fg = diagnostic_error },
    DiagnosticFloatingHint = { fg = diagnostic_hint },
    DiagnosticFloatingInfo = { fg = diagnostic_info },
    DiagnosticFloatingOk = { fg = diagnostic_ok },
    DiagnosticFloatingWarn = { fg = diagnostic_warn },
    DiagnosticHint = { fg = diagnostic_hint },
    DiagnosticInfo = { fg = diagnostic_info },
    DiagnosticWarn = { fg = diagnostic_warn },
    DiagnosticOk = { fg = diagnostic_ok },
    DiagnosticSignError = { fg = diagnostic_error },
    DiagnosticSignHint = { fg = diagnostic_hint },
    DiagnosticSignInfo = { fg = diagnostic_info },
    DiagnosticSignOk = { fg = diagnostic_ok },
    DiagnosticSignWarn = { fg = diagnostic_warn },
    DiagnosticUnderlineError = { undercurl = true, sp = diagnostic_error },
    DiagnosticUnderlineHint = { undercurl = true, sp = diagnostic_hint },
    DiagnosticUnderlineInfo = { undercurl = true, sp = diagnostic_info },
    DiagnosticUnderlineWarn = { undercurl = true, sp = diagnostic_warn },
    DiagnosticVirtualTextError = { fg = diagnostic_error, bg = diag_bg(diagnostic_error) },
    DiagnosticVirtualTextHint = { fg = diagnostic_hint, bg = diag_bg(diagnostic_hint) },
    DiagnosticVirtualTextInfo = { fg = diagnostic_info, bg = diag_bg(diagnostic_info) },
    DiagnosticVirtualTextWarn = { fg = diagnostic_warn, bg = diag_bg(diagnostic_warn) },
    DiagnosticVirtualTextOk = { fg = diagnostic_ok, bg = diag_bg(diagnostic_ok) },
    DiffAddLeft = { bg = u.diffAdd or cs.mix(bg, diff_add, 30) },
    DiffAddRight = { bg = u.diffAdd or cs.mix(bg, diff_add, 30) },
    DiffAdd = { bg = cs.mix(bg, diff_add, 22) },
    DiffAdded = { link = "DiffAdd" },
    DiffChange = { bg = cs.mix(bg, diff_change, 18) },
    DiffChanged = { link = "DiffChange" },
    DiffDelete = { bg = cs.mix(bg, diff_delete, 20) },
    DiffDelLeft = { bg = u.diffDel or cs.mix(bg, diff_delete, 30) },
    DiffDelRight = { bg = u.diffDel or cs.mix(bg, diff_delete, 30) },
    DiffFile = { fg = c.tokenMarkupHeading or accent_orange },
    DiffIndexLine = { link = "diffChanged" },
    DiffLine = { fg = diff_change },
    DiffModLeft = { bg = u.diffDel or cs.mix(bg, diff_change, 30) },
    DiffModRight = { bg = u.diffAdd or cs.mix(bg, diff_change, 30) },
    DiffNewFile = { fg = diff_add },
    DiffOldFile = { fg = diff_delete },
    DiffRemoved = { link = "DiffDelete" },
    DiffText = { bg = cs.mix(bg, diff_change, 24) },
    DiffWordLeft = { bg = u.diffDelInline or cs.mix(bg, diff_delete, 60) },
    DiffWordRight = { bg = u.diffAddInline or cs.mix(bg, diff_add, 60) },
    DevIconDefault = { fg = c.icon_foreground or accent_red },
    Directory = { fg = c.sideBarTitle_foreground or accent_blue, bold = true },
    Done = { fg = diagnostic_ok, bold = true, italic = true },
    EndOfBuffer = { fg = bg },
    Error = { fg = diagnostic_error },
    ErrorMsg = { fg = diagnostic_error, bg = status_bg, bold = true },
    Exception = { fg = accent_purple },
    Float = { fg = string_color },
    FloatActiveBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    FloatBorder = { fg = popup_border, bg = bg_popup },
    FloatNormal = { fg = popup_fg, bg = bg_popup },
    FloatActiveTitle = { link = "ms_b_bg0" },
    FloatTitle = {
      fg = c.notificationCenterHeader_foreground or popup_fg,
      bg = c.notificationCenterHeader_background or bg_popup,
      bold = true,
    },
    FoldColumn = { fg = line_nr_fg },
    Folded = { fg = fg_dim, bg = c.editorWidget_background or cs.mix(bg, border, 15) },
    Function = { fg = function_color },
    Identifier = { fg = c.tokenVariableAndParameterName or accent_blue },
    Include = { fg = keyword_color },
    IncSearch = { fg = bg, bg = inc_search_bg },
    Italic = { fg = fg, italic = true },
    Keyword = { fg = keyword_color, italic = true },
    Label = { fg = c.tokenMarkupHeading or keyword_color },
    Macro = { fg = accent_aqua },
    Member = { fg = accent_aqua },
    Method = { fg = function_color, bold = true },
    LineNr = { fg = line_nr_fg },
    LspCodeLens = { fg = fg_muted, italic = true },
    LspInlayHint = {
      fg = fg_dim,
      bg = t and c.none or (c.editorWidget_background or c.editor_inactiveSelectionBackground or cs.mix(bg, border, 10)),
      italic = true,
    },
    LspReferenceRead = { bg = cs.mix(bg, selection, 40) },
    LspReferenceText = { bg = cs.mix(bg, selection, 40) },
    LspReferenceWrite = { bg = cs.mix(bg, accent_orange, 35) },
    LspSignatureActiveParameter = { fg = function_color, bg = cs.mix(bg, selection, 45), bold = true },
    RenamerBorder = { link = t and "ms_b_bg0" or "ms_b_none" },
    RenamerTitle = { link = t and "ms_b_bg0" or "ms_b_none" },
    MatchParen = { fg = accent_orange, bg = cs.mix(bg, selection, 55), bold = true },
    MatchWord = { fg = fg, bg = c.editor_selectionHighlightBackground or cs.mix(bg, border, 30) },
    MiniIndentscopeSymbol = { fg = indent_guide_active },
    ModeMsg = { fg = status_fg, bg = status_bg, bold = true },
    MoreMsg = { fg = diagnostic_ok, bg = status_bg, bold = true },
    MsgArea = { fg = status_fg, bg = status_bg },
    NonText = { fg = line_nr_fg },
    Normal = { fg = fg, bg = bg },
    NormalFloat = { fg = popup_fg, bg = bg_popup },
    NormalNC = { fg = fg, bg = bg },
    NvimInternalError = { fg = diagnostic_error },
    Number = { fg = number_color },
    Operator = { fg = operator_color },
    Parameter = { fg = c.tokenVariableAndParameterName or accent_blue },
    Pmenu = { fg = menu_fg, bg = menu_bg },
    PmenuSbar = { bg = menu_sbar_bg },
    PmenuSel = { fg = menu_fg, bg = menu_sel_bg, bold = true },
    PmenuThumb = { bg = menu_thumb_bg },
    PreCondit = { fg = keyword_color },
    PreProc = { fg = keyword_color },
    Repeat = { fg = keyword_color },
    Question = { fg = diagnostic_ok },
    QuickFixLine = { fg = quickfix_fg, bg = quickfix_bg, bold = true },
    Removed = { fg = accent_red },
    Search = { fg = bg, bg = search_bg },
    SignColumn = { fg = line_nr_fg, bg = bg },
    Special = { fg = c.tokenMarkupInlineRaw or function_color },
    SpecialChar = { fg = c.tokenString or string_color },
    SpecialKey = { fg = line_nr_fg },
    healthError = { fg = diagnostic_error },
    healthSuccess = { fg = bg, bg = diagnostic_ok },
    healthWarning = { fg = diagnostic_warn },
    SpellBad = { undercurl = true, sp = diagnostic_error },
    SpellCap = { undercurl = true, sp = accent_blue },
    SpellLocal = { undercurl = true, sp = accent_green },
    SpellRare = { undercurl = true, sp = accent_purple },
    Statement = { fg = keyword_color },
    StatusColumnMark = { link = "DiagnosticHint", default = true },
    StatusLine = { fg = status_fg, bg = status_bg },
    StatusLineNC = { fg = fg_dim, bg = status_nc_bg },
    StorageClass = { fg = keyword_color },
    String = { fg = string_color },
    Structure = { fg = type_color },
    Substitute = { fg = bg, bg = accent_red },
    TabLine = { fg = tab_inactive_fg, bg = tab_inactive_bg },
    TabLineFill = { fg = tab_inactive_fg, bg = tab_fill_bg },
    TabLineSel = { fg = tab_active_fg, bg = tab_active_bg, bold = true },
    Tag = { fg = c.tokenEntityNameTag or keyword_color, bold = true },
    Title = { fg = accent_blue, bold = true },
    Todo = { fg = bg, bg = accent_orange, bold = true, italic = true },
    TooLong = { fg = diagnostic_error },
    Type = { fg = type_color },
    Typedef = { fg = type_color },
    UnderLined = { underline = true },
    Variable = { fg = c.tokenVariableAndParameterName or fg },
    Visual = { bg = selection, fg = fg },
    VisualNOS = { link = "Visual" },
    WarningMsg = { fg = diagnostic_warn, bg = status_bg, bold = true },
    Whitespace = { fg = indent_guide },
    WildMenu = { fg = menu_fg, bg = menu_sel_bg, bold = true },
    WinBar = { fg = winbar_fg, bg = winbar_bg },
    WinBarNC = { fg = winbar_nc_fg, bg = winbar_nc_bg },
    VertSplit = { fg = vert_split_fg },
    VertSplitActive = { fg = vert_split_active_fg },
    WinSeparator = { fg = win_separator_fg },
  }

  return hlgroup_map
end

return M
