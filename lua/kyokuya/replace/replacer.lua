local nvim_tools = require("nvim_tools")
local Searcher = require("kyokuya.replace.searcher")
local renderer = require("kyokuya.replace.renderer")

local current_buf_delete_augroup = vim.api.nvim_create_augroup("current_buf_delete_augroup", { clear = true })
local nsnr = 0 -- vim.api.nvim_create_namespace("kyokuya_replace") ---@type integer
local kyokuya_replace_buftype = "nofile"
local kyokuya_replace_filetype = "kyokuya-replace"

---@return integer|nil
local function find_first_replace_buf()
  for _, bufnr in ipairs(vim.t.bufs) do
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    if buftype == kyokuya_replace_buftype and filetype == kyokuya_replace_filetype then
      return bufnr
    end
  end
  return nil
end

---@class kyokuya.replacer.IReplacerOptions
---@field public reuse? boolean

---@class kyokuya.replacer.Replacer
---@field private state kyokuya.types.IReplacerState|nil
---@field private searcher kyokuya.types.ISearcher
---@field private bufnr integer|nil
---@field private dirty boolean
---@field private reuse boolean
local M = {}
M.__index = M

M.nsnr = nsnr

---@param opts? kyokuya.replacer.IReplacerOptions
---@return kyokuya.replacer.Replacer
function M.new(opts)
  local self = setmetatable({}, M)

  opts = opts or {}
  local reuse = not not opts.reuse ---@type boolean

  self.searcher = Searcher:new()
  self.state = nil
  self.bufnr = nil
  self.dirty = true
  self.reuse = reuse

  return self
end

---@return integer|nil
function M:get_bufnr()
  return self.bufnr
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
    if self.reuse then
      self.bufnr = find_first_replace_buf() ---@type integer|nil
    end

    if self.bufnr == nil then
      local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
      vim.api.nvim_set_option_value("buftype", kyokuya_replace_buftype, { buf = bufnr })
      vim.api.nvim_set_option_value("filetype", kyokuya_replace_filetype, { buf = bufnr })
      vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
      vim.cmd(string.format("%sbufdo file %s/REPLACE", bufnr, bufnr)) --- Rename the buf
      vim.api.nvim_create_autocmd("BufDelete", {
        group = current_buf_delete_augroup,
        buffer = bufnr,
        callback = function()
          self.bufnr = nil
        end,
      })

      self.bufnr = bufnr
    end
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
  local search_paths = nvim_tools.normalize_comma_list(state.search_paths) ---@type string
  local include_patterns = nvim_tools.normalize_comma_list(state.include_patterns) ---@type string
  local exclude_patterns = nvim_tools.normalize_comma_list(state.exclude_patterns) ---@type string

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
    and state.search_paths == next_state.search_paths
    and state.include_patterns == next_state.include_patterns
    and state.exclude_patterns == next_state.exclude_patterns
  )
end

return M
