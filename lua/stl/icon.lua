---@class stl.icon
local M = {}

---@class stl.icon.digits_subscript
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

---@class stl.icon.digits_supscript
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

---@class stl.icon.fillchars
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

---@class stl.icon.listchars
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

---@class stl.icon.keycode
M.keycode = {
  Up = "",
  Down = "",
  Left = "",
  Right = "",
  C = "󰘴",
  M = "󰘵",
  D = "󰘳",
  S = "󰘶",
  ["C-a"] = "󰘳",
  ["C-A"] = "󰘳",
  CR = "󰌑",
  Esc = "󱊷",
  ScrollWheelDown = "󱕐",
  ScrollWheelUp = "󱕑",
  NL = "󰌑",
  BS = "󰁮",
  Space = "󱁐",
  Tab = "",
  F1 = "󱊫",
  F2 = "󱊬",
  F3 = "󱊭",
  F4 = "󱊮",
  F5 = "󱊯",
  F6 = "󱊰",
  F7 = "󱊱",
  F8 = "󱊲",
  F9 = "󱊳",
  F10 = "󱊴",
  F11 = "󱊵",
  F12 = "󱊶",
}

---@class stl.icon.symbols
M.symbols = {
  flag_buffer = "",
  flag_case_sensitive = "",
  flag_exclude = "",
  flag_fold_empty_path = "",
  flag_fold_unchanged = "󰈉",
  flag_fuzzy = "",
  flag_gitignore = "",
  flag_hidden = "󰘓",
  flag_included = "󱣬",
  flag_layout_1 = "󰯌",      -- layout 1: commits_left
  flag_layout_2 = "󰯍",      -- layout 2: commits_top
  flag_layout_3 = "󰕰",      -- layout 3: commits_left_filetree
  flag_layout_4 = "󱂬",      -- layout 4: commits_top_filetree
  flag_layout_5 = "󰤼",      -- layout 5: sbs_only
  flag_layout_left = "󰯌",   -- view-split-vertical (legacy)
  flag_layout_top = "󰯍",    -- view-split-horizontal (legacy)
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

---@class stl.icon.status
M.status = {
  attached = "󰖩",
  broadcast = "󰐼",
  detached = "󰖪",
}

----------------------------------------------------------------------------------------------------

---@class stl.icon.app
M.app = {
  Copilot = "",
  CopilotError = "",
  CopilotWarn = "",
  Neovim = "",
  Vim = "",
}

---@class stl.icon.filetype
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

---@class stl.icon.lang
M.lang = {
  python = " ",
}

---@class stl.icon.os
M.os = {
  dos = "",
  mac = "",
  nix = "",
  wsl = "",
  unknown = "",
  current = (stl.env.IS_NIX and "")
    or (stl.env.IS_OSX and "")
    or (stl.env.IS_WIN and "")
    or (stl.env.IS_WSL and "")
    or "",
}

----------------------------------------------------------------------------------------------------

---@class stl.icon.dap
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

---@class stl.icon.diagnostic
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

---@class stl.icon.git
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

---@class stl.icon.lsp
M.lsp = {
  basedpyright = "",
  bashls = "",
  copilot = M.app.Copilot,
  cssls = "",
  docker_compose_language_service = "",
  dockerls = "",
  emmet_language_server = "",
  eslint = "",
  html = "󰌝",
  jsonls = "",
  lua_ls = "",
  ruff = "󰄛",
  rust_analyzer = "",
  stylua = "󰢱",
  tailwindcss = "󱏿",
  taplo = "",
  vtsls = "󰛦",
  vue_ls = "󰡄",
  yamlls = "",
}

----------------------------------------------------------------------------------------------------

---@class stl.icon.kind
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

---@class stl.icon.log
M.loglevel = {
  TRACE = "",
  DEBUG = "",
  INFO = "",
  WARN = "",
  ERROR = "",
}

---@class stl.icon.notepad
M.notepad = {
  Notebook = "󰠮",
  Source = "",
}

---@class stl.icon.ui
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
  CircleMedium = "●",
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
  Plugin = "",
  Paste = "󰆒",
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
  TabPage = "󰓩",
  Table = "",
  Telescope = "",
  Terminal = "",
  Window = "",
}

return M
