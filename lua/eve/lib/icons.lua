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

---@class eve.lib.icons.kind
M.kind = {
  Array = "󰅪",
  Boolean = "󰨙",
  Calendar = "",
  Class = "",
  Codeium = "",
  Collapsed = M.fillchars.foldclose,
  Color = "",
  Constant = "󰏿",
  Constructor = "",
  Control = "",
  Copilot = "",
  Enum = "",
  EnumMember = "",
  Event = "",
  Field = "", --"󰇽",
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
  Property = "",
  Reference = "",
  Snippet = "",
  StaticMethod = "",
  String = "󰀬",
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

---@class eve.lib.icons.documents
M.documents = {
  Default = "",
  File = "",
  Files = "",
  FileTree = "󰙅",
  Import = "",
  Symlink = "",
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
  Untracked = "󰄱", -- "󰞋",
  Unstaged = "",
  Staged = "",
  Conflict = "",
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

---@class eve.lib.icons.ui
M.ui = {
  Accepted = "",
  ArrowClosed = "",
  ArrowOpen = "",
  ArrowPresent = "",
  BigCircle = "",
  BigUnfilledCircle = "",
  BookMark = "󰃃",
  Buffer = "󰓩",
  Bug = "",
  Calendar = "",
  Character = "",
  Check = "󰄳",
  ChevronDown = "",
  ChevronRight = "",
  Circle = "",
  Close = "󰅖",
  Close_alt = "",
  CloudDownload = "",
  CodeAction = "󰌵",
  Comment = "󰅺",
  Dashboard = "",
  Emoji = "󰱫",
  EmptyFolder = "",
  EmptyFolderOpen = "",
  Explorer = "",
  File = "󰈤",
  Fire = "",
  Folder = "",
  FolderOpen = "",
  FolderWithHeart = "󱃪",
  Gear = "",
  History = "󰄉",
  Incoming = "󰏷",
  Indicator = "",
  Keyboard = "",
  Left = "",
  List = "",
  Location = "",
  Square = "",
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
  RootFolderOpened = "",
  Search = "󰍉",
  Separator = "",
  DoubleSeparator = "󰄾",
  SignIn = "",
  SignOut = "",
  Sort = "",
  Spell = "󰓆",
  Symlink = "",
  Tab = "",
  Table = "",
  Telescope = "",
  Window = "",
}

---@class eve.lib.icons.diagnostics
M.diagnostics = {
  Error = "",
  Warning = "",
  Information = "",
  Question = "",
  Hint = "󰌵", -- 󰛩
  -- Holo version
  Error_alt = "󰅚",
  Warning_alt = "󰀪",
  Information_alt = "",
  Question_alt = "",
  Hint_alt = "󰌶",
}

---@class eve.lib.icons.misc
M.misc = {
  Campass = "󰀹",
  Code = "",
  Gavel = "",
  Glass = "󰂖",
  NoActiveLsp = "󱚧",
  PyEnv = "󰢩",
  Separator_left = "",
  Separator_right = "",
  Squirrel = "",
  Tag = "",
  Tree = "",
  Watch = "",
  Lego = "",
  LspAvailable = "󱜙",
  Vbar = "│",
  Add = "+",
  Added = "",
  Ghost = "󰊠",
  ManUp = "",
  Neovim = "",
  Vim = "",
}

---@class eve.lib.icons.cmp
M.cmp = {
  buffer = "",
  cmp_tabnine = "",
  codeium = "",
  copilot = "",
  copilot_error = "",
  copilot_warn = "",
  latex_symbols = "",
  snippet = "󰃐",
  nvim_lsp = "",
  nvim_lua = "",
  orgmode = "",
  path = "",
  spell = "󰓆",
  tmux = "",
  treesitter = "",
  undefined = "",
}

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

return M
