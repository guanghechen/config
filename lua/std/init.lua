---@class std.source.__mods
local source__mods = {
  NotepadJsonSource = "std.source.notepad-json",
  NotepadFolderSource = "std.source.notepad-folder",
}

---@class std.source
---@field public __mods                 std.source.__mods
---@field public NotepadJsonSource      std.source.NotepadJsonSource
---@field public NotepadFolderSource    std.source.NotepadFolderSource
local source = setmetatable({ __mods = source__mods }, {
  __index = function(t, k)
    local m = source__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class std.__mods
local __mods = {
  box = "std.box",
  debug = "std.debug",
  fn = "std.fn",
  fs = "std.fs",
  git = "std.git",
  job = "std.job",
  json = "std.json",
  notepad = "std.notepad",
  nvim = "std.nvim",
  path = "std.path",
  reporter = "std.reporter",
  status = "std.status",
  stdout = "std.stdout",
  string = "std.string",
  table = "std.table",
  timer = "std.timer",
  tmux = "std.tmux",
  uri = "std.uri",

  BatchDisposable = "std.collection.batch_disposable",
  BatchHandler = "std.collection.batch_handler",
  CircularQueue = "std.collection.circular_queue",
  CircularStack = "std.collection.circular_stack",
  Dirtier = "std.collection.dirtier",
  Disposable = "std.collection.disposable",
  Filetree = "std.collection.filetree",
  Frecency = "std.collection.frecency",
  History = "std.collection.history",
  InputHistory = "std.collection.input_history",
  Observable = "std.collection.observable",
  Scheduler = "std.collection.scheduler",
  Spawn = "std.collection.spawn",
  Subscriber = "std.collection.subscriber",
  Subscribers = "std.collection.subscribers",
  Theme = "std.collection.theme",
  Ticker = "std.collection.ticker",
  Tree = "std.collection.tree",
}

---@class std
---@field public __mods                 std.__mods
---@field public source                 std.source
---
---@field public box                    std.box
---@field public debug                  std.debug
---@field public fn                     std.fn
---@field public fs                     std.fs
---@field public git                    std.git
---@field public job                    std.job
---@field public json                   std.json
---@field public notepad                std.notepad
---@field public nvim                   std.nvim
---@field public path                   std.path
---@field public reporter               std.reporter
---@field public status                 std.status
---@field public stdout                 std.stdout
---@field public string                 std.string
---@field public table                  std.table
---@field public timer                  std.timer
---@field public tmux                   std.tmux
---@field public uri                    std.uri
---
---@field public BatchDisposable        std.collection.BatchDisposable
---@field public BatchHandler           std.collection.BatchHandler
---@field public CircularQueue          std.collection.CircularQueue
---@field public CircularStack          std.collection.CircularStack
---@field public Dirtier                std.collection.Dirtier
---@field public Disposable             std.collection.Disposable
---@field public Filetree               std.collection.Filetree
---@field public Frecency               std.collection.Frecency
---@field public History                std.collection.History
---@field public InputHistory           std.collection.InputHistory
---@field public Observable             std.collection.Observable
---@field public Scheduler              std.collection.Scheduler
---@field public Spawn                  std.collection.Spawn
---@field public Subscriber             std.collection.Subscriber
---@field public Subscribers            std.collection.Subscribers
---@field public Theme                  std.collection.Theme
---@field public Ticker                 std.collection.Ticker
---@field public Tree                   std.collection.Tree
local M = setmetatable({
  __mods = __mods,
  source = source,
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
