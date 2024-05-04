---@class  ghc.core.action.search
local M = {}

M.grep_string = require("ghc.core.action.search.grep_string").grep_string

M.live_grep_with_args_workspace = require("ghc.core.action.search.live_grep").live_grep_with_args_workspace
M.live_grep_with_args_cwd = require("ghc.core.action.search.live_grep").live_grep_with_args_cwd
M.live_grep_with_args_current = require("ghc.core.action.search.live_grep").live_grep_with_args_current

return M
