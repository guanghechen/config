---@class eve.state.tab.buf.data
---@field public filepath               string
---@field public pinned                 boolean

---@class eve.state.tab.buf.state
---@field public bufnr                  integer
---@field public pinned                 boolean

---@class eve.state.tab.meta.data
---@field public tabid                  integer
---@field public tabtype                eve.builtin.tab.TypeEnum
---@field public bufs                   eve.state.tab.buf.data[]

---@class eve.state.tab.meta.state
---@field public tabnr                  integer
---@field public bufs                   eve.state.tab.buf.state[]
---
---@field public dump                   fun(self: eve.state.tab.meta.state, tabid: integer): eve.state.tab.meta.data
---@field public find_buf               fun(self: eve.state.tab.meta.state, bufnr: integer): eve.state.tab.buf.state|nil, integer|nil
---@field public find_bufid             fun(self: eve.state.tab.meta.state, bufnr: integer): integer|nil
---@field public get_bufid_sourcefile   fun(self: eve.state.tab.meta.state): integer|nil
---@field public rearrange_bufs         fun(self: eve.state.tab.meta.state): nil
---@field public toggle_pin             fun(self: eve.state.tab.meta.state, bufnr: integer): nil
local Meta = {}
Meta.__index = Meta

---@class eve.state.tab.data
---@field public list                   eve.state.tab.meta.data[]
---@field public tab_history            eve.std.collection.history.ISerializedData

---@class eve.state.tab.state
---@field public Meta                   eve.state.tab.meta.state
---@field public __meta_map__           table<integer, eve.state.tab.meta.state>
---
---@field public tab_history            eve.std.collection.IAdvanceHistory
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
---
---@field public get_unrefereced_bufnrs fun(bufnrs: integer[]|nil): integer[]
---@field public list_valid_bufs        fun(tabnr: integer): eve.state.tab.buf.state[]

---@class eve.state.tab : eve.state.tab.state
---@field public defaults               fun(): eve.state.tab.data
---@field public dump                   fun(): eve.state.tab.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.tab.data
local M = {}

---@param tabnr                        integer
---@param bufs                         eve.state.tab.buf.state[]|nil
---@return eve.state.tab.meta.state
function Meta.new(tabnr, bufs)
  local self = setmetatable({}, Meta)
  self.tabnr = tabnr ---@type integer
  self.bufs = bufs or {} ---@type eve.state.tab.buf.state[]
  return self
end

---@param tabid                         integer
---@return eve.state.tab.meta.data
function Meta:dump(tabid)
  ---@type eve.state.tab.meta.data
  local data = {
    tabid = tabid,
    tabtype = eve.tab.resolve_type(self.tabnr, false),
    bufs = {},
  }

  for _, buf in ipairs(self.bufs) do
    ---@type eve.state.tab.buf.data
    local data_buf = {
      filepath = vim.api.nvim_buf_get_name(buf.bufnr),
      pinned = buf.pinned,
    }
    data.bufs[#data.bufs + 1] = data_buf
  end
  return data
end

---@param bufnr                         integer
---@return eve.state.tab.buf.state|nil
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
function Meta:get_bufid_sourcefile()
  local bufnr_sourcefile = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return nil
  end
  return self:find_bufid(bufnr_sourcefile)
end

---@return nil
function Meta:rearrange_bufs()
  local bufs = self.bufs ---@type eve.state.tab.buf.state[]
  local N = #bufs ---@type integer
  local k = 1 ---@type integer
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type eve.state.tab.buf.state
    if buf ~= nil and eve.buf.is_valid(buf.bufnr) then
      bufs[k] = buf
      k = k + 1
    end
  end
  for i = k, N, 1 do
    bufs[i] = nil
  end
end

---@param bufnr                         integer
---@return nil
function Meta:toggle_pin(bufnr)
  local bufs = self.bufs ---@type eve.state.tab.buf.state[]
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
          ---@type eve.state.tab.meta.data
          local meta_tab = {
            tabid = item.tabid,
            tabtype = item.tabtype,
            bufs = {},
          }
          local bufs = meta_tab.bufs ---@type eve.state.tab.buf.data[]

          for _, buf in ipairs(item.bufs) do
            if type(buf) == "table" and type(buf.filepath) == "string" and type(buf.pinned) == "boolean" then
              local meta_buf = { filepath = buf.filepath, pinned = buf.pinned } ---@type eve.state.tab.buf.data
              bufs[#bufs + 1] = meta_buf
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
  local list = {} ---@type eve.state.tab.meta.data[]
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for tabid, tabnr in ipairs(tabnrs) do
    local meta = M.resolve(tabnr) ---@type eve.state.tab.meta.state|nil

    if meta ~= nil then
      local meta_tab = meta:dump(tabid) ---@type eve.state.tab.meta.data
      list[#list + 1] = meta_tab
    end
  end

  ---@type eve.std.collection.history.ISerializedData
  local tab_history = M.tab_history and M.tab_history:dump() or { present = 0, stack = {} }

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
---@return nil
function M.load(raw_data)
  M.__meta_map__ = {}

  local data = M.normalize(raw_data) ---@type eve.state.tab.data

  ---@type eve.std.collection.IAdvanceHistory
  local tab_history = M.tab_history
    or eve.std.AdvanceHistory.new({
      name = "tabs",
      capacity = eve.setting.TAB_HISTORY_CAPACITY,
      validate = eve.tab.is_valid,
    })

  local stack = {} ---@type integer[]
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabid in ipairs(data.tab_history.stack) do
    local tabnr = tabnrs[tabid] ---@type integer
    stack[#stack + 1] = tabnr
  end
  tab_history:load({ present = #stack, stack = stack })
  M.tab_history = tab_history

  local filepath2bufnr = eve.nvim.filepath2bufnr() ---@type table<string, integer>
  for _, data_tab in ipairs(data.list) do
    local tabnr = tabnrs[data_tab.tabid] ---@type integer|nil
    if tabnr ~= nil then
      local bufs = {} ---@type eve.state.tab.buf.state[]
      local bufnr_set = {} ---@type table<integer, boolean>

      for _, data_buf in ipairs(data_tab.bufs) do
        local bufnr = filepath2bufnr[data_buf.filepath] ---@type integer|nil
        if bufnr ~= nil and not bufnr_set[bufnr] then
          local buf = { bufnr = bufnr, pinned = data_buf.pinned } ---@type eve.state.tab.buf.state
          bufs[#bufs + 1] = buf
          bufnr_set[bufnr] = true
        end
      end

      local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        if eve.win.is_sourcefile(winnr) then
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          if not bufnr_set[bufnr] and eve.editor.is_buf_sourcefile(bufnr) then
            local buf = { bufnr = bufnr, pinned = false } ---@type eve.state.tab.buf.state
            bufs[#bufs + 1] = buf
            bufnr_set[bufnr] = true
          end
        end
      end

      eve.tab.set_type(tabnr, data_tab.tabtype or eve.tab.Types.NORMAL)

      ---@type eve.state.tab.meta.state
      local meta = Meta.new(tabnr, bufs)
      M.set(tabnr, meta)
    end
  end
end

----------------------------------------------------------------------------------------------------

M.Meta = Meta ---@type eve.state.tab.meta.state
M.__meta_map__ = {} ---@type table<integer, eve.state.tab.meta.state>

---@type eve.std.collection.IAdvanceHistory
M.tab_history = eve.std.AdvanceHistory.new({
  name = "tabs",
  capacity = eve.setting.TAB_HISTORY_CAPACITY,
  validate = eve.tab.is_valid,
})

---@param tabnr                         integer|nil
---@return eve.state.tab.meta.state|nil
function M.get(tabnr)
  if tabnr ~= nil and eve.tab.is_valid(tabnr) then
    return M.__meta_map__[tabnr]
  end
end

---@param tabnr                         integer|nil
---@param meta                          eve.state.tab.meta.state
---@return eve.state.tab.meta.state|nil
function M.set(tabnr, meta)
  if tabnr ~= nil and eve.tab.is_valid(tabnr) then
    M.__meta_map__[tabnr] = meta
    return meta
  end
end

---@param tabnr                         integer|nil
---@return nil
function M.del(tabnr)
  if tabnr ~= nil and tabnr > 0 then
    M.__meta_map__[tabnr] = nil
  end
end

---@param tabnr                         integer|nil
---@return eve.state.tab.meta.state|nil
function M.resolve(tabnr)
  if tabnr == nil or not eve.tab.is_valid(tabnr) then
    return nil
  end

  local meta = M.__meta_map__[tabnr] ---@type eve.state.tab.meta.state|nil
  if meta ~= nil then
    return meta
  end

  local bufs = {} ---@type eve.state.tab.buf.data[]
  local bufnr_set = {} ---@type table<integer, true>
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    if eve.win.is_sourcefile(winnr) then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if not bufnr_set[bufnr] and eve.editor.is_buf_sourcefile(bufnr) then
        bufnr_set[bufnr] = true
        bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.state.tab.buf.state
      end
    end
  end

  ---@type eve.state.tab.meta.state
  meta = Meta.new(tabnr, bufs)
  M.__meta_map__[tabnr] = meta
  return meta
end

---@param tabnr                         integer|nil
---@return nil
function M.refresh(tabnr)
  if tabnr == nil or not eve.tab.is_valid(tabnr) then
    return
  end

  local meta = M.__meta_map__[tabnr] ---@type eve.state.tab.meta.state|nil
  if meta == nil then
    M.resolve(tabnr)
    return
  end

  local bufs = meta.bufs ---@type eve.state.tab.buf.state[]
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    if eve.win.is_sourcefile(winnr) then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if not meta:find_buf(bufnr) and eve.editor.is_buf_sourcefile(bufnr) then
        bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.state.tab.buf.state
      end
    end
  end

  meta:rearrange_bufs()
  eve.tab.resolve_type(tabnr, true)
end

---@return nil
function M.refresh_all()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabnr in ipairs(tabnrs) do
    M.refresh(tabnr)
  end

  local invalid_tabnrs = {} ---@type integer[]
  for tabnr in pairs(M.__meta_map__) do
    if tabnr == nil or not eve.tab.is_valid(tabnr) then
      table.insert(invalid_tabnrs, tabnr)
    end
  end
  for _, tabnr in ipairs(invalid_tabnrs) do
    M.__meta_map__[tabnr] = nil
  end
end

---@param tabnr                         integer
function M.on_buf_delete(tabnr)
  local meta = M.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta ~= nil then
    meta:rearrange_bufs()
  end
end

---@param tabnr                         integer
---@param winnr                         integer
---@param bufnr                         integer
---@return nil
function M.on_buf_enter(tabnr, winnr, bufnr)
  if not eve.buf.is_valid(bufnr) or not eve.buf.is_sourcefile(bufnr) then
    return
  end

  if not eve.win.is_valid(winnr) or not eve.win.is_sourcefile(winnr) then
    return
  end

  local meta = M.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta == nil then
    return
  end

  local bufs = meta.bufs ---@type eve.state.tab.buf.state[]
  local bufid = meta:find_bufid(bufnr) ---@type integer|nil
  if bufid == nil then
    bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.state.tab.buf.state
  end
end

---@param tabnr                         integer
---@param bufnrs                        integer[]
---@return nil
function M.on_bufs_close(tabnr, bufnrs)
  if #bufnrs < 1 then
    return
  end

  local meta = M.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta == nil then
    return
  end

  local bufs = meta.bufs ---@type eve.state.tab.buf.state[]
  local N = #bufs ---@type integer

  local k = 1 ---@type integer
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type eve.state.tab.buf.state
    if not vim.list_contains(bufnrs, buf.bufnr) then
      bufs[k] = buf
      k = k + 1
    end
  end
  for i = k, N, 1 do
    bufs[i] = nil
  end
end

---@param bufnrs                        integer[]|nil
---@return integer[]
function M.get_unrefereced_bufnrs(bufnrs)
  bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]

  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local bufnrs_to_remove = {} ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    if eve.editor.is_buf_sourcefile(bufnr) then
      local has_copy = false ---@type boolean
      for _, tabnr in ipairs(tabnrs) do
        local meta_tab = M.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
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
end

---@param tabnr                         integer
---@return eve.state.tab.buf.state[]
function M.list_valid_bufs(tabnr)
  local meta = M.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta == nil or #meta.bufs < 1 then
    return {}
  end

  meta:rearrange_bufs()
  return meta.bufs
end

return M
