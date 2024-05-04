---@class  ghc.core.action.search
local M = {}

M.grep_selected_text_workspace = require("ghc.core.action.search.grep_string").grep_selected_text_workspace
M.grep_selected_text_cwd = require("ghc.core.action.search.grep_string").grep_selected_text_cwd
M.grep_selected_text_current = require("ghc.core.action.search.grep_string").grep_selected_text_current

M.live_grep_with_args_workspace = require("ghc.core.action.search.live_grep").live_grep_with_args_workspace
M.live_grep_with_args_cwd = require("ghc.core.action.search.live_grep").live_grep_with_args_cwd
M.live_grep_with_args_current = require("ghc.core.action.search.live_grep").live_grep_with_args_current

return M
