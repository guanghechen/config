---@class ark.c.__mods
local c__mods = {
  BatchDisposable = "ark.c.batch_disposable",
  BatchHandler = "ark.c.batch_handler",
  CircularQueue = "ark.c.circular_queue",
  CircularStack = "ark.c.circular_stack",
  Dirtier = "ark.c.dirtier",
  Disposable = "ark.c.disposable",
  Filetree = "ark.c.filetree",
  Frecency = "ark.c.frecency",
  History = "ark.c.history",
  InputHistory = "ark.c.input_history",
  Observable = "ark.c.observable",
  Proc = "ark.c.proc",
  Scheduler = "ark.c.scheduler",
  Subscriber = "ark.c.subscriber",
  Subscribers = "ark.c.subscribers",
  Ticker = "ark.c.ticker",
  Tree = "ark.c.tree",
  TreeRetriever = "ark.c.tree_retriever",
}

---@class ark.c
---@field public __mods                 ark.c.__mods
---@field public BatchDisposable        ark.c.BatchDisposable
---@field public BatchHandler           ark.c.BatchHandler
---@field public CircularQueue          ark.c.CircularQueue
---@field public CircularStack          ark.c.CircularStack
---@field public Dirtier                ark.c.Dirtier
---@field public Disposable             ark.c.Disposable
---@field public Filetree               ark.c.Filetree
---@field public Frecency               ark.c.Frecency
---@field public History                ark.c.History
---@field public InputHistory           ark.c.InputHistory
---@field public Observable             ark.c.Observable
---@field public Proc                   ark.c.Proc
---@field public Scheduler              ark.c.Scheduler
---@field public Subscriber             ark.c.Subscriber
---@field public Subscribers            ark.c.Subscribers
---@field public Ticker                 ark.c.Ticker
---@field public Tree                   ark.c.Tree
---@field public TreeRetriever          ark.c.TreeRetriever
local c = setmetatable({ __mods = c__mods }, {
  __index = function(t, k)
    local m = c__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.dict.__mods
local dict__mods = {
  en = "ark.dict.en",
}

---@class ark.dict
---@field public __mods                 ark.dict.__mods
---@field public en                     { [1]: string, [2]: string }[]
local dict = setmetatable({ __mods = dict__mods }, {
  __index = function(t, k)
    local m = dict__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.lang.__mods
local lang__mods = {
  python = "ark.lang.python",
  tailwind = "ark.lang.tailwind",
}

---@class ark.lang
---@field public __mods                 ark.lang.__mods
---@field public python                 ark.lang.python
---@field public tailwind               ark.lang.tailwind
local lang = setmetatable({ __mods = lang__mods }, {
  __index = function(t, k)
    local m = lang__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.theme.scheme.__mods
local theme_scheme__mods = {
  ["catppuccin-frappe"] = "ark.theme.scheme.catppuccin-frappe",
  ["catppuccin-latte"] = "ark.theme.scheme.catppuccin-latte",
  ["catppuccin-macchiato"] = "ark.theme.scheme.catppuccin-macchiato",
  ["catppuccin-mocha"] = "ark.theme.scheme.catppuccin-mocha",
  ["gruvbox-dark"] = "ark.theme.scheme.gruvbox-dark",
  ["gruvbox-light"] = "ark.theme.scheme.gruvbox-light",
  ["nord"] = "ark.theme.scheme.nord",
  ["onehalf-dark"] = "ark.theme.scheme.onehalf-dark",
  ["onehalf-light"] = "ark.theme.scheme.onehalf-light",
  ["rosepine-dawn"] = "ark.theme.scheme.rosepine-dawn",
  ["rosepine-main"] = "ark.theme.scheme.rosepine-main",
  ["rosepine-moon"] = "ark.theme.scheme.rosepine-moon",
  ["tokyonight-day"] = "ark.theme.scheme.tokyonight-day",
  ["tokyonight-moon"] = "ark.theme.scheme.tokyonight-moon",
  ["tokyonight-night"] = "ark.theme.scheme.tokyonight-night",
  ["tokyonight-storm"] = "ark.theme.scheme.tokyonight-storm",
  ["vsc-dark-modern"] = "ark.theme.scheme.vsc-dark-modern",
  ["vsc-light-modern"] = "ark.theme.scheme.vsc-light-modern",
}

---@class ark.theme.scheme
---@field public __mods                 ark.theme.scheme.__mods
---@field public ["catppuccin-frappe"]  ark.t.theme.IScheme
---@field public ["catppuccin-latte"]   ark.t.theme.IScheme
---@field public ["catppuccin-macchiato"] ark.t.theme.IScheme
---@field public ["catppuccin-mocha"]   ark.t.theme.IScheme
---@field public ["gruvbox-dark"]       ark.t.theme.IScheme
---@field public ["gruvbox-light"]      ark.t.theme.IScheme
---@field public ["nord"]               ark.t.theme.IScheme
---@field public ["onehalf-dark"]       ark.t.theme.IScheme
---@field public ["onehalf-light"]      ark.t.theme.IScheme
---@field public ["rosepine-dawn"]      ark.t.theme.IScheme
---@field public ["rosepine-main"]      ark.t.theme.IScheme
---@field public ["rosepine-moon"]      ark.t.theme.IScheme
---@field public ["tokyonight-day"]     ark.t.theme.IScheme
---@field public ["tokyonight-moon"]    ark.t.theme.IScheme
---@field public ["tokyonight-night"]   ark.t.theme.IScheme
---@field public ["tokyonight-storm"]   ark.t.theme.IScheme
---@field public ["vsc-dark-modern"]    ark.t.theme.IScheme
---@field public ["vsc-light-modern"]   ark.t.theme.IScheme
local theme_scheme = setmetatable({ __mods = theme_scheme__mods }, {
  __index = function(t, k)
    local m = theme_scheme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.theme.__mods
local theme__mods = {}

---@class ark.theme
---@field public __mods                 ark.theme.__mods
---@field public scheme                 ark.theme.scheme
local theme = setmetatable({
  __mods = theme__mods,
  scheme = theme_scheme,
}, {
  __index = function(t, k)
    local m = theme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.view.IView
---@field public fullname               string
---@field public nsnr                   integer
---@field public clear                  fun(self: ark.view.IView): ark.view.IView
---@field public dispose                fun(self: ark.view.IView): nil
---@field public isdisposed             fun(self: ark.view.IView): boolean
---@field public render                 fun(self: ark.view.IView, bufnr: integer, force: boolean): ark.view.IView

---@class ark.view.__mods
local view__mods = {
  Plainfile = "ark.view.plainfile",
  Printer = "ark.view.printer",
  Tree = "ark.view.tree",
}

---@class ark.view
---@field public __mods                 ark.view.__mods
---@field public Plainfile              ark.view.Plainfile
---@field public Printer                ark.view.Printer
---@field public Tree                   ark.view.Tree
local view = setmetatable({ __mods = view__mods }, {
  __index = function(t, k)
    local m = view__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.__mods
local __mods = {
  color = "ark.external.color",
  easing = "ark.external.easing",

  anim = "ark.anim",
  box = "ark.box",
  debug = "ark.debug",
  env = "ark.env",
  fileicon = "ark.fileicon",
  filetype = "ark.filetype",
  fn = "ark.fn",
  fs = "ark.fs",
  hot = "ark.hot",
  icon = "ark.icon",
  json = "ark.json",
  nvim = "ark.nvim",
  reporter = "ark.reporter",
  stdout = "ark.stdout",
  string = "ark.string",
  table = "ark.table",
  time = "ark.time",
  timer = "ark.timer",
  tmux = "ark.tmux",
  var = "ark.var",
  winhint = "ark.winhint",
}

---@class ark
---@field public __mods                 ark.__mods
---@field public anim                   ark.anim
---@field public box                    ark.box
---@field public c                      ark.c
---@field public color                  ark.external.color
---@field public debug                  ark.debug
---@field public dict                   ark.dict
---@field public easing                 ark.external.easing
---@field public env                    ark.env
---@field public fileicon               ark.fileicon
---@field public filetype               ark.filetype
---@field public fn                     ark.fn
---@field public fs                     ark.fs
---@field public hot                    ark.hot
---@field public icon                   ark.icon
---@field public json                   ark.json
---@field public lang                   ark.lang
---@field public nvim                   ark.nvim
---@field public reporter               ark.reporter
---@field public stdout                 ark.stdout
---@field public string                 ark.string
---@field public table                  ark.table
---@field public theme                  ark.theme
---@field public time                   ark.time
---@field public timer                  ark.timer
---@field public tmux                   ark.tmux
---@field public var                    ark.var
---@field public view                   ark.view
---@field public winhint                ark.winhint
local M = setmetatable({
  __mods = __mods,
  c = c,
  dict = dict,
  lang = lang,
  theme = theme,
  view = view,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
