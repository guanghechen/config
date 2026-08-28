----------------------------------------------------------------------------------------------------
-- stl.e: Centralized enum and enum set definitions
----------------------------------------------------------------------------------------------------

---@class stl.e
local M = {}

----------------------------------------------------------------------------------------------------
-- BoxPositionEnum
----------------------------------------------------------------------------------------------------

---@class stl.e.IBoxPositionEnum
M.BoxPositionEnum = {
  CURSOR = "cursor",
  CENTER = "center",
}

----------------------------------------------------------------------------------------------------
-- LogLevelEnum
----------------------------------------------------------------------------------------------------

---@class stl.e.ILogLevelEnum
M.LogLevelEnum = {
  TRACE = "TRACE",
  DEBUG = "DEBUG",
  INFO = "INFO",
  WARN = "WARN",
  ERROR = "ERROR",
}

----------------------------------------------------------------------------------------------------
-- NvimbarPositionEnum
----------------------------------------------------------------------------------------------------

---@class stl.e.INvimbarPositionEnum
M.NvimbarPositionEnum = {
  -- stylua: ignore start
  F_SL = "f_sl",                                -- statusline
  F_TL = "f_tl",                                -- tabline
  F_WL = "f_wl",                                -- winbar
  -- stylua: ignore end
}

----------------------------------------------------------------------------------------------------
-- VimModeEnum
----------------------------------------------------------------------------------------------------

---@class stl.e.IVimModeEnum
M.VimModeEnum = {
  -- stylua: ignore start
  C = "c",                                      -- cmdline-mode
  I = "i",                                      -- insert-mode
  N = "n",                                      -- normal-mode
  O = "o",                                      -- operator-pending-mode
  S = "s",                                      -- select-mode
  S_LINE = "S",                                 -- select-line-mode
  T = "t",                                      -- terminal-mode
  V = "v",                                      -- visual-mode
  V_LINE = "V",                                 -- visual-line-mode
  X = "x",                                      -- visual-block-mode
  -- stylua: ignore end
}

----------------------------------------------------------------------------------------------------
-- VimModeNameEnum
----------------------------------------------------------------------------------------------------

---@class stl.e.IVimModeNameEnum
M.VimModeNameEnum = {
  -- stylua: ignore start
  NORMAL   = "normal",
  VISUAL   = "visual",
  INSERT   = "insert",
  TERMINAL = "terminal",
  NTERMINAL = "nterminal",
  REPLACE  = "replace",
  CONFIRM  = "confirm",
  COMMAND  = "command",
  SELECT   = "select",
  -- stylua: ignore end
}

----------------------------------------------------------------------------------------------------
-- TabTypeEnum
----------------------------------------------------------------------------------------------------

---@class stl.e.ITabTypeEnum
M.TabTypeEnum = {
  -- stylua: ignore start
  DIFFVIEW_COMMITS   = "diffview_commits",
  DIFFVIEW_WORKSPACE = "diffview_workspace",
  NORMAL             = "normal",
  -- stylua: ignore end
}

---@class stl.e.ITabTypeSet
M.TabTypeSet = {
  ALL = {
    M.TabTypeEnum.NORMAL,
    M.TabTypeEnum.DIFFVIEW_COMMITS,
    M.TabTypeEnum.DIFFVIEW_WORKSPACE,
  },
  DIFFVIEW = {
    M.TabTypeEnum.DIFFVIEW_COMMITS,
    M.TabTypeEnum.DIFFVIEW_WORKSPACE,
  },
  DIFFVIEW_COMMITS = { M.TabTypeEnum.DIFFVIEW_COMMITS },
  DIFFVIEW_WORKSPACE = { M.TabTypeEnum.DIFFVIEW_WORKSPACE },
  NORMAL = { M.TabTypeEnum.NORMAL },
}

----------------------------------------------------------------------------------------------------
-- WinTypeEnum
----------------------------------------------------------------------------------------------------

---@class stl.e.IWinTypeEnum
M.WinTypeEnum = {
  -- stylua: ignore start
  BOARD             = "ux:board",
  CMDLINE           = "ux:cmdline",
  EXPLORER          = "ux:explorer",
  INPUT             = "ux:input",
  NOTIFY            = "ux:notify",
  PICKER_FINDER     = "ux:picker-finder",
  PICKER_PREVIEW    = "ux:picker-preview",
  PICKER_RESULT     = "ux:picker-result",
  POPUPMENU         = "ux:popupmenu",
  SEARCHER_FINDER   = "ux:searcher-finder",
  SEARCHER_PREVIEW  = "ux:searcher-preview",
  SEARCHER_RESULT   = "ux:searcher-result",
  SELECT            = "ux:select",
  TERMINAL          = "ux:terminal",
  TEXTAREA          = "ux:textarea",
  WINPICKER         = "ux:winpicker",
  WINSEP            = "ux:winsep",
  -- stylua: ignore end
}

return M
