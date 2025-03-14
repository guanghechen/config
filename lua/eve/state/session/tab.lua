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
---@field public bufid_sourcefile       integer

---@class eve.state.tab.meta.state
---@field public tabnr                  integer
---@field public tabtype                eve.e.state.tab.meta.TabType
---@field public bufs                   eve.t.state.tab.buf.state[]
---@field public bufid_sourcefile       eve.collection.IObservable -- integer|nil>
---@field public winnr_command          eve.collection.IObservable -- integer|nil>
---@field public winnr_fixed            eve.collection.IObservable -- integer|nil>
---
---@field public dump                   fun(self: eve.state.tab.meta.state, tabid: integer): eve.t.state.tab.meta.data
---@field public find_buf               fun(self: eve.state.tab.meta.state, bufnr: integer): eve.t.state.tab.buf.state|nil, integer|nil
---@field public find_bufid             fun(self: eve.state.tab.meta.state, bufnr: integer): integer|nil
---@field public focus_win_fixed        fun(self: eve.state.tab.meta.state): nil
---@field public get_winnr_fixed        fun(self: eve.state.tab.meta.state): integer|nil
---@field public get_winnr_command      fun(self: eve.state.tab.meta.state): integer|nil
---@field public get_bufnr_sourcefile   fun(self: eve.state.tab.meta.state): integer|nil
---@field public get_winnr_sourcefile   fun(self: eve.state.tab.meta.state): integer|nil
---@field public rearrange_bufs         fun(self: eve.state.tab.meta.state): nil
---@field public resolve_bufnr_sourcefile fun(self: eve.state.tab.meta.state, bufnr_sourcefile: integer|nil): integer|nil
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
---@field public refresh                fun(tabnr: integer|nil): nil
---@field public refresh_all            fun(): nil
---
---@field public on_buf_delete          fun(tabnr: integer): nil
---@field public on_buf_enter           fun(tabnr: integer, winnr: integer, bufnr: integer): nil
---@field public on_bufs_close          fun(tabnr: integer, bufnrs: integer[]): nil
---@field public on_win_focus           fun(tabnr: integer, winnr: integer): nil
---
---@field public focus_win_fixed        fun(tabnr: integer): nil
---@field public get_bufnr_sourcefile   fun(tabnr: integer): integer|nil
---@field public get_tabtype            fun(tabnr: integer): eve.e.state.tab.meta.TabType
---@field public get_winnr_command      fun(tabnr: integer): integer|nil
---@field public get_winnr_fixed        fun(tabnr: integer): integer|nil
---@field public get_winnr_sourcefile   fun(tabnr: integer): integer|nil
---@field public get_unrefereced_bufnrs fun(bufnrs: integer[]|nil): integer[]
---@field public list_valid_bufs        fun(tabnr: integer): eve.t.state.tab.buf.state[]
local S = {}

---@class eve.state.tab
---@field public defaults               fun(): eve.state.tab.data
---@field public dump                   fun(): eve.state.tab.data
---@field public load                   fun(data: unknown): eve.state.tab.state
---@field public normalize              fun(data: unknown): eve.state.tab.data
local M = {}

---@param tabnr                        integer
---@param tabtype                      eve.e.state.tab.meta.TabType|nil
---@param bufs                         eve.t.state.tab.buf.state[]|nil
---@param bufid_sourcefile             integer
---@return eve.state.tab.meta.state
function Meta.new(tabnr, tabtype, bufs, bufid_sourcefile)
  local self = setmetatable({}, Meta)
  self.tabnr = tabnr ---@type integer
  self.tabtype = tabtype or eve.setting.tabtypes.NORMAL ---@type string
  self.bufs = bufs or {} ---@type eve.t.state.tab.buf.state[]
  self.bufid_sourcefile = eve.col.Observable.from_value(math.max(0, math.min(#bufs, bufid_sourcefile or 1)))
  self.winnr_command = eve.col.Observable.from_value(0)
  self.winnr_fixed = eve.col.Observable.from_value(0)
  return self
end

---@param tabid                         integer
---@return eve.t.state.tab.meta.data
function Meta:dump(tabid)
  ---@type eve.t.state.tab.meta.data
  local data = {
    tabid = tabid,
    tabtype = self.tabtype,
    bufs = {},
    bufid_sourcefile = self.bufid_sourcefile:snapshot(),
  }

  for _, buf in ipairs(self.bufs) do
    ---@type eve.t.state.tab.buf.data
    local data_buf = {
      filepath = vim.api.nvim_buf_get_name(buf.bufnr),
      pinned = buf.pinned,
    }
    data.bufs[#data.bufs + 1] = data_buf
  end
  return data
end

---@param bufnr                         integer
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
---@return integer|nil
function Meta:find_bufid(bufnr)
  for index, buf in ipairs(self.bufs) do
    if buf.bufnr == bufnr then
      return index
    end
  end
  return nil
end

---@return integer|nil
function Meta:focus_win_fixed()
  local winnr = self:get_winnr_fixed() ---@type integer|nil
  if winnr ~= nil then
    vim.api.nvim_tabpage_set_win(self.tabnr, winnr)
  end
end

---@return integer|nil
function Meta:get_bufnr_sourcefile()
  local bufid = self.bufid_sourcefile:snapshot() ---@type integer
  local buf = self.bufs[bufid] ---@type eve.t.state.tab.buf.state|nil
  return buf and buf.bufnr or nil
end

---@return integer|nil
function Meta:get_winnr_command()
  local winnr_command = self.winnr_command:snapshot() ---@type integer
  if eve.nvim.is_win_valid(winnr_command) then
    return winnr_command
  else
    self.winnr_command:next(0)
    return nil
  end
end

---@return integer|nil
function Meta:get_winnr_fixed()
  local winnr_fixed = self.winnr_fixed:snapshot() ---@type integer
  if eve.nvim.is_win_valid(winnr_fixed) then
    return winnr_fixed
  else
    self.winnr_fixed:next(0)
    return nil
  end
end

---@return integer|nil
function Meta:get_winnr_sourcefile()
  local bufnr_sourcefile = self:get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return nil
  end

  local winnr_current = vim.api.nvim_tabpage_get_win(self.tabnr) ---@type integer
  if vim.api.nvim_win_get_buf(winnr_current) == bufnr_sourcefile then
    return winnr_current
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(self.tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    if vim.api.nvim_win_get_buf(winnr) == bufnr_sourcefile then
      return winnr
    end
  end
end

---@return nil
function Meta:rearrange_bufs()
  local bufs = self.bufs ---@type eve.t.state.tab.buf.state[]
  local N = #bufs ---@type integer
  local k = 1 ---@type integer
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type eve.t.state.tab.buf.state
    if buf ~= nil and eve.nvim.is_buf_valid(buf.bufnr) then
      bufs[k] = buf
      k = k + 1
    end
  end
  for i = k, N, 1 do
    bufs[i] = nil
  end
end

---@param bufnr_sourcefile              integer|nil
---@return integer|nil
function Meta:resolve_bufnr_sourcefile(bufnr_sourcefile)
  local bufid_next = bufnr_sourcefile ~= nil and self:find_bufid(bufnr_sourcefile) or nil ---@type integer|nil
  if bufid_next == nil then
    local winnr = vim.api.nvim_tabpage_get_win(self.tabnr) ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufid_next = self:find_bufid(bufnr) ---@type integer|nil
  end
  if bufid_next == nil or bufid_next < 1 then
    bufid_next = math.min(1, #self.bufs) ---@type integer
  end
  self.bufid_sourcefile:next(bufid_next)
  return bufid_next
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

  tab_history = eve.col.AdvanceHistory.new({
    name = "tabs",
    capacity = eve.setting.TAB_HISTORY_CAPACITY,
    validate = eve.nvim.is_tab_valid,
  }),

  get = function(tabnr)
    if tabnr ~= nil and eve.nvim.is_tab_valid(tabnr) then
      return S.__meta_map__[tabnr]
    end
  end,
  set = function(tabnr, meta)
    if tabnr ~= nil and eve.nvim.is_tab_valid(tabnr) then
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
    if tabnr == nil or not eve.nvim.is_tab_valid(tabnr) then
      return nil
    end

    local meta = S.__meta_map__[tabnr] ---@type eve.state.tab.meta.state|nil
    if meta ~= nil then
      return meta
    end

    local tabtype = eve.editor.calc_tabtype(tabnr) ---@type string
    local bufs = {} ---@type eve.t.state.tab.buf.data[]
    local bufnr_set = {} ---@type table<integer, true>
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    local bufid_sourcefile = 0 ---@type integer

    local winnr_current = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    local bufnr_current = vim.api.nvim_win_get_buf(winnr_current) ---@type integer
    for _, winnr in ipairs(winnrs) do
      if eve.editor.is_win_sourcefile(winnr) then
        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        if not bufnr_set[bufnr] and eve.editor.is_buf_sourcefile(bufnr) then
          bufnr_set[bufnr] = true
          bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
          if bufnr == bufnr_current then
            bufid_sourcefile = #bufs
          end
        end
      end
    end

    if bufid_sourcefile < 1 and #bufs > 0 then
      bufid_sourcefile = 1
    end

    ---@type eve.state.tab.meta.state
    meta = Meta.new(tabnr, tabtype, bufs, bufid_sourcefile)
    S.__meta_map__[tabnr] = meta
    return meta
  end,
  refresh = function(tabnr)
    if tabnr == nil or not eve.nvim.is_tab_valid(tabnr) then
      return
    end

    local meta = S.__meta_map__[tabnr] ---@type eve.state.tab.meta.state|nil
    if meta == nil then
      S.resolve(tabnr)
      return
    end

    local bufnr_sourcefile = meta:get_bufnr_sourcefile() ---@type integer|nil
    local bufs = meta.bufs ---@type eve.t.state.tab.buf.state[]

    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      if eve.editor.is_win_sourcefile(winnr) then
        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        if not meta:find_buf(bufnr) and eve.editor.is_buf_sourcefile(bufnr) then
          bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
        end
      end
    end

    meta:rearrange_bufs()
    meta:resolve_bufnr_sourcefile(bufnr_sourcefile)

    local tabtype = eve.editor.calc_tabtype(tabnr) ---@type string
    meta.tabtype = tabtype
  end,
  refresh_all = function()
    local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
    for _, tabnr in ipairs(tabnrs) do
      S.refresh(tabnr)
    end

    local invalid_tabnrs = {} ---@type integer[]
    for tabnr in pairs(S.__meta_map__) do
      if tabnr == nil or not eve.nvim.is_tab_valid(tabnr) then
        table.insert(invalid_tabnrs, tabnr)
      end
    end
    for _, tabnr in ipairs(invalid_tabnrs) do
      S.__meta_map__[tabnr] = nil
    end
  end,
  on_buf_delete = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta ~= nil then
      meta:rearrange_bufs()
    end
  end,
  on_buf_enter = function(tabnr, winnr, bufnr)
    if not eve.nvim.is_buf_valid(bufnr) or not eve.editor.is_buf_sourcefile(bufnr) then
      return
    end

    if not eve.nvim.is_win_valid(winnr) or not eve.editor.is_win_sourcefile(winnr) then
      return
    end

    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta == nil then
      return
    end

    local bufs = meta.bufs ---@type eve.t.state.tab.buf.state[]
    local bufid = meta:find_bufid(bufnr) ---@type integer|nil
    if bufid == nil then
      bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
      bufid = #bufs
    end
    meta.bufid_sourcefile:next(bufid)
  end,
  on_bufs_close = function(tabnr, bufnrs)
    if #bufnrs < 1 then
      return
    end

    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta == nil then
      return
    end

    local bufnr_sourcefile = meta:get_bufnr_sourcefile() ---@type integer|nil
    local bufs = meta.bufs ---@type eve.t.state.tab.buf.state[]
    local N = #bufs ---@type integer

    local k = 1 ---@type integer
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

    meta:resolve_bufnr_sourcefile(bufnr_sourcefile)
  end,
  on_win_focus = function(tabnr, winnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta == nil then
      return
    end

    local is_float = eve.nvim.is_win_floating(winnr) ---@type boolean
    if not is_float then
      meta.winnr_fixed:next(winnr)
      meta.winnr_command:next(winnr)
    end
  end,
  focus_win_fixed = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta ~= nil then
      meta:focus_win_fixed()
    end
  end,
  get_bufnr_sourcefile = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    return meta and meta:get_bufnr_sourcefile() or nil ---@type integer|nil
  end,
  get_tabtype = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    return meta and meta.tabtype or eve.setting.tabtypes.NORMAL
  end,
  get_winnr_command = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    return meta and meta:get_winnr_command() or nil ---@type integer|nil
  end,
  get_winnr_fixed = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    return meta and meta:get_winnr_fixed() or nil ---@type integer|nil
  end,
  get_winnr_sourcefile = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    return meta and meta:get_winnr_sourcefile() or nil ---@type integer|nil
  end,
  get_unrefereced_bufnrs = function(bufnrs)
    bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]

    local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
    local bufnrs_to_remove = {} ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      if eve.editor.is_buf_sourcefile(bufnr) then
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
  list_valid_bufs = function(tabnr)
    local meta = S.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
    if meta == nil or #meta.bufs < 1 then
      return {}
    end

    meta:rearrange_bufs()
    return meta.bufs
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
          and type(item.bufid_sourcefile) == "number"
        then
          ---@type eve.t.state.tab.meta.data
          local meta_tab = {
            tabid = item.tabid,
            tabtype = item.tabtype,
            bufs = {},
            bufid_sourcefile = item.bufid_sourcefile,
          }
          local bufs = meta_tab.bufs ---@type eve.t.state.tab.buf.data[]

          for bufid, buf in ipairs(item.bufs) do
            if type(buf) == "table" and type(buf.filepath) == "string" and type(buf.pinned) == "boolean" then
              local meta_buf = { filepath = buf.filepath, pinned = buf.pinned } ---@type eve.t.state.tab.buf.data
              bufs[#bufs + 1] = meta_buf
              if bufid == item.bufid_sourcefile then
                meta_tab.bufid_sourcefile = #bufs
              end
            end
          end
          table.insert(resolved.list, meta_tab)
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
      local meta_tab = meta:dump(tabid) ---@type eve.t.state.tab.meta.data
      list[#list + 1] = meta_tab
    end
  end

  ---@type eve.collection.history.ISerializedData
  local tab_history = S.tab_history and S.tab_history:dump() or { present = 0, stack = {} }

  local stack = {} ---@type integer[]
  for _, tabnr in ipairs(tab_history.stack) do
    local tabid = eve.table.find_index(tabnrs, tabnr) ---@type integer|nil
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
    or eve.col.AdvanceHistory.new({
      name = "tabs",
      capacity = eve.setting.TAB_HISTORY_CAPACITY,
      validate = eve.nvim.is_tab_valid,
    })

  local stack = {} ---@type integer[]
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabid in ipairs(data.tab_history.stack) do
    local tabnr = tabnrs[tabid] ---@type integer
    stack[#stack + 1] = tabnr
  end
  tab_history:load({ present = #stack, stack = stack })
  S.tab_history = tab_history

  local filepath2bufnr = eve.nvim.filepath2bufnr() ---@type table<string, integer>
  for _, data_tab in ipairs(data.list) do
    local tabnr = tabnrs[data_tab.tabid] ---@type integer|nil
    local bufid_sourcefile = 0 ---@type integer
    if tabnr ~= nil then
      local bufs = {} ---@type eve.t.state.tab.buf.state[]
      local bufnr_set = {} ---@type table<integer, boolean>

      for bufid, data_buf in ipairs(data_tab.bufs) do
        local bufnr = filepath2bufnr[data_buf.filepath] ---@type integer|nil
        if bufnr ~= nil and not bufnr_set[bufnr] then
          local buf = { bufnr = bufnr, pinned = data_buf.pinned } ---@type eve.t.state.tab.buf.state
          bufs[#bufs + 1] = buf
          bufnr_set[bufnr] = true
          if bufid == data_tab.bufid_sourcefile then
            bufid_sourcefile = bufid
          end
        end
      end

      local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        if eve.editor.is_win_sourcefile(winnr) then
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          if not bufnr_set[bufnr] and eve.editor.is_buf_sourcefile(bufnr) then
            local buf = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
            bufs[#bufs + 1] = buf
            bufnr_set[bufnr] = true
          end
        end
      end

      ---@type eve.state.tab.meta.state
      local meta = Meta.new(tabnr, data_tab.tabtype or eve.setting.tabtypes.NORMAL, bufs, bufid_sourcefile)
      S.set(tabnr, meta)
    end
  end

  return S
end

return M
