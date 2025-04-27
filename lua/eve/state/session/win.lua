---@class eve.state.win.meta.data
---@field public winnr                  integer
---@field public filepath_history       eve.std.collection.history.ISerializedData

---@class eve.state.win.meta.state
---@field public filepath_history       eve.std.collection.IAdvanceHistory

---@class eve.state.win.data
---@field public list                   eve.state.win.meta.data[]

---@class eve.state.win.state
---@field public __meta_map__           table<integer, eve.state.win.meta.state>
---@field public get                    fun(winnr: integer|nil): eve.state.win.meta.state|nil
---@field public set                    fun(winnr: integer|nil, meta: eve.state.win.meta.state): eve.state.win.meta.state|nil
---@field public del                    fun(winnr: integer|nil): nil
---@field public fork                   fun(winnr: integer|nil): eve.state.win.meta.state|nil
---@field public resolve                fun(winnr: integer|nil): eve.state.win.meta.state|nil
---@field public refresh                fun(winnr: integer|nil): nil
---@field public refresh_all            fun(): nil
---@field public refresh_tabpage_wins   fun(tabnr: integer|nil): nil
---
---@field public on_buf_enter           fun(winnr: integer, bufnr: integer): nil
---
---@field public locate_symbols         fun(winnr: integer|nil, callback: fun(err: string|false|nil): nil): nil

---@class eve.state.win : eve.state.win.state
---@field public defaults               fun(): eve.state.win.data
---@field public dump                   fun(): eve.state.win.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.win.data
local M = {}

---@return eve.state.win.data
function M.defaults()
  ---@type eve.state.win.data
  return {
    list = {},
  }
end

---@param data                        any
---@return eve.state.win.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.win.data

  ---@diagnostic disable-next-line: empty-block
  if type(data) == "table" then
    --- handle data
  end

  ---@type eve.state.win.data
  return resolved
end

---@return eve.state.win.data
function M.dump()
  ---@type eve.state.win.data
  return {
    list = {},
  }
end

---@param raw_data                      any
---@return nil
---@diagnostic disable-next-line: unused-local
function M.load(raw_data) end

----------------------------------------------------------------------------------------------------

M.__meta_map__ = {} ---@type table<integer, eve.state.win.meta.state>

---@param winnr                         integer|nil
---@return eve.state.win.meta.state|nil
function M.get(winnr)
  if winnr ~= nil and eve.win.is_valid(winnr) then
    return M.__meta_map__[winnr]
  end
end

---@param winnr                         integer|nil
---@param meta                          eve.state.win.meta.state
---@return eve.state.win.meta.state|nil
function M.set(winnr, meta)
  if winnr ~= nil and eve.win.is_valid(winnr) then
    M.__meta_map__[winnr] = meta
    return meta
  end
end

---@param winnr                         integer|nil
---@return nil
function M.del(winnr)
  local meta = winnr ~= nil and M.__meta_map__[winnr] or nil ---@type eve.state.win.meta.state|nil
  if winnr ~= nil then
    if meta ~= nil then
      M.__meta_map__[winnr] = nil
      meta.filepath_history:clear()
    end
  end
end

---@param winnr                         integer|nil
---@return eve.state.win.meta.state|nil
function M.fork(winnr)
  local meta = M.resolve(winnr) ---@type eve.state.win.meta.state|nil
  if meta ~= nil then
    ---@type eve.state.win.meta.state
    local meta_forked = {
      filepath_history = meta.filepath_history:fork({ name = "win_filepath" }),
    }
    return meta_forked
  end
end

---@param winnr                         integer|nil
---@return eve.state.win.meta.state|nil
function M.resolve(winnr)
  if winnr == nil or not eve.win.is_valid(winnr) or eve.win.is_sourcefile(winnr) then
    return nil
  end

  local meta = M.__meta_map__[winnr] ---@type eve.state.win.meta.state|nil
  if meta ~= nil then
    return meta
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if not eve.editor.is_buf_sourcefile(bufnr) then
    return nil
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filepath_history = eve.std.AdvanceHistory.new({
    name = "win#bufs",
    capacity = eve.setting.WIN_BUF_HISTORY_CAPACITY,
    validate = eve.editor.is_valid_filepath,
  })
  filepath_history:push(filepath)

  ---@type eve.state.win.meta.state
  meta = {
    filepath_history = filepath_history,
  }
  M.__meta_map__[winnr] = meta
  return meta
end

---@param winnr                         integer|nil
---@return nil
function M.refresh(winnr)
  if M.resolve(winnr) then
    eve.state.status.dirty_winline_nr:next(winnr)
  end
end

---@return nil
function M.refresh_all()
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh(winnr)
  end

  local invalid_winnrs = {} ---@type integer[]
  for winnr in pairs(M.__meta_map__) do
    if not vim.api.nvim_win_is_valid(winnr) then
      table.insert(invalid_winnrs, winnr)
    end
  end
  for _, winnr in ipairs(invalid_winnrs) do
    M.del(winnr)
  end
end

---@param tabnr                         integer|nil
---@return nil
function M.refresh_tabpage_wins(tabnr)
  if tabnr ~= nil and vim.api.nvim_tabpage_is_valid(tabnr) then
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      M.refresh(winnr)
    end
  end
end

---@param winnr                         integer
---@param bufnr                         integer
---@return nil
function M.on_buf_enter(winnr, bufnr)
  if not eve.buf.is_valid(bufnr) or not eve.buf.is_sourcefile(bufnr) then
    return
  end

  if not eve.win.is_valid(winnr) or not eve.win.is_sourcefile(winnr) then
    return
  end

  local meta = M.get(winnr) ---@type eve.state.win.meta.state|nil
  if meta ~= nil then
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    meta.filepath_history:push(filepath)
  end
end

return M
