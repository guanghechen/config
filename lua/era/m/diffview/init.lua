---@class era.m.diffview.pane.__mods
local pane__mods = {
  changes = "era.m.diffview.pane.changes",
  commits = "era.m.diffview.pane.commits",
  filetree = "era.m.diffview.pane.filetree",
  sbs = "era.m.diffview.pane.sbs",
}

---@class era.m.diffview.pane
---@field public __mods                 era.m.diffview.pane.__mods
---@field public changes                era.m.diffview.pane.changes
---@field public commits                era.m.diffview.pane.commits
---@field public filetree               era.m.diffview.pane.filetree
---@field public sbs                    era.m.diffview.pane.sbs
local pane = setmetatable({ __mods = pane__mods }, {
  __index = function(t, k)
    local m = pane__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.workspace.__mods
local view_workspace__mods = {
  action = "era.m.diffview.view.workspace.action",
  keymap = "era.m.diffview.view.workspace.keymap",
  state = "era.m.diffview.view.workspace.state",
  tabline = "era.m.diffview.view.workspace.tabline",
  view = "era.m.diffview.view.workspace.view",
}

---@class era.m.diffview.view.workspace
---@field public __mods                 era.m.diffview.view.workspace.__mods
---@field public action                 era.m.diffview.view.workspace.action
---@field public keymap                 era.m.diffview.view.workspace.keymap
---@field public state                  era.m.diffview.view.workspace.state
---@field public tabline                era.m.diffview.view.workspace.tabline
---@field public view                   era.m.diffview.view.workspace.view
local view_workspace = setmetatable({ __mods = view_workspace__mods }, {
  __index = function(t, k)
    local m = view_workspace__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.commits.__mods
local view_commits__mods = {
  action = "era.m.diffview.view.commits.action",
  keymap = "era.m.diffview.view.commits.keymap",
  state = "era.m.diffview.view.commits.state",
  tabline = "era.m.diffview.view.commits.tabline",
  view = "era.m.diffview.view.commits.view",
}

---@class era.m.diffview.view.commits
---@field public __mods                 era.m.diffview.view.commits.__mods
---@field public action                 era.m.diffview.view.commits.action
---@field public keymap                 era.m.diffview.view.commits.keymap
---@field public state                  era.m.diffview.view.commits.state
---@field public tabline                era.m.diffview.view.commits.tabline
---@field public view                   era.m.diffview.view.commits.view
local view_commits = setmetatable({ __mods = view_commits__mods }, {
  __index = function(t, k)
    local m = view_commits__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.__mods
local view__mods = {
  commits = "era.m.diffview.view.commits.view",
  workspace = "era.m.diffview.view.workspace.view",
}

---@class era.m.diffview.view
---@field public __mods                 era.m.diffview.view.__mods
---@field public commits                era.m.diffview.view.commits
---@field public workspace              era.m.diffview.view.workspace
local view = setmetatable({
  __mods = view__mods,
  commits = view_commits,
  workspace = view_workspace,
}, {
  __index = function(t, k)
    local m = view__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era.m.diffview.__mods
local __mods = {
  buffer = "era.m.diffview.buffer",
  cmd = "era.m.diffview.cmd",
  config = "era.m.diffview.config",
  data = "era.m.diffview.data",
  fn = "era.m.diffview.fn",
  layout = "era.m.diffview.layout",
  util = "era.m.diffview.util",
  window = "era.m.diffview.window",
}

---@class era.m.diffview
---@field public __mods                 era.m.diffview.__mods
---@field public buffer                 era.m.diffview.buffer
---@field public cmd                    era.m.diffview.cmd
---@field public config                 era.m.diffview.config
---@field public data                   era.m.diffview.data
---@field public fn                     era.m.diffview.fn
---@field public layout                 era.m.diffview.layout
---@field public pane                   era.m.diffview.pane
---@field public util                   era.m.diffview.util
---@field public view                   era.m.diffview.view
---@field public window                 era.m.diffview.window
local M = setmetatable({
  __mods = __mods,
  pane = pane,
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
