local functional = require("eve.builtin.functional")
local AdvanceHistory = require("eve.collection.history_advance")
local fts = require("eve.constant.filetype")
local setting = require("eve.constant.setting")

local checks = require("eve.lib.checks")

---@alias eve.e.state.tab.meta.TabType
---| "normal"
---| "diffview"

---@class eve.t.state.tab.buf.data
---@field public filepath               string
---@field public pinned                 boolean

---@class eve.t.state.tab.buf.state
---@field public bufnr                  integer
---@field public pinned                 boolean

---@class eve.t.state.tab.meta.data
---@field public tabid                  integer
---@field public tabtype                eve.e.state.tab.meta.TabType
---@field public bufs                   eve.t.state.tab.buf.data[]

---@class eve.state.tab.meta.state
---@field public tabnr                  integer
---@field public tabtype                eve.e.state.tab.meta.TabType
---@field public winnr_listed           integer
---@field public bufs                   eve.t.state.tab.buf.state[]
---@field public find_buf               fun(self: eve.state.tab.meta.state, bufnr: integer): eve.t.state.tab.buf.state|nil, integer|nil
---@field public toggle_pin             fun(self: eve.state.tab.meta.state, bufnr: integer): nil
local Meta = {}
Meta.__index = Meta

---@class eve.state.tab.data
---@field public list                   eve.t.state.tab.meta.data[]
---@field public tab_history            eve.collection.history.ISerializedData

---@class eve.state.tab.state
---@field public Meta                   eve.state.tab.meta.state
---@field public __meta_map__           table<integer, eve.state.tab.meta.state>
---
---@field public tab_history            eve.collection.IAdvanceHistory
---
---@field public get                    fun(tabnr: integer|nil): eve.state.tab.meta.state|nil
---@field public set                    fun(tabnr: integer|nil, meta: eve.state.tab.meta.state): eve.state.tab.meta.state|nil
---@field public del                    fun(tabnr: integer|nil): nil
---@field public resolve                fun(tabnr: integer|nil): eve.state.tab.meta.state|nil
---@field public resolve_tabtype        fun(tabnr: integer|nil): eve.e.state.tab.meta.TabType
---@field public resolve_winnr_listed   fun(tabnr: integer|nil): integer
---@field public refresh                fun(tabnr: integer|nil): nil
---@field public refresh_all            fun(): nil
---
---@field public on_buf_enter           fun(winnr: integer, bufnr: integer): nil
---@field public on_bufs_close          fun(tabnr: integer, bufnrs: integer[]): nil
---
---@field public calc_tabtype           fun(tabnr: integer): eve.e.state.tab.meta.TabType
---@field public get_current_winnr      fun(): integer
---@field public get_current_bufnr      fun(): integer
---@field public get_visible_bufnrs     fun(tabnr: integer|nil): integer[]
---@field public get_unrefereced_bufnrs fun(bufnrs?: integer[]): integer[]
local S = {}

---@class eve.state.tab
---@field public defaults               fun(): eve.state.tab.data
---@field public dump                   fun(): eve.state.tab.data
---@field public load                   fun(data: unknown): eve.state.tab.state
---@field public normalize              fun(data: unknown): eve.state.tab.data
local M = {}

---@param tabnr                        integer
---@param tabtype                      eve.e.state.tab.meta.TabType|nil
---@param winnr_listed                 integer|nil
---@param bufs                         eve.t.state.tab.buf.state[]|nil
---@return eve.state.tab.meta.state
function Meta.new(tabnr, tabtype, winnr_listed, bufs)
  local self = setmetatable({}, Meta)
  self.tabnr = tabnr ---@type integer
  self.tabtype = tabtype or setting.TT_NORMAL ---@type string
  self.winnr_listed = winnr_listed or S.resolve_winnr_listed() ---@type integer
  self.bufs = bufs or {} ---@type eve.t.state.tab.buf.state[]
  return self
end

---@return eve.t.state.tab.buf.state|nil
---@return integer|nil
function Meta:find_buf(bufnr)
  for index, buf in ipairs(self.bufs) do
    if buf.bufnr == bufnr then
      return buf, index
    end
  end
  return nil, nil
end

---@param bufnr                         integer
---@return nil
function Meta:toggle_pin(bufnr)
  local bufs = self.bufs ---@type eve.t.state.tab.buf.state[]
  local buf, i = self:find_buf(bufnr)
  if i == nil or buf == nil then
    return
  end

  if buf.pinned then
    local j = i + 1 ---@type integer
    while j <= #bufs do
      if not bufs[j].pinned then
        break
      end

      bufs[j - 1] = buf[j]
      j = j + 1
    end
    bufs[j - 1] = buf
    return
  end

  local j = i - 1 ---@type integer
  while j >= 1 do
    if bufs[j].pinned then
      break
    end
    bufs[j + 1] = bufs[j]
    j = j - 1
  end

  buf.pinned = not buf.pinned
  bufs[j + 1] = buf
end

---@type eve.state.tab.state
S = {
  Meta = Meta,
  __meta_map__ = {},

  tab_history = AdvanceHistory.new({
    name = "tabs",
    capacity = setting.TAB_HISTORY_CAPACITY,
    validate = checks.is_tab_valid,
  }),

  get = function(tabnr)
    if tabnr ~= nil and tabnr > 0 and vim.api.nvim_tabpage_is_valid(tabnr) then
      return S.__meta_map__[tabnr]
    end
  end,
  set = function(tabnr, meta)
    if tabnr ~= nil and tabnr > 0 and vim.api.nvim_tabpage_is_valid(tabnr) then
      S.__meta_map__[tabnr] = meta
      return meta
    end
  end,
  del = function(tabnr)
    if tabnr ~= nil and tabnr > 0 then
      S.__meta_map__[tabnr] = nil
    end
  end,
  resolve = function(tabnr)
    if tabnr == nil or tabnr < 1 then
      return nil
    end

    local meta = S.__meta_map__[tabnr] ---@type eve.state.tab.meta.state|nil
    if meta ~= nil then
      return meta
    end

    if not checks.is_tab_valid(tabnr) then
      return nil
    end

    local tabtype = S.calc_tabtype(tabnr) ---@type string

    local bufs = {} ---@type eve.t.state.tab.buf.data[]
    local bufnr_set = {} ---@type table<integer, true>
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      if not checks.is_win_floating(winnr) then
        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        if not bufnr_set[bufnr] and checks.is_buf_valid(bufnr) then
          bufnr_set[bufnr] = true
          bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
        end
      end
    end

    ---@type eve.state.tab.meta.state
    meta = Meta.new(tabnr, tabtype, 0, bufs)
    S.__meta_map__[tabnr] = meta
    return meta
  end,
  resolve_tabtype = function(tabnr)
    if tabnr == nil or tabnr < 1 then
      return setting.TT_NORMAL
    end

    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    return meta and meta.tabtype or setting.TT_NORMAL
  end,
  resolve_winnr_listed = function(tabnr)
    if tabnr == nil or tabnr < 1 then
      return 0
    end

    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta ~= nil and checks.is_win_valid(meta.winnr_listed) then
      return meta.winnr_listed
    end

    local winnr_cur = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    if checks.is_win_valid(winnr_cur) then
      meta.winnr_listed = winnr_cur
      return winnr_cur
    end

    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      if checks.is_win_valid(winnr) then
        meta.winnr_listed = winnr
        return winnr
      end
    end
    return 0
  end,
  refresh = function(tabnr)
    if tabnr == nil or tabnr < 1 then
      return
    end

    local meta = S.__meta_map__[tabnr] ---@type eve.state.tab.meta.state|nil
    if meta == nil then
      S.resolve(tabnr)
      return
    end

    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    local bufs = meta.bufs ---@type eve.t.state.tab.buf.state[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if not meta:find_buf(bufnr) then
        bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
      end
    end

    local k = 1 ---@type integer
    local N = #bufs ---@type integer
    for i = 1, N, 1 do
      local buf = bufs[i] ---@type eve.t.state.tab.buf.state
      if checks.is_buf_valid(buf.bufnr) then
        bufs[k] = buf
        k = k + 1
      end
    end
    for i = k, N, 1 do
      bufs[i] = nil
    end

    S.resolve_winnr_listed(tabnr)

    local tabtype = S.calc_tabtype(tabnr) ---@type string
    meta.tabtype = tabtype
  end,
  refresh_all = function()
    local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
    for _, tabnr in ipairs(tabnrs) do
      S.refresh(tabnr)
    end

    local invalid_tabnrs = {} ---@type integer[]
    for tabnr in pairs(S.__meta_map__) do
      if tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
        table.insert(invalid_tabnrs, tabnr)
      end
    end
    for _, tabnr in ipairs(invalid_tabnrs) do
      S.__meta_map__[tabnr] = nil
    end
  end,
  on_buf_enter = function(winnr, bufnr)
    if not checks.is_win_valid(winnr) or not checks.is_buf_valid(bufnr) then
      return
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta == nil then
      return
    end

    local winnr_listed = checks.is_win_valid(winnr) and winnr or S.resolve_winnr_listed(tabnr) ---@type integer
    meta.winnr_listed = winnr_listed

    local bufs = meta.bufs ---@type eve.t.state.tab.buf.state[]
    if not meta:find_buf(bufnr) then
      bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
    end
  end,
  on_bufs_close = function(tabnr, bufnrs)
    if #bufnrs < 1 then
      return
    end

    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta == nil then
      return
    end

    local bufs = meta.bufs ---@type eve.t.state.tab.buf.state[]
    local k = 1 ---@type integer
    local N = #bufs ---@type integer
    for i = 1, N, 1 do
      local buf = bufs[i] ---@type eve.t.state.tab.buf.state
      if not vim.list_contains(bufnrs, buf.bufnr) then
        bufs[k] = buf
        k = k + 1
      end
    end
    for i = k, N, 1 do
      bufs[i] = nil
    end
  end,
  calc_tabtype = function(tabnr)
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

    ---! Check if the diffview tab
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local filetype = vim.bo[bufnr].filetype ---@type string
      if filetype == fts.DIFFVIEW_FILES or filetype == fts.DIFFVIEW_FILE_HISTORY then
        return setting.TT_DIFFVIEW
      end
    end

    return setting.TT_NORMAL ---@type string
  end,
  get_current_winnr = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    return S.resolve_winnr_listed(tabnr) ---@type integer
  end,
  get_current_bufnr = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    local winnr = meta and meta.winnr_listed or 0 ---@type integer
    return winnr > 0 and vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) or 0
  end,
  get_visible_bufnrs = function(tabnr)
    if tabnr == nil or tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
      return {}
    end

    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    local bufnrs = {} ---@type table<integer, boolean>
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      bufnrs[bufnr] = true
    end
    return bufnrs
  end,
  get_unrefereced_bufnrs = function(bufnrs)
    bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]

    local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
    local bufnrs_to_remove = {} ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      if checks.is_buf_valid(bufnr) then
        local has_copy = false ---@type boolean
        for _, tabnr in ipairs(tabnrs) do
          local meta_tab = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
          if meta_tab ~= nil and meta_tab:find_buf(bufnr) ~= nil then
            has_copy = true
            break
          end
        end
        if not has_copy then
          table.insert(bufnrs_to_remove, bufnr)
        end
      end
    end
    return bufnrs_to_remove
  end,
}

---@return eve.state.tab.data
function M.defaults()
  ---@type eve.state.tab.data
  return {
    list = {},
    tab_history = { present = 0, stack = {} },
  }
end

---@param data                        any
---@return eve.state.tab.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.tab.data
  if type(data) == "table" then
    if type(data.list) == "table" then
      for _, item in ipairs(data.list) do
        if
          type(item) == "table"
          and type(item.tabid) == "number"
          and type(item.tabtype) == "string"
          and type(item.bufs) == "table"
        then
          ---@type eve.t.state.tab.meta.data
          local meta_tab = {
            tabid = item.tabid,
            tabtype = item.tabtype,
            bufs = {},
          }
          table.insert(resolved.list, meta_tab)

          for _, buf in ipairs(item.bufs) do
            if type(buf) == "table" and type(buf.filepath) == "string" and type(buf.pinned) == "boolean" then
              ---@type eve.t.state.tab.buf.data
              local meta_buf = { filepath = buf.filepath, pinned = buf.pinned }
              table.insert(meta_tab.bufs, meta_buf)
            end
          end
        end
      end
    end

    if type(data.tab_history) == "table" then
      if type(data.tab_history.present) == "number" then
        resolved.tab_history.present = data.tab_history.present
      end
      if type(data.tab_history.stack) == "table" then
        resolved.tab_history.stack = data.tab_history.stack
      end
    end
  end

  ---@type eve.state.tab.data
  return resolved
end

---@return eve.state.tab.data
function M.dump()
  local list = {} ---@type eve.t.state.tab.meta.data[]
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for tabid, tabnr in ipairs(tabnrs) do
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil

    if meta ~= nil then
      ---@type eve.t.state.tab.meta.data
      local meta_tab = {
        tabid = tabid,
        tabtype = meta.tabtype,
        bufs = {},
      }

      list[#list + 1] = meta_tab
      for _, buf in ipairs(meta.bufs) do
        ---@type eve.t.state.tab.buf.data
        local meta_buf = {
          filepath = vim.api.nvim_buf_get_name(buf.bufnr),
          pinned = buf.pinned,
        }
        meta_tab.bufs[#meta_tab.bufs + 1] = meta_buf
      end
    end
  end

  ---@type eve.collection.history.ISerializedData
  local tab_history = S.tab_history and S.tab_history:dump() or { present = 0, stack = {} }

  local stack = {} ---@type integer[]
  for _, tabnr in ipairs(tab_history.stack) do
    local tabid = functional.find_index(tabnrs, tabnr) ---@type integer|nil
    if tabid ~= nil then
      stack[#stack + 1] = tabid
    end
  end
  tab_history.present = #stack
  tab_history.stack = stack

  ---@type eve.state.tab.data
  return {
    list = list,
    tab_history = tab_history,
  }
end

---@param raw_data                      any
---@return eve.state.tab.state
function M.load(raw_data)
  S.__meta_map__ = {}

  local data = M.normalize(raw_data) ---@type eve.state.tab.data

  ---@type eve.collection.IAdvanceHistory
  local tab_history = S.tab_history
    or AdvanceHistory.new({
      name = "tabs",
      capacity = setting.TAB_HISTORY_CAPACITY,
      validate = checks.is_tab_valid,
    })

  local stack = {} ---@type integer[]
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabid in ipairs(data.tab_history.stack) do
    local tabnr = tabnrs[tabid] ---@type integer
    stack[#stack + 1] = tabnr
  end
  tab_history:load({ present = #stack, stack = stack })
  S.tab_history = tab_history

  local filepath2bufnr = functional.filepath2bufnr() ---@type table<string, integer>
  for _, data_tab in ipairs(data.list) do
    local tabnr = tabnrs[data_tab.tabid] ---@type integer|nil
    if tabnr ~= nil then
      local bufs = {} ---@type eve.t.state.tab.buf.state[]
      local bufnr_set = {} ---@type table<integer, boolean>

      for _, data_buf in ipairs(data_tab.bufs) do
        local bufnr = filepath2bufnr[data_buf.filepath] ---@type integer|nil
        if bufnr ~= nil and not bufnr_set[bufnr] then
          local buf = { bufnr = bufnr, pinned = data_buf.pinned } ---@type eve.t.state.tab.buf.state
          bufs[#bufs + 1] = buf
          bufnr_set[bufnr] = true
        end
      end

      local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        if checks.is_win_valid(winnr) then
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          if not bufnr_set[bufnr] and checks.is_buf_valid(bufnr) then
            local buf = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
            bufs[#bufs + 1] = buf
            bufnr_set[bufnr] = true
          end
        end
      end

      ---@type eve.state.tab.meta.state
      local meta = Meta.new(tabnr, data_tab.tabtype or setting.TT_NORMAL, 0, bufs)
      S.set(tabnr, meta)
    end
  end

  return S
end

return M
