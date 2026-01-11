---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.minimap.handler.marks" ---@type string

local util = require("era.m.minimap.util")

local HIGHLIGHT = "m_mm_mark"
local MARK_KEY = "m"
local BUILTIN_MARKS = { "'.", "'^", "''", "'\"", "'<", "'>", "'[", "']" } ---@type string[]

---@class era.m.minimap.handler.marks : era.m.minimap.IHandler
local M = {
  name = "marks",
}

---@class era.m.minimap.handler.marks.IGlobalMarkCache
---@field public marks                   table<string, { pos: integer[], mark: string }[]>

---@type era.m.minimap.handler.marks.IGlobalMarkCache|nil
local global_mark_cache = nil

---@type boolean
local cache_dirty = true

---@type table<string, true>
local created_keymaps = {}

---@return table<string, { pos: integer[], mark: string }[]>
local function get_global_marks_by_file()
  if not cache_dirty and global_mark_cache then
    return global_mark_cache.marks
  end

  local marks_by_file = {} ---@type table<string, { pos: integer[], mark: string }[]>

  for _, mark in ipairs(vim.fn.getmarklist()) do
    if mark.mark:find("[a-zA-Z]") ~= nil then
      local mark_file = vim.fn.fnamemodify(mark.file, ":p:a") ---@type string
      if not marks_by_file[mark_file] then
        marks_by_file[mark_file] = {}
      end
      marks_by_file[mark_file][#marks_by_file[mark_file] + 1] = mark
    end
  end

  global_mark_cache = { marks = marks_by_file }
  cache_dirty = false

  return marks_by_file
end

---@return nil
local function invalidate_cache()
  cache_dirty = true
end

---@param m                           string
---@return boolean
local function is_builtin_mark(m)
  return vim.list_contains(BUILTIN_MARKS, m)
end

---@param marks                       era.m.minimap.IMark[]
---@param mark                        { pos: integer[], mark: string }
---@param winnr                       integer
---@return nil
local function add_mark_to_bar(marks, mark, winnr)
  local lnum = mark.pos[2] ---@type integer
  local pos = util.row_to_barpos(winnr, lnum - 1)

  if not is_builtin_mark(mark.mark) then
    marks[#marks + 1] = {
      pos = pos,
      highlight = HIGHLIGHT,
      symbol = mark.mark:sub(2, 3),
    }
  end
end

---@param bufnr                       integer
---@param winnr                       integer
---@return era.m.minimap.IMark[]
local function get_marks(bufnr, winnr)
  local ret = {} ---@type era.m.minimap.IMark[]
  local current_file = vim.api.nvim_buf_get_name(bufnr) ---@type string

  local global_marks = get_global_marks_by_file()[current_file]
  if global_marks then
    for _, mark in ipairs(global_marks) do
      add_mark_to_bar(ret, mark, winnr)
    end
  end

  for _, mark in ipairs(vim.fn.getmarklist(bufnr)) do
    add_mark_to_bar(ret, mark, winnr)
  end

  return ret
end

---@param winnr                       integer
---@return nil
local function render(winnr)
  local view = require("era.m.minimap.view")
  if vim.api.nvim_win_is_valid(winnr) and view.is_attached(winnr) then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local marks = get_marks(bufnr, winnr)
    view.render_handler(winnr, M.ns, M.config, marks)
  end
end

---@param data                        any
---@param winnr                       integer
---@return nil
local function exec_mark_autocmd(data, winnr)
  invalidate_cache()
  vim.api.nvim_exec_autocmds("User", {
    pattern = "Mark_" .. tostring(winnr),
    data = data,
  })
end

---@param winnr                       integer
---@return nil
function M.attach(winnr)
  local gname = "era_minimap_marks_" .. tostring(winnr) ---@type string
  local group = vim.api.nvim_create_augroup(gname, { clear = true })

  for code = string.byte("A"), string.byte("Z") do
    local m = string.char(code) ---@type string
    local m_key = MARK_KEY .. m ---@type string
    if vim.fn.maparg(m_key) == "" then
      vim.keymap.set({ "n", "x" }, m_key, function()
        exec_mark_autocmd({ key = m_key }, winnr)
        return m_key
      end, { expr = true })
      created_keymaps[m_key] = true
    end
  end

  for code = string.byte("a"), string.byte("z") do
    local m = string.char(code) ---@type string
    local m_key = MARK_KEY .. m ---@type string
    if vim.fn.maparg(m_key) == "" then
      vim.keymap.set({ "n", "x" }, m_key, function()
        exec_mark_autocmd({ key = m_key }, winnr)
        return m_key
      end, { expr = true })
      created_keymaps[m_key] = true
    end
  end

  for _, cmd in ipairs({ "k", "mar", "delm" }) do
    util.on_cmd(cmd, group, function()
      exec_mark_autocmd({ cmd = cmd }, winnr)
    end)
  end

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "Mark_" .. tostring(winnr),
    callback = vim.schedule_wrap(function()
      render(winnr)
    end),
  })

  render(winnr)
end

---@param winnr                       integer
---@return nil
function M.detach(winnr)
  local gname = "era_minimap_marks_" .. tostring(winnr) ---@type string
  vim.api.nvim_clear_autocmds({ group = gname })

  for m_key in pairs(created_keymaps) do
    pcall(vim.keymap.del, "n", m_key)
    pcall(vim.keymap.del, "x", m_key)
  end
  created_keymaps = {}
end

return M
