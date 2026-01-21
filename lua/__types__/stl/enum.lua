---@meta

----------------------------------------------------------------------------------------------------
-- BoxPositionEnum
----------------------------------------------------------------------------------------------------

---@alias stl.t.BoxPositionEnum
---| "cursor"
---| "center"

---@class stl.e.IBoxPositionEnum
---@field public CURSOR                 "cursor"
---@field public CENTER                 "center"

----------------------------------------------------------------------------------------------------
-- LogLevelEnum
----------------------------------------------------------------------------------------------------

---@alias stl.t.LogLevelEnum
---| "TRACE"
---| "DEBUG"
---| "INFO"
---| "WARN"
---| "ERROR"

---@class stl.e.ILogLevelEnum
---@field public TRACE                  "TRACE"
---@field public DEBUG                  "DEBUG"
---@field public INFO                   "INFO"
---@field public WARN                   "WARN"
---@field public ERROR                  "ERROR"

----------------------------------------------------------------------------------------------------
-- NvimbarPositionEnum
----------------------------------------------------------------------------------------------------

---@alias stl.t.NvimbarPositionEnum
---| "f_sl"
---| "f_tl"
---| "f_wl"

---@class stl.e.INvimbarPositionEnum
---@field public F_SL                   "f_sl"
---@field public F_TL                   "f_tl"
---@field public F_WL                   "f_wl"

----------------------------------------------------------------------------------------------------
-- VimModeEnum
----------------------------------------------------------------------------------------------------

---@alias stl.t.VimModeEnum
---| "c"
---| "i"
---| "n"
---| "o"
---| "s"
---| "S"
---| "t"
---| "v"
---| "V"
---| "x"

---@class stl.e.IVimModeEnum
---@field public C                      "c"
---@field public I                      "i"
---@field public N                      "n"
---@field public O                      "o"
---@field public S                      "s"
---@field public S_LINE                 "S"
---@field public T                      "t"
---@field public V                      "v"
---@field public V_LINE                 "V"
---@field public X                      "x"

----------------------------------------------------------------------------------------------------
-- VimModeNameEnum
----------------------------------------------------------------------------------------------------

---@alias stl.t.VimModeNameEnum
---| "normal"
---| "visual"
---| "insert"
---| "terminal"
---| "nterminal"
---| "replace"
---| "confirm"
---| "command"
---| "select"

---@class stl.e.IVimModeNameEnum
---@field public NORMAL                 "normal"
---@field public VISUAL                 "visual"
---@field public INSERT                 "insert"
---@field public TERMINAL               "terminal"
---@field public NTERMINAL              "nterminal"
---@field public REPLACE                "replace"
---@field public CONFIRM                "confirm"
---@field public COMMAND                "command"
---@field public SELECT                 "select"

----------------------------------------------------------------------------------------------------
-- TabTypeEnum
----------------------------------------------------------------------------------------------------

---@alias stl.t.TabTypeEnum
---| "acp"
---| "diffview_commits"
---| "diffview_workspace"
---| "normal"

---@alias stl.e.TabTypeEnum stl.t.TabTypeEnum

---@class stl.e.ITabTypeEnum
---@field public ACP                    "acp"
---@field public DIFFVIEW_COMMITS       "diffview_commits"
---@field public DIFFVIEW_WORKSPACE     "diffview_workspace"
---@field public NORMAL                 "normal"

---@class stl.e.ITabTypeSet
---@field public ACP                    stl.t.TabTypeEnum[]
---@field public ALL                    stl.t.TabTypeEnum[]
---@field public DIFFVIEW               stl.t.TabTypeEnum[]
---@field public DIFFVIEW_COMMITS       stl.t.TabTypeEnum[]
---@field public DIFFVIEW_WORKSPACE     stl.t.TabTypeEnum[]
---@field public NORMAL                 stl.t.TabTypeEnum[]

----------------------------------------------------------------------------------------------------
-- WinTypeEnum
----------------------------------------------------------------------------------------------------

---@alias stl.t.WinTypeEnum
---| "ux:board"
---| "ux:cmdline"
---| "ux:explorer"
---| "ux:input"
---| "ux:notify"
---| "ux:picker-finder"
---| "ux:picker-preview"
---| "ux:picker-result"
---| "ux:popupmenu"
---| "ux:searcher-finder"
---| "ux:searcher-preview"
---| "ux:searcher-result"
---| "ux:select"
---| "ux:terminal"
---| "ux:textarea"
---| "ux:winpicker"
---| "ux:winsep"

---@alias stl.e.WinTypeEnum stl.t.WinTypeEnum

---@class stl.e.IWinTypeEnum
---@field public BOARD                  "ux:board"
---@field public CMDLINE                "ux:cmdline"
---@field public EXPLORER               "ux:explorer"
---@field public INPUT                  "ux:input"
---@field public NOTIFY                 "ux:notify"
---@field public PICKER_FINDER          "ux:picker-finder"
---@field public PICKER_PREVIEW         "ux:picker-preview"
---@field public PICKER_RESULT          "ux:picker-result"
---@field public POPUPMENU              "ux:popupmenu"
---@field public SEARCHER_FINDER        "ux:searcher-finder"
---@field public SEARCHER_PREVIEW       "ux:searcher-preview"
---@field public SEARCHER_RESULT        "ux:searcher-result"
---@field public SELECT                 "ux:select"
---@field public TERMINAL               "ux:terminal"
---@field public TEXTAREA               "ux:textarea"
---@field public WINPICKER              "ux:winpicker"
---@field public WINSEP                 "ux:winsep"
