local sd = vim.fn.sign_define

---@class eve.constant.sign
local M = {}

M.NR_SEARCH_MAIN_CURRENT = 2333
M.NR_SEARCH_MAIN_PRESENT = 2334
M.NR_SEARCH_MAIN_SELECTED = 2335

M.GROUP_SEARCH_MAIN_SELECTED = "GROUP_SEARCH_MAIN_SELECTED"

M.DAP_BREAKPOINT = "DapBreakpoint"
M.DAP_BREAKPOINT_CONDITION = "DapBreakpointCondition"
M.DAP_BREAKPOINT_REJECTED = "DapBreakpointRejected"
M.DAP_LOG_POINT = "DapLogPoint"
M.DAP_STOPPED = "DapStopped"

M.SEARCH_INPUT_CURSOR = "SIGN_SEARCH_INPUT_CURSOR"
M.SEARCH_MAIN_CURRENT = "SIGN_SEARCH_MAIN_CURRENT"
M.SEARCH_MAIN_PRESENT = "SIGN_SEARCH_MAIN_PRESENT"
M.SEARCH_MAIN_PRESENT_CUR = "SIGN_SEARCH_MAIN_PRESENT_CUR"
M.SEARCH_MAIN_SELECTED = "SIGN_SEARCH_MAIN_SELECTED"
M.SEARCH_MAIN_SELECTED_CUR = "SEARCH_MAIN_SELECTED_CUR"

-- stylua: ignore start
sd(M.DAP_BREAKPOINT,              { text = eve.icon.dap.Breakpoint,          texthl = "DapBreakpoint",          linehl = "DapBreakpointLine",          numhl = "DapBreakpointNum",          })
sd(M.DAP_BREAKPOINT_CONDITION,    { text = eve.icon.dap.BreakpointCondition, texthl = "DapBreakpointCondition", linehl = "DapBreakpointConditionLine", numhl = "DapBreakpointConditionNum", })
sd(M.DAP_BREAKPOINT_REJECTED,     { text = eve.icon.dap.BreakpointRejected,  texthl = "DapBreakpointRejected",  linehl = "DapBreakpointRejectedLine",  numhl = "DapBreakpointRejectedNum",  })
sd(M.DAP_LOG_POINT,               { text = eve.icon.dap.LogPoint,            texthl = "DapLogPoint",            linehl = "DapLogPointLine",            numhl = "DapLogPointNum",            })
sd(M.DAP_STOPPED,                 { text = eve.icon.dap.Stopped,             texthl = "DapStopped",             linehl = "DapStoppedLine",             numhl = "DapStoppedNum",             })

sd(M.SEARCH_INPUT_CURSOR,         { text = eve.icon.ui.Telescope,            texthl = "fs_input_prompt"      })
sd(M.SEARCH_MAIN_CURRENT,         { text = ' ',                           texthl = "fs_main_current"      })
sd(M.SEARCH_MAIN_PRESENT,         { text = eve.icon.ui.ArrowPresent,         texthl = "fs_main_present"      })
sd(M.SEARCH_MAIN_PRESENT_CUR,     { text = eve.icon.ui.ArrowPresent,         texthl = "fs_main_present_cur"  })
sd(M.SEARCH_MAIN_SELECTED,        { text = eve.icon.ui.Selected,             texthl = "fs_main_selected"     })
sd(M.SEARCH_MAIN_SELECTED_CUR,    { text = eve.icon.ui.Selected,             texthl = "fs_main_selected_cur" })
-- stylua: ignore end

return M
