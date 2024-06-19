local util_table = require("guanghechen.util.table")
local Searcher = require("kyokuya.replace.searcher")
local renderer = require("kyokuya.replace.renderer")
local ui_edit = require("kyokuya.replace.ui-edit")

local current_buf_delete_augroup = vim.api.nvim_create_augroup("current_buf_delete_augroup", { clear = true })

local nsnr = vim.api.nvim_create_namespace("REPLACE_PANE") ---@type integer

---@class kyokuya.replacer.Replacer
---@field private state kyokuya.types.IReplacerState|nil
---@field private searcher kyokuya.types.ISearcher
---@field private bufnr integer|nil
---@field private dirty boolean
local M = {}
M.__index = M

---@return kyokuya.replacer.Replacer
function M.new()
  local self = setmetatable({}, M)

  self.searcher = Searcher:new()
  self.state = nil
  self.bufnr = nil
  self.dirty = true

  return self
end

---@param next_state kyokuya.types.IReplacerState|nil
---@return nil
function M:set_state(next_state)
  if next_state == nil then
    return
  end

  local normailized = self:normalize(next_state) ---@type kyokuya.types.IReplacerState
  if not self:equals(normailized) then
    self.dirty = true
    self.state = normailized
  end
end

---@param opts? kyokuya.types.IReplacerOptions
---@return nil
function M:replace(opts)
  local winnr = (opts ~= nil and opts.winnr ~= nil) and opts.winnr or 0 ---@type integer
  local force = (opts ~= nil and opts.force ~= nil) and opts.force or false ---@type boolean
  local state = (opts ~= nil and opts.state ~= nil) and opts.state or nil ---@type kyokuya.types.IReplacerState|nil
  self:set_state(state)

  local function on_change(next_state)
    self:replace({
      state = next_state,
      winnr = winnr,
      force = force,
    })
  end

  if self.bufnr == nil then
    local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
    vim.cmd(string.format("%sbufdo file %s/REPLACE", bufnr, bufnr)) --- Rename the buf
    vim.api.nvim_create_autocmd("BufDelete", {
      group = current_buf_delete_augroup,
      buffer = bufnr,
      callback = function()
        self.bufnr = nil
      end,
    })

    ---@param modes string|string[]
    ---@param key string
    ---@param action any
    ---@param desc string
    local function mk(modes, key, action, desc)
      vim.keymap.set(modes, key, action, { noremap = true, silent = true, buffer = bufnr, desc = desc })
    end

    local function on_edit()
      ui_edit.edit_replacer_state({
        state = self.state,
        on_confirm = on_change,
      })
    end

    mk({ "n" }, "I", on_edit, "Edit search config")
    mk({ "n" }, "a", on_edit, "Edit search config")
    mk({ "n" }, "A", on_edit, "Edit search config")
    self.bufnr = bufnr
  end

  if self.state ~= nil then
    if self.dirty or force then
      renderer.render({
        searcher = self.searcher,
        state = self.state,
        bufnr = self.bufnr,
        winnr = winnr,
        nsnr = nsnr,
        force = force,
        on_change = on_change,
      })
      self.dirty = false
    end
  end
end

---@param state kyokuya.types.IReplacerState
---@return kyokuya.types.IReplacerState
function M:normalize(state)
  local search_paths = util_table.trim_and_filter(state.search_paths)
  local include_patterns = util_table.trim_and_filter(state.include_patterns)
  local exclude_patterns = util_table.trim_and_filter(state.exclude_patterns)

  ---@type kyokuya.types.IReplacerState
  local normalized = {
    cwd = state.cwd,
    mode = state.mode,
    flag_case_sensitive = state.flag_case_sensitive,
    flag_regex = state.flag_regex,
    search_pattern = state.search_pattern,
    replace_pattern = state.replace_pattern,
    search_paths = search_paths,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
  }
  return normalized
end

---@param next_state kyokuya.types.IReplacerState
---@return boolean
function M:equals(next_state)
  local state = self.state ---@type kyokuya.types.IReplacerState

  if state == nil then
    return false
  end

  if state == next_state then
    return true
  end

  return (
    state.cwd == next_state.cwd
    and state.mode == next_state.mode
    and state.flag_regex == next_state.flag_regex
    and state.flag_case_sensitive == next_state.flag_case_sensitive
    and state.search_pattern == next_state.search_pattern
    and state.replace_pattern == next_state.replace_pattern
    and util_table.equals_array(state.search_paths, next_state.search_paths)
    and util_table.equals_array(state.include_patterns, next_state.include_patterns)
    and util_table.equals_array(state.exclude_patterns, next_state.exclude_patterns)
  )
end

return M
