local NS_NAME = "dot_module_git_sign"
local NS_NAME_STAGED = "dot_module_git_sign_staged"

local config = {
  signs = {
    add = { text = "┃", hl = "m_git_sign_add" },
    change = { text = "┃", hl = "m_git_sign_change" },
    delete = { text = "▁", hl = "m_git_sign_delete" },
    topdelete = { text = "▔", hl = "m_git_sign_delete" },
    changedelete = { text = "~", hl = "m_git_sign_change" },
    untracked = { text = "┆", hl = "m_git_sign_untracked" },
  },
  signs_staged = {
    add = { text = "┃", hl = "m_git_sign_add_staged" },
    change = { text = "┃", hl = "m_git_sign_change_staged" },
    delete = { text = "▁", hl = "m_git_sign_delete_staged" },
    topdelete = { text = "▔", hl = "m_git_sign_delete_staged" },
    changedelete = { text = "~", hl = "m_git_sign_change_staged" },
  },
  priority = 10,
  priority_staged = 9,
}

----------------------------------------------------------------------------------------------------
-- Signs class
----------------------------------------------------------------------------------------------------

---@class era.m.git.sign.ISigns
---@field protected _ns                 integer
---@field protected _config             table<era.m.git.SignType, { text: string, hl: string }>
---@field protected _priority           integer
---@field protected _hl_to_type         table<string, era.m.git.SignType>
local Signs = {}
Signs.__index = Signs

---@param staged                        boolean|nil
---@return era.m.git.sign.ISigns
function Signs.__new__(staged)
  local self = setmetatable({}, Signs)
  self._ns = vim.api.nvim_create_namespace(staged and NS_NAME_STAGED or NS_NAME)
  self._config = staged and config.signs_staged or config.signs
  self._priority = staged and config.priority_staged or config.priority

  self._hl_to_type = {}
  for sign_type, sign_config in pairs(self._config) do
    self._hl_to_type[sign_config.hl] = sign_type
  end

  return self
end

---@return integer
function Signs:get_namespace()
  return self._ns
end

---@param bufnr                         integer
---@param start_lnum                    integer
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
---@param signs                         era.m.git.Sign[]
---@param filter                        (fun(lnum: integer): boolean)|nil
function Signs:add(bufnr, signs, filter)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, sign in ipairs(signs) do
    local lnum = sign.lnum ---@type integer
    if lnum >= 1 and (not filter or filter(lnum)) and not self:contains(bufnr, lnum) then
      local line = lnum - 1 ---@type integer
      local text = self._config[sign.type] and self._config[sign.type].text ---@type string|nil
      if text then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, self._ns, line, 0, {
          id = lnum,
          priority = self._priority,
          sign_text = text,
          sign_hl_group = self._config[sign.type].hl,
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

----------------------------------------------------------------------------------------------------

---@param bufnr                         integer
---@return table<integer, era.m.git.SignType>
function Signs:__get_extmarks__(bufnr)
  local result = {} ---@type table<integer, era.m.git.SignType>
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return result
  end

  local marks = vim.api.nvim_buf_get_extmarks(bufnr, self._ns, 0, -1, { details = true })
  for _, mark in ipairs(marks) do
    local lnum = mark[2] + 1 ---@type integer
    local details = mark[4] ---@type table
    local hl = details.sign_hl_group ---@type string|nil
    if hl and self._hl_to_type[hl] then
      result[lnum] = self._hl_to_type[hl]
    end
  end

  return result
end

---@param bufnr                         integer
---@param new_signs                     era.m.git.Sign[]
---@param filter                        (fun(lnum: integer): boolean)|nil
function Signs:__update_incremental__(bufnr, new_signs, filter)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local old_signs = self:__get_extmarks__(bufnr)
  local new_signs_map = {} ---@type table<integer, era.m.git.SignType>

  for _, sign in ipairs(new_signs) do
    local lnum = sign.lnum ---@type integer
    if lnum >= 1 and (not filter or filter(lnum)) then
      new_signs_map[lnum] = sign.type
    end
  end

  local to_remove = {} ---@type integer[]
  local to_add = {} ---@type era.m.git.Sign[]

  for lnum, old_type in pairs(old_signs) do
    local new_type = new_signs_map[lnum]
    if not new_type then
      to_remove[#to_remove + 1] = lnum
    elseif new_type ~= old_type then
      to_remove[#to_remove + 1] = lnum
      to_add[#to_add + 1] = { lnum = lnum, type = new_type }
    end
  end

  for lnum, new_type in pairs(new_signs_map) do
    if not old_signs[lnum] then
      to_add[#to_add + 1] = { lnum = lnum, type = new_type }
    end
  end

  for _, lnum in ipairs(to_remove) do
    pcall(vim.api.nvim_buf_del_extmark, bufnr, self._ns, lnum)
  end

  for _, sign in ipairs(to_add) do
    local lnum = sign.lnum ---@type integer
    local line = lnum - 1 ---@type integer
    local text = self._config[sign.type] and self._config[sign.type].text ---@type string|nil
    if text then
      pcall(vim.api.nvim_buf_set_extmark, bufnr, self._ns, line, 0, {
        id = lnum,
        priority = self._priority,
        sign_text = text,
        sign_hl_group = self._config[sign.type].hl,
      })
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Module
----------------------------------------------------------------------------------------------------

---@class era.m.git.sign
local M = {}

---@type era.m.git.sign.ISigns
local signs_normal = Signs.__new__(false)

---@type era.m.git.sign.ISigns
local signs_staged = Signs.__new__(true)

---@type boolean
local decoration_provider_setup = false

---@param bufnr                         integer
---@param topline                       integer
---@param botline                       integer
local function on_win(bufnr, topline, botline)
  local buf_cache = era.m.git.buffer.get_cache(bufnr)
  if not buf_cache then
    return false
  end

  local hunks = buf_cache.hunks
  local hunks_staged = buf_cache.hunks_staged
  if not hunks and not hunks_staged then
    return false
  end

  local top = topline + 1 ---@type integer
  local bot = botline + 1 ---@type integer
  local untracked = buf_cache.untracked ---@type boolean

  if hunks then
    local signs = era.m.git.hunk.calc_signs_all(hunks, top, bot)
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
    local signs = era.m.git.hunk.calc_signs_all(hunks_staged, top, bot)
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

  local ns = vim.api.nvim_create_namespace("dot_module_git_sign_decor") ---@type integer
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, bufnr, topline, botline)
      return on_win(bufnr, topline, botline)
    end,
  })
end

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---@param bufnr                         integer
---@param signs                         era.m.git.Sign[]
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
---@param hunks                         era.m.git.Hunk[]|nil
---@param hunks_staged                  era.m.git.Hunk[]|nil
---@param opts                          { untracked: boolean|nil, force: boolean|nil }|nil
function M.update(bufnr, hunks, hunks_staged, opts)
  setup_decoration_provider()

  local force = opts and opts.force ---@type boolean|nil
  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer

  local new_signs = {} ---@type era.m.git.Sign[]
  if hunks and #hunks > 0 then
    new_signs = era.m.git.hunk.calc_signs_all(hunks, 1, line_count)
    if opts and opts.untracked then
      for _, sign in ipairs(new_signs) do
        if sign.type == "add" then
          sign.type = "untracked"
        end
      end
    end
  end

  if force then
    signs_normal:remove(bufnr)
    signs_normal:add(bufnr, new_signs)
  else
    signs_normal:__update_incremental__(bufnr, new_signs)
  end

  local new_signs_staged = {} ---@type era.m.git.Sign[]
  if hunks_staged and #hunks_staged > 0 then
    new_signs_staged = era.m.git.hunk.calc_signs_all(hunks_staged, 1, line_count)
  end

  local new_signs_lnum_set = {} ---@type table<integer, boolean>
  for _, sign in ipairs(new_signs) do
    new_signs_lnum_set[sign.lnum] = true
  end

  local filter = function(lnum)
    return not new_signs_lnum_set[lnum]
  end

  if force then
    signs_staged:remove(bufnr)
    signs_staged:add(bufnr, new_signs_staged, filter)
  else
    signs_staged:__update_incremental__(bufnr, new_signs_staged, filter)
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
  return signs_normal:contains(bufnr, start_lnum, end_lnum) or signs_staged:contains(bufnr, start_lnum, end_lnum)
end

return M
