local env = require("eve.lib.env")

---@class eve.lib.icons
local M = {}

---@class eve.lib.icons.fillchars
M.fillchars = {
  diff = " ",
  eob = " ",
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  msgsep = "─",
  vert = "│",
}

---@class eve.lib.icons.listchars
M.listchars = {
  eol = "↲",
  extends = "»",
  lead = " ",
  nbsp = "·",
  precedes = "«",
  space = "·",
  tab = " ",
  trail = "•",
}

---@class eve.lib.icons.symbols
M.symbols = {
  flag_fuzzy = "󰫳",
  flag_case_sensitive = "",
  flag_gitignore = "",
  flag_regex = "󰑑",
  flag_replace = "",
}

----------------------------------------------------------------------------------------------------

---@class eve.lib.icons.app
M.app = {
  Copilot = "",
  CopilotError = "",
  CopilotWarn = "",
  Neovim = "",
  Vim = "",
}

---@class eve.lib.icons.ft
M.ft = {
  Default = "",
  File = "",
  Files = "",
  FileTree = "󰙅",
  Folder = "",
  FolderEmpty = "",
  FolderEmptyOpen = "",
  FolderOpen = "",
  FolderRootOpened = "",
  FolderWithHeart = "󱃪",
  Import = "",
  Symlink = "",
}

---@class eve.lib.icons.os
M.os = {
  dos = "",
  mac = "",
  nix = "",
  wsl = "",
  unknown = "",
  current = (env.IS_NIX and "")
    or (env.IS_MAC and "")
    or (env.IS_WIN and "")
    or (env.IS_WSL and "")
    or "",
}

----------------------------------------------------------------------------------------------------

---@class eve.lib.icons.dap
M.dap = {
  Breakpoint = "",
  BreakpointCondition = "",
  BreakpointRejected = "",
  LogPoint = ".>",
  Pause = "",
  Play = "",
  RunLast = "↻",
  StepBack = "",
  StepInto = "󰆹",
  StepOut = "󰆸",
  StepOver = "󰆷",
  Stopped = "",
  Terminate = "󰝤",
}

---@class eve.lib.icons.diagnostic
M.diagnostic = {
  Error = "",
  Error_alt = "󰅚",
  Hint = "󰌵", -- 󰛩
  Hint_alt = "󰌶",
  Information = "",
  Information_alt = "",
  Question = "",
  Question_alt = "",
  Warning = "",
  Warning_alt = "󰀪",
}

---@class eve.lib.icons.git
M.git = {
  Add = "",
  Branch = "",
  Diff = "",
  Git = "󰊢",
  Ignore = "",
  Mod = "M",
  Mod_alt = "",
  Remove = "",
  Rename = "",
  Repo = "",
  Unmerged = "󰘬",
  Untracked = "󰄱",
  Unstaged = "",
  Staged = "",
  Conflict = "",
}

----------------------------------------------------------------------------------------------------

---@class eve.lib.icons.kind
M.kind = {
  Array = "󰅪",
  Boolean = "󰨙",
  Calendar = "",
  Class = "",
  Codeium = "󰘦",
  Collapsed = M.fillchars.foldclose,
  Color = "",
  Constant = "󰏿",
  Constructor = "",
  Control = "",
  Copilot = M.app.Copilot,
  Enum = "",
  EnumMember = "",
  Event = "",
  Field = "",
  File = "",
  Folder = "󰉋",
  Fragment = "",
  Function = "󰊕",
  Interface = "",
  Implementation = "",
  Key = "",
  Keyword = "",
  Macro = "",
  Method = "󰊕",
  Module = "",
  Namespace = "󰦮",
  Null = "󰟢",
  Number = "󰎠",
  Object = "󰅩",
  Operator = "",
  Package = "",
  Parameter = "",
  Property = "",
  Reference = "",
  Snippet = "󱄽",
  StaticMethod = "",
  String = "",
  Struct = "󰙅",
  Supermaven = "",
  Table = "",
  TabNine = "󰏚",
  Tag = "",
  Text = "󰉿",
  TypeAlias = "",
  TypeParameter = "",
  Undefined = "",
  Unit = "",
  Value = "",
  Variable = "󰀫",
  Watch = "󰥔",
}

---@class eve.lib.icons.ui
M.ui = {
  Accepted = "",
  ArrowClosed = "",
  ArrowOpen = "",
  ArrowPresent = "",
  BigCircle = "",
  BigUnfilledCircle = "",
  BookMark = "󰃃",
  buffer = "",
  Bug = "",
  Calendar = "",
  Character = "",
  Check = "󰄳",
  Circle = "",
  Close = "󰅖",
  Close_alt = "",
  CloudDownload = "",
  CodeAction = "󰌵",
  Comment = "󰅺",
  Dashboard = "",
  Emoji = "󰱫",
  Fire = "",
  Gear = "",
  History = "󰄉",
  Incoming = "󰏷",
  Indicator = "",
  Keyboard = "",
  Left = "",
  List = "",
  Location = "",
  SymlinkFolder = "",
  Lock = "󰍁",
  Modified = "✥",
  Modified_alt = "",
  NewFile = "",
  Newspaper = "",
  Note = "󰍨",
  Outgoing = "󰏻",
  Package = "",
  Pencil = "󰏫",
  Perf = "󰅒",
  Play = "",
  Project = "",
  Right = "",
  Search = "󰍉",
  Separator = "",
  DoubleSeparator = "󰄾",
  SignIn = "",
  SignOut = "",
  Sort = "",
  Spell = "󰓆",
  Tab = "",
  Table = "",
  Telescope = "",
  Window = "",
}

return M
