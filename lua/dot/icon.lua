---@class dot.icon
local M = {}

---@class dot.icon.digits_subscript
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

---@class dot.icon.digits_supscript
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

---@class dot.icon.fillchars
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

---@class dot.icon.listchars
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

---@class dot.icon.symbols
M.symbols = {
  flag_buffer = "",
  flag_case_sensitive = "",
  flag_exclude = "",
  flag_fold_empty_path = "",
  flag_fuzzy = "",
  flag_gitignore = "",
  flag_hidden = "󰘓",
  flag_included = "󱣬",
  flag_list = "",
  flag_regex = "󰑑",
  flag_replace = "",
  flag_reset = "󰝳",
  flag_selected = "󰔡",
  flag_textonly = "󱄽",
  flag_tree = "",
  sep_left = "",
  sep_right = "",
  selection = "▎",
  selection_copy = "󰆏",
  selection_cut = "󰆐",
  setting = "",
}

---@class dot.icon.status
M.status = {
  attached = "󰖩",
  broadcast = "󰐼",
  detached = "󰖪",
}

----------------------------------------------------------------------------------------------------

---@class dot.icon.app
M.app = {
  Copilot = "",
  CopilotError = "",
  CopilotWarn = "",
  Neovim = "",
  Vim = "",
}

---@class dot.icon.filetype
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

---@class dot.icon.lang
M.lang = {
  python = " ",
}

---@class dot.icon.os
M.os = {
  dos = "",
  mac = "",
  nix = "",
  wsl = "",
  unknown = "",
  current = (ark.env.IS_NIX and "")
    or (ark.env.IS_MAC and "")
    or (ark.env.IS_WIN and "")
    or (ark.env.IS_WSL and "")
    or "",
}

----------------------------------------------------------------------------------------------------

---@class dot.icon.dap
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

---@class dot.icon.diagnostic
M.diagnostic = {
  ERROR = "",
  WARN = "",
  INFO = "",
  HINT = "󱧢",

  Error = "",
  Error_alt = "",
  Hint = "󱧡",
  Hint_alt = "󱧢",
  Information = "",
  Information_alt = "",
  Question = "",
  Question_alt = "",
  Warning = "",
  Warning_alt = "",
}

---@class dot.icon.git
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

---@class dot.icon.kind
M.kind = {
  Array = "󰅪",
  Boolean = "󰨙",
  Calendar = "",
  Class = "",
  Codeium = "󰘦",
  Collapsed = M.fillchars.foldclose,
  Color = "",
  Constant = "󰏿",
  Constructor = "",
  Control = "",
  Copilot = M.app.Copilot,
  Enum = "",
  EnumMember = "",
  Event = "",
  Field = "",
  File = "",
  Folder = "",
  Fragment = "",
  Function = "󰊕",
  Interface = "",
  Implementation = "",
  Key = "",
  Keyword = "",
  Macro = "",
  Method = "󰊕",
  Module = "",
  Namespace = "󰦮",
  Null = "󰟢",
  Number = "󰎠",
  Object = "󰅩",
  Operator = "",
  Package = "",
  Parameter = "",
  Property = "",
  Reference = "",
  Snippet = "󱄽",
  StaticMethod = "",
  String = "",
  Struct = "󰙅",
  Table = "",
  TabNine = "󰏚",
  Tag = "",
  Text = "󰉿",
  TypeAlias = "",
  TypeParameter = "",
  Undefined = "",
  Unit = "",
  Unknown = "󰞋",
  Value = "",
  Variable = "󰀫",
  Watch = "󰥔",
}

---@class dot.icon.log
M.loglevel = {
  TRACE = "",
  DEBUG = "",
  INFO = "",
  WARN = "",
  ERROR = "",
}

---@class dot.icon.notepad
M.notepad = {
  Notebook = "󰠮",
  Source = "",
}

---@class dot.icon.ui
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
  SelectedCurrent = "󰞘",
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
