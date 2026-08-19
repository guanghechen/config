---@class dot.var
---@field public N_BUF_DISABLE_LINT     string
---@field public N_IMAGE_ATTACHED       string
---@field public N_IMAGE_CONCEAL        string
---@field public N_WINLINE_DISABLED     string
local M = {}

M.BUF_UNTITLED = "untitled"
M.EDITING_INPUT_PREFIX = "@#!dot!#@"
M.WIN_BUF_HISTORY_CAPACITY = 99
M.WIN_HISTORY_CAPACITY = 99

----------------------------------------------------------------------------------------------------

M.K_CODE_INSERT_SPLITLINE = "g;"

----------------------------------------------------------------------------------------------------

M.N_BUF_DISABLE_LINT = "dot_buf_disable_lint"
M.N_IMAGE_ATTACHED = "dot_image_attached"
M.N_IMAGE_CONCEAL = "dot_image_conceal"
M.N_WINLINE_DISABLED = "dot_winline_disabled"

----------------------------------------------------------------------------------------------------

local severity = vim.diagnostic.severity

---@class dot.var.diagnostic
M.diagnostic = {
  ---@type table<vim.diagnostic.Severity, string>
  severity2prefixicon = {
    [severity.ERROR] = stl.icon.diagnostic.Error_alt,
    [severity.WARN] = stl.icon.diagnostic.Warning_alt,
    [severity.INFO] = stl.icon.diagnostic.Information_alt,
    [severity.HINT] = stl.icon.diagnostic.Hint_alt,
  },
  ---@type table<vim.diagnostic.Severity, string>
  severity2texticon = {
    [severity.ERROR] = stl.icon.diagnostic.Error_alt,
    [severity.WARN] = stl.icon.diagnostic.Warning_alt,
    [severity.INFO] = stl.icon.diagnostic.Information_alt,
    [severity.HINT] = stl.icon.diagnostic.Hint_alt,
  },
  ---@type table<vim.diagnostic.Severity, string>
  severity2numhl = {
    [severity.ERROR] = "f_lnum_error",
    [severity.WARN] = "f_lnum_warn",
    [severity.INFO] = "f_lnum_info",
    [severity.HINT] = "f_lnum_hint",
  },
}

----------------------------------------------------------------------------------------------------

local cn = vim.api.nvim_create_namespace

---@class dot.var.nsnr
M.nsnr = {
  -- stylua: ignore start
  ai_prompt_preview     = cn("ux:ai:prompt:preview"),
  attach                = cn("ux:attach"),
  cmdline               = cn("ux:cmdline"),
  diagnostic            = cn("ux:diagnostic"),
  explorer_cursorline   = cn("ux:explorer:cursorline"),
  input_confirmation    = cn("ux:input:confirmation"),
  matches               = cn("ux:matches"),
  notify                = cn("ux:notify"),
  picker                = cn("ux:picker"),
  picker_matches        = cn("ux:picker:matches"),
  picker_preview        = cn("ux:picker:preview"),
  picker_preview_visual = cn("ux:picker:preview:visual"),
  picker_result         = cn("ux:picker:result"),
  searcher_matches      = cn("ux:searcher:matches"),
  searcher_preview      = cn("ux:searcher:preview"),
  searcher_result       = cn("ux:searcher:result"),
  searcher_searched     = cn("ux:searcher:searched"),
  searcher_searched_cur = cn("ux:searcher:searched:cur"),
  search_count          = cn("ux:search_count"),
  select                = cn("ux:select"),
  popupmenu             = cn("ux:popupmenu"),
  popupmenu_selected    = cn("ux:popupmenu_selected"),
  view_plainfile        = cn("ux:view:plainfile"),
  view_printer          = cn("ux:view:printer"),
  view_tree             = cn("ux:view:tree"),
  view_filetree_matches = cn("ux:view:filetree:matches"),
  virtcolumn            = cn("ux:virtcolumn"),
  -- stylua: ignore end
}

----------------------------------------------------------------------------------------------------

---@class dot.var.session
M.session = {
  persistent_options = table.concat({
    "blank",
    "buffers",
    "curdir",
    "folds",
    "globals",
    "help",
    "resize",
    "slash",
    "skiprtp",
    "tabpages",
    "unix",
    "winpos",
    "winsize",
  }, ","),
}

---@class dot.var.themes
M.themes = {
  "catppuccin-frappe",
  "catppuccin-latte",
  "catppuccin-macchiato",
  "catppuccin-mocha",
  "gruvbox-dark",
  "gruvbox-light",
  "nord",
  "onehalf-dark",
  "onehalf-light",
  "rosepine-dawn",
  "rosepine-main",
  "rosepine-moon",
  "tokyonight-day",
  "tokyonight-moon",
  "tokyonight-night",
  "tokyonight-storm",
  "vsc-dark-modern",
  "vsc-light-modern",
}

---@class dot.var.toggler
M.toggler = {
  "auto_im_behavior",
  "bufs_relative_behavior",

  "fileencoding_local",
  "fileformat_local",
  "hipatterns_local",
  "markdown_local",
  "wrap_local",

  "expandtab_ux",
  "notification_paused_ux",
  "relativenumber_ux",
  "transparency_ux",
  "theme_ux",
  "theme_variant_ux",
  "username_ux",

  "autoformat_flight",
  "autoload_flight",
  "autosave_flight",
  "devmode_flight",
  "dressing_clipboard_flight",
  "dressing_illuminate_flight",
  "dressing_input_flight",
  "dressing_select_flight",
  "dressing_winsep_flight",
  "gitdiff_expand_all_flight",

  "code_lens_lsp",
  "diagnostics_virt_lines_lsp",
  "inlay_hints_lsp",
  "python_venv_lsp",
  "spellcheck_lsp",

  "render_markdown_plugin",
  "treesitter_context_plugin",

  "maximize",
}

----------------------------------------------------------------------------------------------------

---@class dot.var.sign
M.sign = {
  -- stylua: ignore start
  ---! picker
  GROUP_PICKER_FINDER_PROMPT            = "ba16e20e-993c-43f5-8916-b254f009816e",
  GROUP_PICKER_RESULT_CURRENT           = "904b8648-d599-4b9f-a02d-e015c99505a5",
  GROUP_PICKER_RESULT_PRESENT           = "4bca395f-09c9-4e37-be28-19e2568cdb73",
  GROUP_PICKER_RESULT_SELECTED          = "8f3ed243-bcaf-4dba-ac46-f7fc9d20c772",
  NR_PICKER_RESULT_CURRENT              = 3010,
  NR_PICKER_RESULT_PRESENT              = 3011,
  PICKER_FINDER_PROMPT                  = "PickerFinderPrompt",
  PICKER_RESULT_CURRENT                 = "PickerResultCurrent",
  PICKER_RESULT_PRESENT                 = "PickerResultPresent",
  PICKER_RESULT_PRESENT_CURRENT         = "PickerResultPresentCurrent",
  PICKER_RESULT_SELECTED                = "PickerResultSelected",
  PICKER_RESULT_SELECTED_CURRENT        = "PickerResultSelectedCurrent",

  GROUP_SEARCHER_BUFFER_PROMPT          = "3e46a5aa-0872-4671-8e92-2e7ebc91e715",
  GROUP_SEARCHER_FINDER_PROMPT          = "8efb0a6e-1bd8-4902-8898-b19bf83d856d",
  GROUP_SEARCHER_RESULT_CURRENT         = "e1235112-26c1-42c5-8b96-f7f43fedd804",
  GROUP_SEARCHER_RESULT_PRESENT         = "8b8e311a-1c6f-42f7-bf6a-d67e033011d9",
  GROUP_SEARCHER_RESULT_SELECTED        = "729f2114-03b6-46b7-9cd6-bccc5d1756e6",
  NR_SEARCHER_RESULT_CURRENT            = 3030,
  NR_SEARCHER_RESULT_PRESENT            = 3031,
  SEARCHER_BUFFER_PROMPT                = "SearcherBufferPrompt",
  SEARCHER_FINDER_PROMPT                = "SearcherFinderPrompt",
  SEARCHER_RESULT_CURRENT               = "SearcherResultCurrent",
  SEARCHER_RESULT_PRESENT               = "SearcherResultPresent",
  SEARCHER_RESULT_PRESENT_CURRENT       = "SearcherResultPresentCurrent",
  SEARCHER_RESULT_SELECTED              = "SearcherResultSelected",
  SEARCHER_RESULT_SELECTED_CURRENT      = "SearcherResultSelectedCurrent",

  ---! choices
  CHOICES_CURRENT                       = "ChoicesCurrent",
  GROUP_CHOICES_CURRENT                 = "f7a1b2c3-d4e5-6789-abcd-ef0123456789",
  NR_CHOICES_CURRENT                    = 3050,

  ---! diffview commits
  DIFFVIEW_COMMITS_PRESENT              = "DiffviewCommitsPresent",
  GROUP_DIFFVIEW_COMMITS                = "a1b2c3d4-e5f6-7890-abcd-diffvcommits",

  ---! dap
  DAP_BREAKPOINT                        = "DapBreakpoint",
  DAP_BREAKPOINT_CONDITION              = "DapBreakpointCondition",
  DAP_BREAKPOINT_REJECTED               = "DapBreakpointRejected",
  DAP_LOG_POINT                         = "DapLogPoint",
  DAP_STOPPED                           = "DapStopped",
  -- stylua: ignore end
}

-- stylua: ignore start
local sd = vim.fn.sign_define
sd(M.sign.PICKER_FINDER_PROMPT,             { text = stl.icon.ui.Telescope,            texthl = "m_pk_finder_prompt"              })
sd(M.sign.PICKER_RESULT_CURRENT,            { text = stl.icon.ui.ArrowPresent,         texthl = "m_pk_sign_line_current"          })
sd(M.sign.PICKER_RESULT_PRESENT,            { text = stl.icon.ui.ArrowPresent,         texthl = "m_pk_sign_line_present"          })
sd(M.sign.PICKER_RESULT_PRESENT_CURRENT,    { text = stl.icon.ui.ArrowPresent,         texthl = "m_pk_sign_line_present_current"  })
sd(M.sign.PICKER_RESULT_SELECTED,           { text = stl.icon.ui.Selected,             texthl = "m_pk_sign_line_selected"         })
sd(M.sign.PICKER_RESULT_SELECTED_CURRENT,   { text = stl.icon.ui.SelectedCurrent,      texthl = "m_pk_sign_line_selected_current" })

sd(M.sign.SEARCHER_BUFFER_PROMPT,           { text = stl.icon.ui.Telescope,            texthl = "m_pk_finder_prompt"              })
sd(M.sign.SEARCHER_FINDER_PROMPT,           { text = stl.icon.ui.Telescope,            texthl = "m_pk_finder_prompt"              })
sd(M.sign.SEARCHER_RESULT_CURRENT,          { text = stl.icon.ui.ArrowPresent,         texthl = "m_pk_sign_line_current"          })
sd(M.sign.SEARCHER_RESULT_PRESENT,          { text = stl.icon.ui.ArrowPresent,         texthl = "m_pk_sign_line_present"          })
sd(M.sign.SEARCHER_RESULT_PRESENT_CURRENT,  { text = stl.icon.ui.ArrowPresent,         texthl = "m_pk_sign_line_present_current"  })
sd(M.sign.SEARCHER_RESULT_SELECTED,         { text = stl.icon.ui.Selected,             texthl = "m_pk_sign_line_selected"         })
sd(M.sign.SEARCHER_RESULT_SELECTED_CURRENT, { text = stl.icon.ui.SelectedCurrent,      texthl = "m_pk_sign_line_selected_current" })

sd(M.sign.CHOICES_CURRENT,                  { text = stl.icon.ui.ArrowPresent,         texthl = "m_ch_sign_current"               })

sd(M.sign.DIFFVIEW_COMMITS_PRESENT,         { text = stl.icon.ui.ArrowPresent,         texthl = "m_dv_sign_present"               })

sd(M.sign.DAP_BREAKPOINT,                   { text = stl.icon.dap.Breakpoint,          texthl = "DapBreakpoint",                  linehl = "DapBreakpointLine",          numhl = "DapBreakpointNum",          })
sd(M.sign.DAP_BREAKPOINT_CONDITION,         { text = stl.icon.dap.BreakpointCondition, texthl = "DapBreakpointCondition",         linehl = "DapBreakpointConditionLine", numhl = "DapBreakpointConditionNum", })
sd(M.sign.DAP_BREAKPOINT_REJECTED,          { text = stl.icon.dap.BreakpointRejected,  texthl = "DapBreakpointRejected",          linehl = "DapBreakpointRejectedLine",  numhl = "DapBreakpointRejectedNum",  })
sd(M.sign.DAP_LOG_POINT,                    { text = stl.icon.dap.LogPoint,            texthl = "DapLogPoint",                    linehl = "DapLogPointLine",            numhl = "DapLogPointNum",            })
sd(M.sign.DAP_STOPPED,                      { text = stl.icon.dap.Stopped,             texthl = "DapStopped",                     linehl = "DapStoppedLine",             numhl = "DapStoppedNum",             })
-- stylua: ignore end

----------------------------------------------------------------------------------------------------

---@class dot.var.zindex
M.zindex = {
  BOARD = 100,
  CMDLINE = 10000,
  CMDLINE_BLOCK = 10500,
  MESSAGES = 200,
  NOTIFIER = 9000,
  WK = 8000,
  POPUPMENU = 1200,
  TREESITTER_CONTEXT = 30,
  WINSEP = 10,
}

return M
