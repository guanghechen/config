---@class eve.builtin.var
local M = {}

---@class eve.builtin.var.Names
M.Names = {
  BUF_DISABLE_AUTO_FORMAT = "eve_buf_disable_auto_format",
  BUF_DISABLE_LINT = "eve_buf_disable_lint",
  NEO_TREE_SOURCE = "neo_tree_source",
  WINLINE_DISABLED = "eve_winline_disabled",
}

local cn = vim.api.nvim_create_namespace

---@class eve.builtin.var.nsnr
M.nsnr = {
  -- stylua: ignore start
  attach                = cn("ux:attach"),
  cmdline               = cn("ux:cmdline"),
  hipairs               = cn("ux:hipairs"),
  indentline            = cn("ux:indentline"),
  matches               = cn("ux:matches"),
  notify                = cn("ux:notify"),
  picker                = cn("ux:picker"),
  picker_matches        = cn("ux:picker:matches"),
  picker_preview        = cn("ux:picker:preview"),
  picker_result         = cn("ux:picker:result"),
  searcher_matches      = cn("ux:searcher:matches"),
  searcher_preview      = cn("ux:searcher:preview"),
  searcher_result       = cn("ux:searcher:result"),
  search_count          = cn("ux:search_count"),
  search_input          = cn("ux:search_input"),
  search_main           = cn("ux:search_main"),
  search_preview        = cn("ux:search_preview"),
  select_popup          = cn("ux:select_popup"),
  popupmenu             = cn("ux:popupmenu"),
  popupmenu_selected    = cn("ux:popupmenu_selected"),
  view_plainfile        = cn("ux:view:plainfile"),
  view_printer          = cn("ux:view:printer"),
  view_tree             = cn("ux:view:tree"),
  view_filetree_matches = cn("ux:view:filetree:matches"),
  -- stylua: ignore end
}

---@class eve.builtin.var.sign
M.sign = {
  -- stylua: ignore start
  NR_SEARCH_MAIN_CURRENT                = 2333,
  NR_SEARCH_MAIN_PRESENT                = 2334,
  NR_SEARCH_MAIN_SELECTED               = 2335,

  ---! picker
  GROUP_PICKER_FINDER_PROMPT            = std.fn.uuid(),
  GROUP_PICKER_RESULT_CURRENT           = std.fn.uuid(),
  GROUP_PICKER_RESULT_PRESENT           = std.fn.uuid(),
  GROUP_PICKER_RESULT_SELECTED          = std.fn.uuid(),
  NR_PICKER_RESULT_CURRENT              = 3010,
  NR_PICKER_RESULT_PRESENT              = 3011,
  PICKER_FINDER_PROMPT                  = "PickerFinderPrompt",
  PICKER_RESULT_CURRENT                 = "PickerResultCurrent",
  PICKER_RESULT_PRESENT                 = "PickerResultPresent",
  PICKER_RESULT_PRESENT_CURRENT         = "PickerResultPresentCurrent",
  PICKER_RESULT_SELECTED                = "PickerResultSelected",
  PICKER_RESULT_SELECTED_CURRENT        = "PickerResultSelectedCurrent",

  GROUP_SEARCHER_FINDER_PROMPT          = std.fn.uuid(),
  GROUP_SEARCHER_RESULT_CURRENT         = std.fn.uuid(),
  GROUP_SEARCHER_RESULT_PRESENT         = std.fn.uuid(),
  GROUP_SEARCHER_RESULT_SELECTED        = std.fn.uuid(),
  NR_SEARCHER_RESULT_CURRENT            = 3010,
  NR_SEARCHER_RESULT_PRESENT            = 3011,
  SEARCHER_FINDER_PROMPT                = "SearcherFinderPrompt",
  SEARCHER_RESULT_CURRENT               = "SearcherResultCurrent",
  SEARCHER_RESULT_PRESENT               = "SearcherResultPresent",
  SEARCHER_RESULT_PRESENT_CURRENT       = "SearcherResultPresentCurrent",
  SEARCHER_RESULT_SELECTED              = "SearcherResultSelected",
  SEARCHER_RESULT_SELECTED_CURRENT      = "SearcherResultSelectedCurrent",

  GROUP_SEARCH_MAIN_SELECTED            = std.fn.uuid(),

  DAP_BREAKPOINT                        = "DapBreakpoint",
  DAP_BREAKPOINT_CONDITION              = "DapBreakpointCondition",
  DAP_BREAKPOINT_REJECTED               = "DapBreakpointRejected",
  DAP_LOG_POINT                         = "DapLogPoint",
  DAP_STOPPED                           = "DapStopped",


  SEARCH_INPUT_CURSOR                   = "SearchInputCursor",
  SEARCH_MAIN_CURRENT                   = "SearchMainCurrent",
  SEARCH_MAIN_PRESENT                   = "SearchMainPresent",
  SEARCH_MAIN_PRESENT_CUR               = "SearchMainPresentCur",
  SEARCH_MAIN_SELECTED                  = "SearchMainSelected",
  SEARCH_MAIN_SELECTED_CUR              = "SearchMainSelectedCur",
  -- stylua: ignore end
}

-- stylua: ignore start
local sd = vim.fn.sign_define
sd(M.sign.DAP_BREAKPOINT,                   { text = eve.icon.dap.Breakpoint,          texthl = "DapBreakpoint",                  linehl = "DapBreakpointLine",          numhl = "DapBreakpointNum",          })
sd(M.sign.DAP_BREAKPOINT_CONDITION,         { text = eve.icon.dap.BreakpointCondition, texthl = "DapBreakpointCondition",         linehl = "DapBreakpointConditionLine", numhl = "DapBreakpointConditionNum", })
sd(M.sign.DAP_BREAKPOINT_REJECTED,          { text = eve.icon.dap.BreakpointRejected,  texthl = "DapBreakpointRejected",          linehl = "DapBreakpointRejectedLine",  numhl = "DapBreakpointRejectedNum",  })
sd(M.sign.DAP_LOG_POINT,                    { text = eve.icon.dap.LogPoint,            texthl = "DapLogPoint",                    linehl = "DapLogPointLine",            numhl = "DapLogPointNum",            })
sd(M.sign.DAP_STOPPED,                      { text = eve.icon.dap.Stopped,             texthl = "DapStopped",                     linehl = "DapStoppedLine",             numhl = "DapStoppedNum",             })

sd(M.sign.PICKER_FINDER_PROMPT,             { text = eve.icon.ui.Telescope,            texthl = "f_pk_finder_prompt"              })
sd(M.sign.PICKER_RESULT_CURRENT,            { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_current"          })
sd(M.sign.PICKER_RESULT_PRESENT,            { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_present"          })
sd(M.sign.PICKER_RESULT_PRESENT_CURRENT,    { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_present_current"  })
sd(M.sign.PICKER_RESULT_SELECTED,           { text = eve.icon.ui.Selected,             texthl = "f_pk_sign_line_selected"         })
sd(M.sign.PICKER_RESULT_SELECTED_CURRENT,   { text = eve.icon.ui.SelectedCurrent,      texthl = "f_pk_sign_line_selected_current" })

sd(M.sign.SEARCHER_FINDER_PROMPT,           { text = eve.icon.ui.Telescope,            texthl = "f_pk_finder_prompt"              })
sd(M.sign.SEARCHER_RESULT_CURRENT,          { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_current"          })
sd(M.sign.SEARCHER_RESULT_PRESENT,          { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_present"          })
sd(M.sign.SEARCHER_RESULT_PRESENT_CURRENT,  { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_present_current"  })
sd(M.sign.SEARCHER_RESULT_SELECTED,         { text = eve.icon.ui.Selected,             texthl = "f_pk_sign_line_selected"         })
sd(M.sign.SEARCHER_RESULT_SELECTED_CURRENT, { text = eve.icon.ui.SelectedCurrent,      texthl = "f_pk_sign_line_selected_current" })

sd(M.sign.SEARCH_INPUT_CURSOR,              { text = eve.icon.ui.Telescope,            texthl = "fs_input_prompt"                 })
sd(M.sign.SEARCH_MAIN_CURRENT,              { text = ' ',                              texthl = "fs_main_current"                 })
sd(M.sign.SEARCH_MAIN_PRESENT,              { text = eve.icon.ui.ArrowPresent,         texthl = "fs_main_present"                 })
sd(M.sign.SEARCH_MAIN_PRESENT_CUR,          { text = eve.icon.ui.ArrowPresent,         texthl = "fs_main_present_cur"             })
sd(M.sign.SEARCH_MAIN_SELECTED,             { text = eve.icon.ui.Selected,             texthl = "fs_main_selected"                })
sd(M.sign.SEARCH_MAIN_SELECTED_CUR,         { text = eve.icon.ui.Selected,             texthl = "fs_main_selected_cur"            })
-- stylua: ignore end

return M
