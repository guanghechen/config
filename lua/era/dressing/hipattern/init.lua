---@see https://github.com/nvim-mini/mini.hipatterns/blob/7c840c71d6a91f53d734cab2b6fe2290d285ec3b/lua/mini/hipatterns.lua

--- MIT License
---
--- Copyright (c) 2023 Evgeni Chasnovski
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
local __module_name__ = "era.dressing.hipattern" ---@type string

local filetype = require("stl.filetype")

---@class era.dressing.hipattern
local M = {}

---@type table<string, boolean>
local DISABLED_BUFTYPES = {
  help = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

---@type table<string, boolean>
local DISABLED_FILETYPES = {
  [""] = true,
  ["diff"] = true,
  ["excalidraw"] = true,
  ["git-credentials"] = true,
  ["image"] = true,
  [filetype.AI_TERMINAL] = true,
  [filetype.BIGFILE] = true,
  [filetype.BOARD] = true,
  [filetype.CHECKHEALTH] = true,
  [filetype.DIFFVIEW_CHANGES] = true,
  [filetype.DIFFVIEW_COMMITS] = true,
  [filetype.DIFFVIEW_FILES] = true,
  [filetype.DIFFVIEW_SBS] = true,
  [filetype.EXPLORER] = true,
  [filetype.GITCOMMIT] = true,
  [filetype.HELP] = true,
  [filetype.LSPINFO] = true,
  [filetype.MAN] = true,
  [filetype.MASON] = true,
  [filetype.NOTIFY] = true,
  [filetype.QUICKFIX] = true,
  [filetype.SELECT] = true,
  [filetype.STARTUPTIME] = true,
  [filetype.TEMP_VIEWER] = true,
  [filetype.TERM] = true,
  [filetype.TERM_MASK] = true,
  [filetype.UX_CMDLINE] = true,
  [filetype.UX_INPUT] = true,
  [filetype.UX_MESSAGE_HISTORY] = true,
  [filetype.UX_PICKER_FINDER] = true,
  [filetype.UX_PICKER_PREVIEW] = true,
  [filetype.UX_PICKER_RESULT] = true,
  [filetype.UX_POPUPMENU] = true,
  [filetype.UX_SEARCHER_FINDER] = true,
  [filetype.UX_SEARCHER_PREVIEW] = true,
  [filetype.UX_SEARCHER_RESULT] = true,
  [filetype.WINPICKER_MASK] = true,
  [filetype.WINSEP] = true,
}

local initialized = false ---@type boolean

---@return era.dressing.hipattern.buffer
local function get_buffer()
  return require("era.dressing.hipattern.buffer")
end

---@param bufnr                         integer
---@return boolean
local function is_eligible(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
  if DISABLED_BUFTYPES[buftype] then
    return false
  end

  local value = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  return DISABLED_FILETYPES[value] ~= true
end

---@param bufnr                         integer|nil
---@return nil
function M.enable(bufnr)
  get_buffer().enable(bufnr, is_eligible)
end

---@param bufnr                         integer|nil
---@return nil
function M.disable(bufnr)
  get_buffer().disable(bufnr)
end

---@param bufnr                         integer|nil
---@return nil
function M.toggle(bufnr)
  get_buffer().toggle(bufnr, is_eligible)
end

---@param bufnr                         integer|nil
---@return boolean
function M.is_enabled(bufnr)
  return get_buffer().is_enabled(bufnr)
end

---@param bufnr                         integer|nil
---@param from_row                      integer|nil
---@param to_row                        integer|nil
---@return nil
function M.update(bufnr, from_row, to_row)
  get_buffer().update(bufnr, from_row, to_row)
end

---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true
  get_buffer().setup(is_eligible)
end

return M
