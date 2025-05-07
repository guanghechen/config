---@class eve.builtin.var
local M = {}

---@class eve.builtin.vars.Names
M.Names = {
  BUF_DISABLE_AUTO_FORMAT = "eve_buf_disable_auto_format",
  BUF_DISABLE_LINT = "eve_buf_disable_lint",
  NEO_TREE_SOURCE = "neo_tree_source",
  WINLINE_DISABLED = "eve_winline_disabled",
}

local cn = vim.api.nvim_create_namespace

---@class eve.builtin.vars.nsnr
M.nsnr = {
  -- stylua: ignore start
  attach                = cn("ux_attach"),
  cmdline               = cn("ux_cmdline"),
  hipairs               = cn("ux_hipairs"),
  indentline            = cn("ux_indentline"),
  notify                = cn("ux_notify"),
  search_count          = cn("ux_search_count"),
  search_input          = cn("ux_search_input"),
  search_main           = cn("ux_search_main"),
  search_preview        = cn("ux_search_preview"),
  select_popup          = cn("ux_select_popup"),
  popupmenu             = cn("ux_popupmenu"),
  popupmenu_selected    = cn("ux_popupmenu_selected"),
  -- stylua: ignore end
}

---@class eve.builtin.vars.sign
M.sign = {
  NR_SEARCH_MAIN_CURRENT = 2333,
  NR_SEARCH_MAIN_PRESENT = 2334,
  NR_SEARCH_MAIN_SELECTED = 2335,

  GROUP_SEARCH_MAIN_SELECTED = "GROUP_SEARCH_MAIN_SELECTED",

  -- stylua: ignore start
  DAP_BREAKPOINT            = "DapBreakpoint",
  DAP_BREAKPOINT_CONDITION  = "DapBreakpointCondition",
  DAP_BREAKPOINT_REJECTED   = "DapBreakpointRejected",
  DAP_LOG_POINT             = "DapLogPoint",
  DAP_STOPPED               = "DapStopped",

  PICKER_FINDER_PROMPT      = "PickerFinderPrompt",
  PICKER_RESULT_PRESENT     = "PickerResultPresent",

  SEARCH_INPUT_CURSOR       = "SearchInputCursor",
  SEARCH_MAIN_CURRENT       = "SearchMainCurrent",
  SEARCH_MAIN_PRESENT       = "SearchMainPresent",
  SEARCH_MAIN_PRESENT_CUR   = "SearchMainPresentCur",
  SEARCH_MAIN_SELECTED      = "SearchMainSelected",
  SEARCH_MAIN_SELECTED_CUR  = "SearchMainSelectedCur",
  -- stylua: ignore end
}

-- stylua: ignore start
local sd = vim.fn.sign_define
sd(M.sign.DAP_BREAKPOINT,              { text = eve.icon.dap.Breakpoint,          texthl = "DapBreakpoint",          linehl = "DapBreakpointLine",          numhl = "DapBreakpointNum",          })
sd(M.sign.DAP_BREAKPOINT_CONDITION,    { text = eve.icon.dap.BreakpointCondition, texthl = "DapBreakpointCondition", linehl = "DapBreakpointConditionLine", numhl = "DapBreakpointConditionNum", })
sd(M.sign.DAP_BREAKPOINT_REJECTED,     { text = eve.icon.dap.BreakpointRejected,  texthl = "DapBreakpointRejected",  linehl = "DapBreakpointRejectedLine",  numhl = "DapBreakpointRejectedNum",  })
sd(M.sign.DAP_LOG_POINT,               { text = eve.icon.dap.LogPoint,            texthl = "DapLogPoint",            linehl = "DapLogPointLine",            numhl = "DapLogPointNum",            })
sd(M.sign.DAP_STOPPED,                 { text = eve.icon.dap.Stopped,             texthl = "DapStopped",             linehl = "DapStoppedLine",             numhl = "DapStoppedNum",             })

sd(M.sign.SEARCH_INPUT_CURSOR,         { text = eve.icon.ui.Telescope,            texthl = "fs_input_prompt"      })
sd(M.sign.SEARCH_MAIN_CURRENT,         { text = ' ',                              texthl = "fs_main_current"      })
sd(M.sign.SEARCH_MAIN_PRESENT,         { text = eve.icon.ui.ArrowPresent,         texthl = "fs_main_present"      })
sd(M.sign.SEARCH_MAIN_PRESENT_CUR,     { text = eve.icon.ui.ArrowPresent,         texthl = "fs_main_present_cur"  })
sd(M.sign.SEARCH_MAIN_SELECTED,        { text = eve.icon.ui.Selected,             texthl = "fs_main_selected"     })
sd(M.sign.SEARCH_MAIN_SELECTED_CUR,    { text = eve.icon.ui.Selected,             texthl = "fs_main_selected_cur" })
-- stylua: ignore end

return M
