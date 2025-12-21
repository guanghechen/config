local NS_NAME = "dot_module_git_sign"
local NS_NAME_STAGED = "dot_module_git_sign_staged"

local config = {
  signs = {
    add = { text = "┃", hl = "fg_sign_add" },
    change = { text = "┃", hl = "fg_sign_change" },
    delete = { text = "▁", hl = "fg_sign_delete" },
    topdelete = { text = "▔", hl = "fg_sign_delete" },
    changedelete = { text = "~", hl = "fg_sign_change" },
    untracked = { text = "┆", hl = "fg_sign_untracked" },
  },
  signs_staged = {
    add = { text = "┃", hl = "fg_sign_add_staged" },
    change = { text = "┃", hl = "fg_sign_change_staged" },
    delete = { text = "▁", hl = "fg_sign_delete_staged" },
    topdelete = { text = "▔", hl = "fg_sign_delete_staged" },
    changedelete = { text = "~", hl = "fg_sign_change_staged" },
  },
  priority = 10,
  priority_staged = 9,
}

---@class dot.module.git.sign.ISigns
---@field protected _ns                 integer
---@field protected _config             table<dot.module.git.SignType, { text: string, hl: string }>
---@field protected _priority           integer
local Signs = {}
Signs.__index = Signs

---@param sign_type                     dot.module.git.SignType
---@return string|nil
function Signs:__get_sign_text__(sign_type)
  local sign_config = self._config[sign_type]
  return sign_config and sign_config.text
end

---@param sign_type                     dot.module.git.SignType
---@return string|nil
function Signs:__get_sign_hl__(sign_type)
  local sign_config = self._config[sign_type]
  return sign_config and sign_config.hl
end

---@param bufnr                         integer
---@param signs                         dot.module.git.Sign[]
---@param filter                        (fun(lnum: integer): boolean)|nil
function Signs:add(bufnr, signs, filter)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, sign in ipairs(signs) do
    local lnum = sign.lnum
    if lnum >= 1 and (not filter or filter(lnum)) and not self:contains(bufnr, lnum) then
      local line = lnum - 1
      local text = self:__get_sign_text__(sign.type)
      if text then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, self._ns, line, 0, {
          id = lnum,
          priority = self._priority,
          sign_text = text,
          sign_hl_group = self:__get_sign_hl__(sign.type),
        })
      end
    end
  end
end

---@param bufnr                         integer
---@param start_lnum                    integer|nil
---@param end_lnum                      integer|nil
function Signs:remove(bufnr, start_lnum, end_lnum)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if start_lnum then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, self._ns, start_lnum - 1, end_lnum or start_lnum)
  else
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, self._ns, 0, -1)
  end
end

---@param bufnr                         integer
---@param start_lnum                    integer|nil
---@param end_lnum                      integer|nil
---@return boolean
function Signs:contains(bufnr, start_lnum, end_lnum)
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    self._ns,
    { (start_lnum or 1) - 1, 0 },
    { (end_lnum or start_lnum or 1) - 1, 0 },
    { limit = 1 }
  )
  return #marks > 0
end

---@param bufnr                         integer
---@param last_orig                     integer
---@param last_new                      integer
function Signs:on_lines(bufnr, last_orig, last_new)
  if last_orig > last_new then
    self:remove(bufnr, last_new + 1, last_orig)
  end
end

function Signs:reset()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    self:remove(buf)
  end
end

---@return integer
function Signs:get_namespace()
  return self._ns
end

---@param staged                        boolean|nil
---@return dot.module.git.sign.ISigns
function Signs.__new__(staged)
  local self = setmetatable({}, Signs)
  self._ns = vim.api.nvim_create_namespace(staged and NS_NAME_STAGED or NS_NAME)
  self._config = staged and config.signs_staged or config.signs
  self._priority = staged and config.priority_staged or config.priority
  return self
end

---@class dot.module.git.sign
local M = {}

---@type dot.module.git.sign.ISigns
local signs_normal = Signs.__new__(false)

---@type dot.module.git.sign.ISigns
local signs_staged = Signs.__new__(true)

---@type boolean
local decoration_provider_setup = false

---@param bufnr                         integer
---@param topline                       integer
---@param botline                       integer
local function on_win(bufnr, topline, botline)
  local buf_cache = dot.git.buffer.get_cache(bufnr)
  if not buf_cache then
    return false
  end

  local hunks = buf_cache.hunks
  local hunks_staged = buf_cache.hunks_staged
  if not hunks and not hunks_staged then
    return false
  end

  local top = topline + 1
  local bot = botline + 1
  local untracked = buf_cache.untracked

  if hunks then
    local signs = dot.git.hunk.calc_signs_all(hunks, top, bot)
    if untracked then
      for _, sign in ipairs(signs) do
        if sign.type == "add" then
          sign.type = "untracked"
        end
      end
    end
    signs_normal:add(bufnr, signs)
  end

  if hunks_staged then
    local signs = dot.git.hunk.calc_signs_all(hunks_staged, top, bot)
    signs_staged:add(bufnr, signs, function(lnum)
      return not signs_normal:contains(bufnr, lnum)
    end)
  end

  return false
end

local function setup_decoration_provider()
  if decoration_provider_setup then
    return
  end
  decoration_provider_setup = true

  local ns = vim.api.nvim_create_namespace("dot_module_git_sign_decor")
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, bufnr, topline, botline)
      return on_win(bufnr, topline, botline)
    end,
  })
end

---@param bufnr                         integer
---@param signs                         dot.module.git.Sign[]
function M.add(bufnr, signs)
  signs_normal:add(bufnr, signs)
end

---@param bufnr                         integer
---@param start_lnum                    integer|nil
---@param end_lnum                      integer|nil
function M.remove(bufnr, start_lnum, end_lnum)
  signs_normal:remove(bufnr, start_lnum, end_lnum)
  signs_staged:remove(bufnr, start_lnum, end_lnum)
end

---@param bufnr                         integer
function M.clear(bufnr)
  signs_normal:remove(bufnr)
  signs_staged:remove(bufnr)
end

---@param bufnr                         integer
---@param last_orig                     integer
---@param last_new                      integer
function M.on_lines(bufnr, last_orig, last_new)
  signs_normal:on_lines(bufnr, last_orig, last_new)
  signs_staged:on_lines(bufnr, last_orig, last_new)
end

---@param bufnr                         integer
---@param hunks                         dot.module.git.Hunk[]|nil
---@param hunks_staged                  dot.module.git.Hunk[]|nil
---@param opts                          { untracked: boolean|nil }|nil
function M.update(bufnr, hunks, hunks_staged, opts)
  M.clear(bufnr)
  setup_decoration_provider()

  if not hunks or #hunks == 0 then
    if not hunks_staged or #hunks_staged == 0 then
      return
    end
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if hunks and #hunks > 0 then
    local signs = dot.git.hunk.calc_signs_all(hunks, 1, line_count)
    if opts and opts.untracked then
      for _, sign in ipairs(signs) do
        if sign.type == "add" then
          sign.type = "untracked"
        end
      end
    end
    signs_normal:add(bufnr, signs)
  end

  if hunks_staged and #hunks_staged > 0 then
    local signs = dot.git.hunk.calc_signs_all(hunks_staged, 1, line_count)
    signs_staged:add(bufnr, signs, function(lnum)
      return not signs_normal:contains(bufnr, lnum)
    end)
  end
end

function M.reset()
  signs_normal:reset()
  signs_staged:reset()
end

---@return integer
function M.get_namespace()
  return signs_normal:get_namespace()
end

---@return integer
function M.get_namespace_staged()
  return signs_staged:get_namespace()
end

---@param bufnr                         integer
---@param start_lnum                    integer
---@param end_lnum                      integer|nil
---@return boolean
function M.contains_range(bufnr, start_lnum, end_lnum)
  return signs_normal:contains(bufnr, start_lnum, end_lnum)
    or signs_staged:contains(bufnr, start_lnum, end_lnum)
end

return M
