---@class ghc.core.setting.icons
local M = {}

---@class ghc.core.setting.icons.kind
M.kind = {
  Array = "[]",
  --Boolean = "",
  Boolean = "󰨙",
  Calendar = "",
  -- Class = "󰠱",
  Class = "",
  Codeium = "",
  Copilot = "",
  Color = "󰏘",
  Constant = "󰏿",
  Constructor = "",
  Enum = "",
  EnumMember = "",
  Event = "",
  Field = "󰇽",
  File = "󰈙",
  Folder = "󰉋",
  Fragment = "",
  Function = "󰊕",
  Interface = "",
  Implementation = "",
  Key = "",
  Keyword = "",
  Macro = "",
  Method = "󰆧",
  Module = "",
  -- Namespace = "󰌗",
  Namespace = "󰦮",
  Null = "󰟢",
  -- Number = "",
  Number = "󰎠",
  Object = "󰅩",
  Operator = "󰆕",
  Package = "",
  Parameter = "",
  Property = "󰜢",
  Reference = "",
  Snippet = "",
  StaticMethod = "",
  String = "󰉿",
  Struct = "󰙅", --"",
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

---@class ghc.core.setting.icons.type
M.type = {
  Array = "󰅪",
  Boolean = "",
  Null = "󰟢",
  Number = "",
  Object = "󰅩",
  String = "󰉿",
}

---@class ghc.core.setting.icons.documents
M.documents = {
  Default = "",
  File = "",
  Files = "",
  FileTree = "󰙅",
  Import = "",
  Symlink = "",
}

---@class ghc.core.setting.icons.git
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

---@class ghc.core.setting.icons.os
M.os = {
  unix = "",
  mac = "",
  dos = "",
  unknown = "",
}

---@class ghc.core.setting.icons.ui
M.ui = {
  Accepted = "",
  ArrowClosed = "",
  ArrowOpen = "",
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

---@class ghc.core.setting.icons.diagnostics
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

---@class ghc.core.setting.icons.misc
M.misc = {
  Campass = "󰀹",
  Code = "",
  Gavel = "",
  Glass = "󰂖",
  NoActiveLsp = "󱚧",
  PyEnv = "󰢩",
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

---@class ghc.core.setting.icons.cmp
M.cmp = {
  buffer = "",
  cmp_tabnine = "",
  codeium = "",
  copilot = "",
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

---@class ghc.core.setting.icons.dap
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

---@class ghc.core.setting.icons.devicons
M.devicons = {
  default_icon = {
    icon = "󰈚",
    name = "Default",
  },

  c = {
    icon = "",
    name = "c",
  },

  css = {
    icon = "",
    name = "css",
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

  html = {
    icon = "",
    name = "html",
  },

  jpeg = {
    icon = "󰉏",
    name = "jpeg",
  },

  jpg = {
    icon = "󰉏",
    name = "jpg",
  },

  js = {
    icon = "󰌞",
    name = "js",
  },

  kt = {
    icon = "󱈙",
    name = "kt",
  },

  lock = {
    icon = "󰌾",
    name = "lock",
  },

  lua = {
    icon = "",
    name = "lua",
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

  png = {
    icon = "󰉏",
    name = "png",
  },

  py = {
    icon = "",
    name = "py",
  },

  ["robots.txt"] = {
    icon = "󰚩",
    name = "robots",
  },

  toml = {
    icon = "",
    name = "toml",
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

  vue = {
    icon = "󰡄",
    name = "vue",
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
