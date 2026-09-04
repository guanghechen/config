---@see https://github.com/nvim-mini/mini.indentscope/blob/92fbaf895f83c59575ec599df532b297ebf62b14/lua/mini/indentscope.lua

--- MIT License
---
--- Copyright (c) 2022 Evgeni Chasnovski
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
local __module_name__ = "era.dressing.indentscope" ---@type string

---@alias era.dressing.indentscope.Border "both"|"top"|"bottom"|"none"
---@alias era.dressing.indentscope.Side "top"|"bottom"

---@class era.dressing.indentscope.IOptions
---@field public border                 era.dressing.indentscope.Border
---@field public indent_at_cursor       boolean
---@field public try_as_border          boolean

---@class era.dressing.indentscope.IOptionsOverride
---@field public border                 ?era.dressing.indentscope.Border
---@field public indent_at_cursor       ?boolean
---@field public try_as_border          ?boolean

---@class era.dressing.indentscope.IDrawConfig
---@field public delay                  integer
---@field public interval               integer
---@field public max_duration           integer
---@field public priority               integer

---@class era.dressing.indentscope.IDrawOptions: era.dressing.indentscope.IDrawConfig
---@field public symbol                 string
---@field public highlights             string[]

---@class era.dressing.indentscope.IConfig
---@field public draw                   era.dressing.indentscope.IDrawConfig
---@field public options                era.dressing.indentscope.IOptions
---@field public symbol                 string
---@field public highlights             string[]

---@class era.dressing.indentscope.IBody
---@field public top                    integer
---@field public bottom                 integer
---@field public indent                 integer

---@class era.dressing.indentscope.IBorder
---@field public top                    integer|nil
---@field public bottom                 integer|nil
---@field public indent                 integer|nil

---@class era.dressing.indentscope.IReference
---@field public line                   integer
---@field public col                    integer
---@field public indent                 integer

---@class era.dressing.indentscope.IScope
---@field public bufnr                  integer
---@field public winnr                  integer
---@field public body                   era.dressing.indentscope.IBody
---@field public border                 era.dressing.indentscope.IBorder
---@field public reference              era.dressing.indentscope.IReference

---@class era.dressing.indentscope.draw.IIndicator
---@field public rows                   integer[]
---@field public row_indexes            table<integer, integer>
---@field public origin_index           integer
---@field public extmark_options        vim.api.keyset.set_extmark

---@class era.dressing.indentscope
local M = {}

---@type era.dressing.indentscope.IConfig
M.config = {
  draw = {
    delay = 100,
    interval = 20,
    max_duration = 300,
    priority = 2,
  },
  options = {
    border = "both",
    indent_at_cursor = true,
    try_as_border = true,
  },
  symbol = "╎",
  highlights = {
    "f_indentscope_1",
    "f_indentscope_2",
    "f_indentscope_3",
    "f_indentscope_4",
    "f_indentscope_5",
    "f_indentscope_6",
    "f_indentscope_7",
  },
}

local initialized = false ---@type boolean

---@return era.dressing.indentscope.scope
local function get_scope_module()
  return require("era.dressing.indentscope.scope")
end

---@return era.dressing.indentscope.draw
local function get_draw_module()
  return require("era.dressing.indentscope.draw")
end

---@return era.dressing.indentscope.action
local function get_action_module()
  return require("era.dressing.indentscope.action")
end

---@param options                       ?era.dressing.indentscope.IOptionsOverride
---@return era.dressing.indentscope.IOptions
local function resolve_options(options)
  local resolved = vim.tbl_extend("force", {}, M.config.options, options or {}) ---@type era.dressing.indentscope.IOptions
  if not vim.list_contains({ "both", "top", "bottom", "none" }, resolved.border) then
    error("invalid indentscope border: " .. tostring(resolved.border), 2)
  end
  return resolved
end

---@param options                       ?table
---@return era.dressing.indentscope.IDrawOptions
local function resolve_draw_options(options)
  local resolved = vim.tbl_extend("force", {}, M.config.draw, options or {}) ---@type era.dressing.indentscope.IDrawOptions
  resolved.symbol = M.config.symbol
  resolved.highlights = M.config.highlights
  return resolved
end

---@param bufnr                         integer
---@return boolean
function M.is_enabled(bufnr)
  return get_draw_module().is_enabled(bufnr)
end

---@param line                          ?integer
---@param col                           ?integer
---@param options                       ?era.dressing.indentscope.IOptionsOverride
---@return era.dressing.indentscope.IScope
function M.get_scope(line, col, options)
  return get_scope_module().get(line, col, resolve_options(options))
end

---@param scope                         ?era.dressing.indentscope.IScope
---@param options                       ?table
---@return nil
function M.draw(scope, options)
  get_draw_module().draw(scope or M.get_scope(), resolve_draw_options(options))
end

---@return nil
function M.undraw()
  get_draw_module().undraw()
end

---@param side                          era.dressing.indentscope.Side
---@param use_border                    ?boolean
---@param scope                         ?era.dressing.indentscope.IScope
---@return nil
function M.move_cursor(side, use_border, scope)
  get_action_module().move_cursor(side, use_border == true, scope or M.get_scope())
end

---@param side                          era.dressing.indentscope.Side
---@param add_to_jumplist               ?boolean
---@return nil
function M.operator(side, add_to_jumplist)
  get_action_module().operator(side, add_to_jumplist == true, M.get_scope)
end

---@param use_border                    ?boolean
---@return nil
function M.textobject(use_border)
  get_action_module().textobject(use_border == true, M.get_scope)
end

---@param lazy                          boolean
---@param immediate                     boolean
---@return nil
local function refresh(lazy, immediate)
  local draw = get_draw_module() ---@type era.dressing.indentscope.draw
  if not draw.is_enabled(vim.api.nvim_get_current_buf()) then
    draw.undraw()
    return
  end

  local options = resolve_draw_options(immediate and { delay = 0 } or nil) ---@type era.dressing.indentscope.IDrawOptions
  draw.refresh(M.get_scope(), options, lazy)
end

---@return nil
local function relayout()
  local draw = get_draw_module() ---@type era.dressing.indentscope.draw
  if not draw.relayout() then
    refresh(false, true)
  end
end

---@return nil
local function setup_highlights()
  for _, hlname in ipairs(M.config.highlights) do
    vim.api.nvim_set_hl(0, hlname, { default = true, link = "Delimiter" })
  end
end

---@return nil
local function setup_keymaps()
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "[i",
      desc = "indentscope: goto top",
      callback = "<Cmd>lua era.dressing.indentscope.operator('top', true)<CR>",
    },
    {
      modes = { "n" },
      key = "]i",
      desc = "indentscope: goto bottom",
      callback = "<Cmd>lua era.dressing.indentscope.operator('bottom', true)<CR>",
    },
    {
      modes = { "x", "o" },
      key = "[i",
      desc = "indentscope: goto top",
      callback = "<Cmd>lua era.dressing.indentscope.operator('top')<CR>",
    },
    {
      modes = { "x", "o" },
      key = "]i",
      desc = "indentscope: goto bottom",
      callback = "<Cmd>lua era.dressing.indentscope.operator('bottom')<CR>",
    },
    {
      modes = { "x", "o" },
      key = "ii",
      desc = "indentscope: inner scope",
      callback = "<Cmd>lua era.dressing.indentscope.textobject()<CR>",
    },
    {
      modes = { "x", "o" },
      key = "ai",
      desc = "indentscope: around scope",
      callback = "<Cmd>lua era.dressing.indentscope.textobject(true)<CR>",
    },
  }
  stl.nvim.fn.bindkeys(keymaps, { noremap = true, silent = true })
end

---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  setup_highlights()
  setup_keymaps()

  local augroup = stl.nvim.fn.augroup(__module_name__) ---@type integer
  vim.api.nvim_create_autocmd({ "BufWinEnter", "CursorMoved", "CursorMovedI", "ModeChanged", "WinEnter" }, {
    group = augroup,
    callback = function()
      refresh(true, false)
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    callback = function()
      if vim.fn.win_gettype() ~= "autocmd" then
        refresh(true, false)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = augroup,
    callback = function()
      refresh(false, true)
    end,
  })
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = augroup,
    callback = relayout,
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = setup_highlights,
  })
  vim.api.nvim_create_autocmd("User", {
    group = augroup,
    pattern = "VeryLazy",
    once = true,
    callback = setup_keymaps,
  })
end

return M
