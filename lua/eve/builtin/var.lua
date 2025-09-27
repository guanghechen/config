---@class eve.builtin.var
local M = {}

---@class eve.builtin.var.Names
M.Names = {
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
  diagnostic            = cn("ux:diagnostic"),
  hipairs               = cn("ux:hipairs"),
  indentline            = cn("ux:indentline"),
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
  -- stylua: ignore end
}

---@class eve.builtin.var.sign
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

  DAP_BREAKPOINT                        = "DapBreakpoint",
  DAP_BREAKPOINT_CONDITION              = "DapBreakpointCondition",
  DAP_BREAKPOINT_REJECTED               = "DapBreakpointRejected",
  DAP_LOG_POINT                         = "DapLogPoint",
  DAP_STOPPED                           = "DapStopped",
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
sd(M.sign.SEARCHER_BUFFER_PROMPT,           { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_current"          })
sd(M.sign.SEARCHER_RESULT_PRESENT,          { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_present"          })
sd(M.sign.SEARCHER_RESULT_PRESENT_CURRENT,  { text = eve.icon.ui.ArrowPresent,         texthl = "f_pk_sign_line_present_current"  })
sd(M.sign.SEARCHER_RESULT_SELECTED,         { text = eve.icon.ui.Selected,             texthl = "f_pk_sign_line_selected"         })
sd(M.sign.SEARCHER_RESULT_SELECTED_CURRENT, { text = eve.icon.ui.SelectedCurrent,      texthl = "f_pk_sign_line_selected_current" })
-- stylua: ignore end

return M
