---@class eve.globals.icons
local M = {}

---@class fml.ui.icosn.fillchars
M.fillchars = {
  diff = "╱",
  eob = " ",
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  msgsep = "─",
  vert = "│",
}

---@class eve.globals.icons.listchars
M.listchars = {
  eol = "↲",
  extends = "»",
  lead = "·",
  nbsp = "·",
  precedes = "«",
  space = "·",
  tab = " ",
  trail = "•",
}

---@class eve.globals.icons.symbols
M.symbols = {
  flag_fuzzy = "󰫳",
  flag_case_sensitive = "",
  flag_gitignore = "",
  flag_regex = "󰑑",
  flag_replace = "",
  win_indicator = " ",
  win_indicator_active = "▎",
}

---@class eve.globals.icons.kind
M.kind = {
  Array = "󰅪",
  --Boolean = "",
  Boolean = "◩",
  Calendar = "",
  Class = "",
  Codeium = "",
  Copilot = "",
  Color = "󰏘",
  Constant = "󰏿",
  Constructor = "", -- "",
  Enum = "󰕘",
  EnumMember = "󰕘",
  Event = "",
  Field = "", --"󰇽",
  File = "󰈙",
  Folder = "󰉋",
  Fragment = "",
  Function = "󰊕",
  Interface = "",
  Implementation = "",
  Key = "󰌋",
  Keyword = "",
  Macro = "",
  Method = "󰆧",
  Module = "",
  -- Namespace = "󰌗",
  Namespace = "󰦮",
  Null = "󰟢",
  -- Number = "",
  Number = "󰎠",
  Object = "󰅩",
  Operator = "󰆕",
  Package = "",
  Parameter = "",
  Property = "",
  Reference = "",
  Snippet = "",
  StaticMethod = "",
  String = "󰀬",
  Struct = "󰙅",
  Table = "",
  TabNine = "",
  Tag = "",
  Text = "󰉿",
  TypeAlias = "",
  -- TypeParameter = "󰅲", -- "󰊄",
  TypeParameter = "",
  Undefined = "",
  Unit = "",
  Value = "󰎠",
  Variable = "󰀫", -- "",
  Watch = "󰥔",
}

---@class eve.globals.icons.type
M.type = {
  Array = "󰅪",
  Boolean = "",
  Null = "󰟢",
  Number = "",
  Object = "󰅩",
  String = "󰉿",
}

---@class eve.globals.icons.documents
M.documents = {
  Default = "",
  File = "",
  Files = "",
  FileTree = "󰙅",
  Import = "",
  Symlink = "",
}

---@class eve.globals.icons.git
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

---@class eve.globals.icons.os
M.os = {
  unix = "",
  mac = "",
  dos = "",
  unknown = "",
}

---@class eve.globals.icons.ui
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

---@class eve.globals.icons.diagnostics
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

---@class eve.globals.icons.misc
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

---@class eve.globals.icons.cmp
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

---@class eve.globals.icons.dap
M.dap = {
  Breakpoint = "󰝥",
  BreakpointCondition = "󰟃",
  BreakpointRejected = "",
  LogPoint = "",
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

---@class eve.globals.icons.devicons
M.devicons = {
  default_icon = {
    icon = "󰈚",
    name = "Default",
  },
  dart = {
    icon = "",
    name = "dart",
  },
  deb = {
    icon = "",
    name = "deb",
  },
  Dockerfile = {
    icon = "",
    name = "Dockerfile",
  },
  jpeg = {
    icon = "󰉏",
    name = "jpeg",
  },
  jpg = {
    icon = "󰉏",
    name = "jpg",
  },
  kt = {
    icon = "󱈙",
    name = "kt",
  },
  mp3 = {
    icon = "󰎆",
    name = "mp3",
  },
  mp4 = {
    icon = "",
    name = "mp4",
  },
  out = {
    icon = "",
    name = "out",
  },
  ts = {
    icon = "󰛦",
    name = "ts",
  },
  ttf = {
    icon = "",
    name = "TrueTypeFont",
  },
  rb = {
    icon = "",
    name = "rb",
  },
  rpm = {
    icon = "",
    name = "rpm",
  },
  woff = {
    icon = "",
    name = "WebOpenFontFormat",
  },
  woff2 = {
    icon = "",
    name = "WebOpenFontFormat2",
  },
  xz = {
    icon = "",
    name = "xz",
  },
  zip = {
    icon = "",
    name = "zip",
  },
}

return M