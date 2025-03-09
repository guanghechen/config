local env = require("eve.builtin.env")

---@class eve.constant.icon
local M = {}

---@class eve.constant.icon.digits_subscript
local digits_subscript = {
  "₀",
  "₁",
  "₂",
  "₃",
  "₄",
  "₅",
  "₆",
  "₇",
  "₈",
  "₉",
}

---@class eve.constant.icon.digits_supscript
local digits_supscript = {
  "⁰",
  "¹",
  "²",
  "³",
  "⁴",
  "⁵",
  "⁶",
  "⁷",
  "⁸",
  "⁹",
}

---@param num                           integer
---@return string
function M.todigit_subscript(num)
  local result = "" ---@type string
  while num > 0 do
    local digit = num % 10
    num = math.floor((num - digit) / 10)
    result = digits_subscript[digit + 1] .. result
  end
  return #result > 0 and result or digits_subscript[1]
end

---@param num                           integer
---@return string
function M.todigit_supscript(num)
  local result = "" ---@type string
  while num > 0 do
    local digit = num % 10
    num = math.floor((num - digit) / 10)
    result = digits_supscript[digit + 1] .. result
  end
  return #result > 0 and result or digits_supscript[1]
end

---@class eve.constant.icon.fillchars
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

---@class eve.constant.icon.listchars
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

---@class eve.constant.icon.symbols
M.symbols = {
  setting = "",
  flag_case_sensitive = "",
  flag_exclude = "",
  flag_filter = "",
  flag_fuzzy = "",
  flag_gitignore = "",
  flag_regex = "󰑑",
  flag_replace = "",
  flag_reset = "󰝳",
  flag_selected = "󰔡",
  sep_left = "",
  sep_right = "",
}

----------------------------------------------------------------------------------------------------

---@class eve.constant.icon.app
M.app = {
  Copilot = "",
  CopilotError = "",
  CopilotWarn = "",
  Neovim = "",
  Vim = "",
}

---@class eve.constant.icon.filetype
M.filetype = {
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
  Unknown = "󰈚",
}

---@class eve.constant.icon.lang
M.lang = {
  python = " ",
}

---@class eve.constant.icon.os
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

---@class eve.constant.icon.dap
M.dap = {
  Breakpoint = "",
  BreakpointCondition = "",
  BreakpointRejected = "",
  Disconnect = "",
  LogPoint = ".>",
  Pause = "",
  Play = "",
  RunLast = "↻",
  StepBack = "",
  StepInto = "󰆹",
  StepOut = "󰆸",
  StepOver = "󰆷",
  Stopped = "󰁕",
  Terminate = "󰝤",
}

---@class eve.constant.icon.diagnostic
M.diagnostic = {
  Error = "",
  Error_alt = "󰅚",
  Hint = "",
  Hint_alt = "󰌶",
  Information = "",
  Information_alt = "",
  Question = "",
  Question_alt = "",
  Warning = "",
  Warning_alt = "󰀪",
}

---@class eve.constant.icon.git
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

---@class eve.constant.icon.kind
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

---@class eve.constant.icon.ui
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
  Selected = "▎",
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
