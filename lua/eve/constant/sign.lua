local icons = require("eve.constant.icon")
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
sd(M.DAP_BREAKPOINT,              { text = icons.dap.Breakpoint,          texthl = "DapBreakpoint",          linehl = "DapBreakpointLhl",           numhl = "DapBreakpointNhl",          })
sd(M.DAP_BREAKPOINT_CONDITION,    { text = icons.dap.BreakpointCondition, texthl = "DapBreakpointCondition", linehl = "DapBreakpointConditionLhl",  numhl = "DapBreakpointConditionNhl", })
sd(M.DAP_BREAKPOINT_REJECTED,     { text = icons.dap.BreakpointRejected,  texthl = "DapBreakpointRejected",  linehl = "DapBreakpointRejectedLhl",   numhl = "DapBreakpointRejectedNhl",  })
sd(M.DAP_LOG_POINT,               { text = icons.dap.LogPoint,            texthl = "DapLogPoint",            linehl = "DapLogPointLhl",             numhl = "DapLogPointNhl",            })
sd(M.DAP_STOPPED,                 { text = icons.dap.Stopped,             texthl = "DapStopped",             linehl = "DapStoppedLhl",              numhl = "DapStoppedNhl",             })

sd(M.SEARCH_INPUT_CURSOR,         { text = icons.ui.Telescope,            texthl = "fs_input_prompt"      })
sd(M.SEARCH_MAIN_CURRENT,         { text = ' ',                           texthl = "fs_main_current"      })
sd(M.SEARCH_MAIN_PRESENT,         { text = icons.ui.ArrowPresent,         texthl = "fs_main_present"      })
sd(M.SEARCH_MAIN_PRESENT_CUR,     { text = icons.ui.ArrowPresent,         texthl = "fs_main_present_cur"  })
sd(M.SEARCH_MAIN_SELECTED,        { text = icons.ui.Selected,             texthl = "fs_main_selected"     })
sd(M.SEARCH_MAIN_SELECTED_CUR,    { text = icons.ui.Selected,             texthl = "fs_main_selected_cur" })
-- stylua: ignore end

return M
