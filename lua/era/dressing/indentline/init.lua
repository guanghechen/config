---@see https://github.com/saghen/blink.indent/blob/8b69b9262891fe81fe728fe6a52fa2a84dd5d5e0/lua/blink/indent/init.lua

--- MIT License
---
--- Copyright (c) 2025 Liam Dyer
---
--- Permission is hereby granted, free of charge, to any person obtaining a copy
--- of this software and associated documentation files (the "Software"), to deal
--- in the Software without restriction, including without limitation the rights
--- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--- copies of the Software, and to permit persons to whom the Software is
--- furnished to do so, subject to the following conditions:
---
--- The above copyright notice and this permission notice shall be included in all
--- copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--- SOFTWARE.

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.indentline" ---@type string

local filetype = require("stl.filetype")

---@class era.dressing.indentline.IConfig
---@field public char                   string
---@field public priority               integer
---@field public highlights             string[]

---@class era.dressing.indentline
local M = {}

M.config = {
  char = "│",
  priority = 1,
  highlights = {
    "f_indentline_1",
    "f_indentline_2",
    "f_indentline_3",
    "f_indentline_4",
    "f_indentline_5",
    "f_indentline_6",
    "f_indentline_7",
  },
} ---@type era.dressing.indentline.IConfig

---@type table<string, boolean>
local DISABLED_BUFTYPES = {
  nofile = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

---@type table<string, boolean>
local DISABLED_FILETYPES = {
  [""] = true,
  ["dashboard"] = true,
  ["lazy"] = true,
  ["packer"] = true,
  [filetype.BIGFILE] = true,
  [filetype.CHECKHEALTH] = true,
  [filetype.GITCOMMIT] = true,
  [filetype.HELP] = true,
  [filetype.LSPINFO] = true,
  [filetype.MAN] = true,
  [filetype.MASON] = true,
}

local initialized = false ---@type boolean
local enabled = false ---@type boolean

---@return era.dressing.indentline.render
local function get_render()
  return require("era.dressing.indentline.render")
end

---@param bufnr                         integer
---@return boolean
function M.is_enabled(bufnr)
  if
    not enabled
    or not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.api.nvim_buf_is_loaded(bufnr)
    or DISABLED_BUFTYPES[vim.api.nvim_get_option_value("buftype", { buf = bufnr })]
  then
    return false
  end

  local value = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  return DISABLED_FILETYPES[value] ~= true
end

---@return nil
local function refresh()
  get_render().invalidate()
  pcall(vim.api.nvim__redraw, { valid = false, flush = true })
end

---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  enabled = dot.context.flight.dressing_indent:snapshot() ---@type boolean
  get_render().setup(M.config, M.is_enabled)

  stl.fn.observe({ dot.context.flight.dressing_indent }, function()
    enabled = dot.context.flight.dressing_indent:snapshot() ---@type boolean
    refresh()
  end, true)

  local augroup = stl.nvim.fn.augroup(__module_name__) ---@type integer
  vim.api.nvim_create_autocmd("OptionSet", {
    group = augroup,
    pattern = { "breakindent", "buftype", "filetype", "list", "listchars", "shiftwidth", "tabstop", "vartabstop" },
    callback = refresh,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(ev)
      get_render().drop_window(tonumber(ev.match) or -1)
    end,
  })

  refresh()
end

return M
