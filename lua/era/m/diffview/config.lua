---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.config" ---@type string

local filetype = require("stl.filetype")
local icon = require("stl.icon")

---@class era.m.diffview.config
local M = {}

----------------------------------------------------------------------------------------------------
-- Namespace
----------------------------------------------------------------------------------------------------

M.NS = vim.api.nvim_create_namespace("era.m.diffview")

----------------------------------------------------------------------------------------------------
-- Filetype
----------------------------------------------------------------------------------------------------

---@type table<string, string>
M.FT = {
  CHANGES = filetype.DIFFVIEW_CHANGES,
  COMMITS = filetype.DIFFVIEW_COMMITS,
  FILETREE = filetype.DIFFVIEW_FILES,
  SBS = filetype.DIFFVIEW_SBS,
}

----------------------------------------------------------------------------------------------------
-- Buffer options for non-file buffers
----------------------------------------------------------------------------------------------------

---@type table<string, any>
M.BUFOPTS_PANEL = {
  bufhidden = "wipe",
  buflisted = false,
  buftype = "nofile",
  modifiable = false,
  swapfile = false,
}

---@type table<string, any>
M.BUFOPTS_SBS = {
  bufhidden = "hide",
  buflisted = false,
  buftype = "nowrite",
  modifiable = false,
  swapfile = false,
  undolevels = -1,
}

----------------------------------------------------------------------------------------------------
-- Window options for diff mode
----------------------------------------------------------------------------------------------------

---@type era.m.diffview.IWinopts
M.WINOPTS_SBS = {
  cursorbind = true,
  diff = true,
  foldenable = true,
  foldcolumn = "1",
  foldlevel = 0,
  foldmethod = "diff",
  scrollbind = true,
  scrollopt = { "ver", "hor", "jump" },
}

---@type table<string, any>
M.WINOPTS_PANEL = {
  cursorline = true,
  foldcolumn = "0",
  list = false,
  number = false,
  relativenumber = false,
  signcolumn = "no",
  spell = false,
  wrap = false,
}

----------------------------------------------------------------------------------------------------
-- Window options to track for save/restore
----------------------------------------------------------------------------------------------------

---@type string[]
M.TRACKED_WINOPTS = {
  "cursorbind",
  "diff",
  "foldenable",
  "foldcolumn",
  "foldlevel",
  "foldmethod",
  "scrollbind",
  "winhighlight",
}

----------------------------------------------------------------------------------------------------
-- Layout dimensions
----------------------------------------------------------------------------------------------------

M.FILETREE_WIDTH = 40
M.COMMITS_WIDTH = 40
M.COMMITS_HEIGHT = 12

----------------------------------------------------------------------------------------------------
-- Pagination
----------------------------------------------------------------------------------------------------

M.COMMITS_PER_PAGE = 100

----------------------------------------------------------------------------------------------------
-- Icons
----------------------------------------------------------------------------------------------------

M.ICONS = {
  COLLAPSED = icon.ui.ArrowClosed,
  EXPANDED = icon.ui.ArrowOpen,
  FILE = icon.filetype.File,
  SEPARATOR = "─",
}

----------------------------------------------------------------------------------------------------
-- Status icons
----------------------------------------------------------------------------------------------------

M.STATUS_ICONS = {
  A = "+",
  C = "C",
  D = "-",
  M = "~",
  R = "→",
  T = "T",
  U = "U",
  ["?"] = "?",
}

return M
