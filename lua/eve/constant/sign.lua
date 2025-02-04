local icons = require("eve.constant.icon")
local sd = vim.fn.sign_define

---@class eve.constant.sign
local M = {}

M.NR_SEARCH_MAIN_CURRENT = 2333
M.NR_SEARCH_MAIN_PRESENT = 2334
M.NR_SEARCH_MAIN_SELECTED = 2335

M.DAP_BREAKPOINT = "DapBreakpoint"
M.DAP_BREAKPOINT_CONDITION = "DapBreakpointCondition"
M.DAP_BREAKPOINT_REJECTED = "DapBreakpointRejected"
M.DAP_LOG_POINT = "DapLogPoint"
M.DAP_PAUSE = "DapPause"
M.DAP_PLAY = "DapPlay"
M.DAP_RUN_LAST = "DapRunLast"
M.DAP_STEP_BACK = "DapStepBack"
M.DAP_STEP_INTO = "DapStepInto"
M.DAP_STEP_OUT = "DapStepOut"
M.DAP_STEP_OVER = "DapStepOver"
M.DAP_STOPPED = "DapStopped"
M.DAP_TERMINATE = "DapTerminate"

M.SEARCH_INPUT_CURSOR = "SIGN_SEARCH_INPUT_CURSOR"
M.SEARCH_MAIN_CURRENT = "SIGN_SEARCH_MAIN_CURRENT"
M.SEARCH_MAIN_PRESENT = "SIGN_SEARCH_MAIN_PRESENT"
M.SEARCH_MAIN_PRESENT_CUR = "SIGN_SEARCH_MAIN_PRESENT_CUR"

M.SELECT_INPUT_CURSOR = "SIGN_SELECT_INPUT_CURSOR"
M.SELECT_MAIN_CURRENT = "SIGN_SELECT_MAIN_CURRENT"

-- stylua: ignore start
sd(M.DAP_BREAKPOINT,              { text = icons.dap.Breakpoint,          texthl = "f_dap_breakpoint",            linehl = "f_dap_breakpoint_line",           numhl = "f_dap_breakpoint_lnum",           })
sd(M.DAP_BREAKPOINT_CONDITION,    { text = icons.dap.BreakpointCondition, texthl = "f_dap_breakpoint_condition",  linehl = "f_dap_breakpoint_condition_line", numhl = "f_dap_breakpoint_condition_lnum", })
sd(M.DAP_BREAKPOINT_REJECTED,     { text = icons.dap.BreakpointRejected,  texthl = "f_dap_breakpoint_rejected",   linehl = "f_dap_breakpoint_rejected_line",  numhl = "f_dap_breakpoint_rejected_lnum",  })
sd(M.DAP_LOG_POINT,               { text = icons.dap.LogPoint,            texthl = "f_dap_log_pint",              linehl = "f_dap_log_pint_line",             numhl = "f_dap_log_pint_lnum",             })
sd(M.DAP_PAUSE,                   { text = icons.dap.Pause,               texthl = "f_dap_pause",                 linehl = "f_dap_pause_line",                numhl = "f_dap_pause_lnum",                })
sd(M.DAP_PLAY,                    { text = icons.dap.Breakpoint,          texthl = "f_dap_play",                  linehl = "f_dap_play_line",                 numhl = "f_dap_play_lnum",                 })
sd(M.DAP_RUN_LAST,                { text = icons.dap.Breakpoint,          texthl = "f_dap_run_last",              linehl = "f_dap_run_last_line",             numhl = "f_dap_run_last_lnum",             })
sd(M.DAP_STEP_BACK,               { text = icons.dap.Breakpoint,          texthl = "f_dap_step_back",             linehl = "f_dap_step_back_line",            numhl = "f_dap_step_back_lnum",            })
sd(M.DAP_STEP_INTO,               { text = icons.dap.Breakpoint,          texthl = "f_dap_step_into",             linehl = "f_dap_step_into_line",            numhl = "f_dap_step_into_lnum",            })
sd(M.DAP_STEP_OUT,                { text = icons.dap.Breakpoint,          texthl = "f_dap_step_out",              linehl = "f_dap_step_out_line",             numhl = "f_dap_step_out_lnum",             })
sd(M.DAP_STEP_OVER,               { text = icons.dap.Breakpoint,          texthl = "f_dap_step_over",             linehl = "f_dap_step_over_line",            numhl = "f_dap_step_over_lnum",            })
sd(M.DAP_STOPPED,                 { text = icons.dap.Breakpoint,          texthl = "f_dap_stopped",               linehl = "f_dap_stopped_line",              numhl = "f_dap_stopped_lnum",              })
sd(M.DAP_TERMINATE,               { text = icons.dap.Breakpoint,          texthl = "f_dap_terminate",             linehl = "f_dap_terminate_line",            numhl = "f_dap_terminate_lnum",            })

sd(M.SEARCH_INPUT_CURSOR,         { text = icons.ui.Telescope,            texthl = "fs_input_prompt"      })
sd(M.SEARCH_MAIN_CURRENT,         { text = icons.ui.ArrowPresent,         texthl = "fs_main_current"      })
sd(M.SEARCH_MAIN_PRESENT,         { text = icons.ui.ArrowPresent,         texthl = "fs_main_present"      })
sd(M.SEARCH_MAIN_PRESENT_CUR,     { text = icons.ui.ArrowPresent,         texthl = "fs_main_present_cur"  })
sd(M.SEARCH_MAIN_SELECTED,        { text = icons.ui.Selected,               texthl = "fs_main_selected"     })

sd(M.SELECT_INPUT_CURSOR,         { text = icons.ui.Telescope,            texthl = "fs_input_prompt"      })
sd(M.SELECT_MAIN_CURRENT,         { text = icons.ui.ArrowClosed,          texthl = "fs_main_current"      })
-- stylua: ignore end

return M
