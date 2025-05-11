---@class eve.builtin.icon
local M = {}

---@class eve.builtin.icon.digits_subscript
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

---@class eve.builtin.icon.digits_supscript
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

---@class eve.builtin.icon.fillchars
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

---@class eve.builtin.icon.listchars
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

---@class eve.builtin.icon.symbols
M.symbols = {
  setting = "",
  flag_case_sensitive = "",
  flag_exclude = "",
  flag_fold_empty_path = "",
  flag_fuzzy = "",
  flag_gitignore = "",
  flag_included = "󱣬",
  flag_regex = "󰑑",
  flag_replace = "",
  flag_reset = "󰝳",
  flag_selected = "󰔡",
  sep_left = "",
  sep_right = "",
}

----------------------------------------------------------------------------------------------------

---@class eve.builtin.icon.app
M.app = {
  Copilot = "",
  CopilotError = "",
  CopilotWarn = "",
  Neovim = "",
  Vim = "",
}

---@class eve.builtin.icon.filetype
M.filetype = {
  Default = "",
  File = "",
  Files = "",
  FileTree = "󰙅",
  Folder = "󰉋",
  FolderEmptyOpen = "",
  FolderOpen = "",
  FolderRootOpened = "",
  FolderWithHeart = "󱃪",
  Import = "",
  Symlink = "",
  Unknown = "󰈚",
}

---@class eve.builtin.icon.lang
M.lang = {
  python = " ",
}

---@class eve.builtin.icon.os
M.os = {
  dos = "",
  mac = "",
  nix = "",
  wsl = "",
  unknown = "",
  current = (eve.env.IS_NIX and "")
    or (eve.env.IS_MAC and "")
    or (eve.env.IS_WIN and "")
    or (eve.env.IS_WSL and "")
    or "",
}

----------------------------------------------------------------------------------------------------

---@class eve.builtin.icon.dap
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

---@class eve.builtin.icon.diagnostic
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

---@class eve.builtin.icon.git
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

---@class eve.builtin.icon.kind
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

---@class eve.builtin.icon.log
M.loglevel = {
  TRACE = "",
  DEBUG = "",
  INFO = "",
  WARN = "",
  ERROR = "",
}

---@class eve.builtin.icon.ui
M.ui = {
  Accepted = "",
  ArrowClosed = "",
  ArrowOpen = "",
  ArrowPresent = "",
  BigCircle = "",
  BigUnfilledCircle = "",
  BookMark = "󰃃",
  Buffer = "",
  Bug = "",
  Calendar = "",
  Character = "",
  Check = "󰄳",
  Circle = "",
  Close = "󰅖",
  Close_alt = "",
  CloudDownload = "",
  Cmdline = "",
  CodeAction = "󰌵",
  Comment = "󰅺",
  Dashboard = "",
  Edit = "",
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
  SearchForward = "",
  SearchBackward = "",
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
  Terminal = "",
  Window = "",
}

return M
