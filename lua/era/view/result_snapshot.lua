---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_snapshot" ---@type string

---@class era.view.ResultSnapshot
---@field snapshot                      table
local M = {}
M.__index = M

---@return table
local function columns()
  return {
    keys = {},
    parent_keys = {},
    labels = {},
    can_expand = {},
    foldable = {},
    hidden = {},
    scores = {},
    icons = {},
    highlights = {},
    right_texts = {},
    fields = {},
    completeness = {},
  }
end

---Flat file metadata can share an immutable copy; bound inspection and preserve distinct table identities.
---@param value                         table|string
---@param previous                      ?table|string
---@param copies                        table
---@param retained                      table
---@return nil
local function retain(value, previous, copies, retained)
  if
    type(value) ~= "table"
    or not previous
    or copies[value]
    or retained[previous]
    or getmetatable(value) ~= getmetatable(previous)
  then
    return
  end
  local count = 0
  for key, item in pairs(value) do
    local key_type, item_type = type(key), type(item)
    count = count + 1
    if
      count > 16
      or key_type == "table"
      or key_type == "userdata"
      or key_type == "thread"
      or item_type == "table"
      or item_type == "userdata" and item ~= vim.NIL
      or item_type == "thread"
      or rawget(previous, key) ~= item
    then
      return
    end
  end
  for key in pairs(previous) do
    if rawget(value, key) == nil then
      return
    end
  end
  copies[value], retained[previous] = previous, value
end

---@param value                         any
---@param work                          table
---@return any
local function copy(value, work)
  if value == vim.NIL then
    return value
  end
  local kind = type(value)
  if kind == "userdata" or kind == "thread" then
    error("Cannot deepcopy object of type " .. kind)
  end
  if kind ~= "table" then
    return value
  end
  if work.copies[value] then
    return work.copies[value]
  end
  local target = {}
  work.copies[value] = target
  for key, item in pairs(value) do
    work.remaining = work.remaining - 1
    if work.remaining == 0 then
      work.remaining = 1024
      if vim.uv.hrtime() >= work.deadline then
        coroutine.yield()
        work.deadline = vim.uv.hrtime() + 2000000
      end
    end
    target[copy(key, work)] = copy(item, work)
  end
  return setmetatable(target, getmetatable(value))
end

---@param source                        era.view.ResultSource
---@param entries                       table<string, era.view.result_tree.IEntry>
---@param hidden                        table<string, boolean>
---@param present                       fun(key: string, data: table|string, entry: era.view.result_tree.IEntry): table
---@param previous                      ?table
---@param metadata                      ?table
---@return era.view.ResultSnapshot
function M.new(source, entries, hidden, present, previous, metadata)
  local self = setmetatable({
    snapshot = {
      records = not previous and columns() or nil,
      entries = entries,
      data = {},
      payloads = {},
      keys = {},
      signatures = {},
      topology = {},
      updates = previous and {} or nil,
      base_revision = previous and previous.revision,
    },
    _previous = previous,
    _signature = {},
    _copies = {},
  }, M)
  local retained = {}
  self._produce_records = function()
    source:walk(nil, function(key, data)
      self.snapshot.data[key] = data
      self.snapshot.payloads[key] = source.payloads and source.payloads[key]
      local entry = entries[key] or { nodetype = "container" }
      if metadata then
        retain(data, metadata.data[key], self._copies, retained)
        retain(entry, metadata.entries[key], self._copies, retained)
      end
      local item = present(key, data, entry)
      item.key, item.parent = key, source:parent(key)
      item.can_expand = entry.nodetype == "container" or entry.locations ~= nil and #entry.locations > 0
      item.foldable = entry.nodetype == "container" and entry.foldable ~= false
      item.hidden = hidden[key] == true
      coroutine.yield(item)
      for _, location in ipairs(entry.locations or {}) do
        if metadata then
          retain(location, metadata.entries[location.locationuuid], self._copies, retained)
        end
        local row = present(location.locationuuid, data, location)
        row.key, row.parent = location.locationuuid, key
        row.hidden = hidden[row.key] == true
        coroutine.yield(row)
      end
    end)
  end
  self._produce = coroutine.create(self._produce_records)
  return self
end

---Only a full replacement needs to retain every presentation record until import.
---@return nil
function M:_restart_import()
  self._previous = nil
  self.snapshot.records, self.snapshot.updates = columns(), nil
  self.snapshot.signatures, self.snapshot.topology = {}, {}
  self._produce = coroutine.create(self._produce_records)
end

---Bound presentation and graph copying independently; shared metadata and cycles retain their identity.
---@return boolean
function M:step()
  if self._produce then
    local deadline = vim.uv.hrtime() + 2000000
    for _ = 1, 256 do
      local ok, record = coroutine.resume(self._produce)
      if not ok then
        error(record)
      end
      if coroutine.status(self._produce) == "dead" then
        if self._previous and #self._previous.topology ~= #self.snapshot.topology then
          self:_restart_import()
          return false
        end
        self._produce, self._produce_records, self._signature = nil, nil, nil
        self._copy = coroutine.create(function()
          return copy({ entries = self.snapshot.entries, data = self.snapshot.data }, {
            copies = self._copies,
            remaining = 1024,
            deadline = vim.uv.hrtime() + 2000000,
          })
        end)
        break
      end
      local records = self.snapshot.records
      if records then
        -- Optional columns acquire defaults only in the bounded import chunk.
        local at = #records.keys + 1
        records.keys[at], records.parent_keys[at] = record.key, record.parent or false
        records.labels[at] = record.label or false
        records.can_expand[at], records.foldable[at], records.hidden[at] =
          record.can_expand or nil, record.foldable or nil, record.hidden or nil
        if record.score ~= nil and record.score ~= 0 then
          records.scores[at] = record.score
        end
        records.icons[at], records.highlights[at], records.right_texts[at] =
          record.icon or nil, record.highlight or nil, record.right_text or nil
        records.fields[at] = record.fields or nil
        records.completeness[at] = record.completeness ~= "complete" and record.completeness or nil
      end
      local snapshot, previous = self.snapshot, self._previous
      local index = #snapshot.topology + 1
      snapshot.topology[index], snapshot.topology[index + 1] = record.key, record.parent or false
      -- Exact bytes avoid retaining a second graph of presentation tables or relying on hash equality.
      local signature
      if
        type(record.label) == "string"
        and not record.can_expand
        and not record.foldable
        and not record.hidden
        and (record.score == nil or record.score == 0)
        and record.icon == nil
        and record.highlight == nil
        and record.right_text == nil
        and record.fields == nil
        and (record.completeness == nil or record.completeness == "complete")
      then
        signature = "s" .. record.label
      else
        local values = self._signature
        values[1], values[2], values[3], values[4] =
          record.label or vim.NIL, record.can_expand or false, record.foldable or false, record.hidden or false
        values[5], values[6], values[7], values[8], values[9], values[10] =
          record.score == nil and vim.NIL or record.score,
          record.icon == nil and vim.NIL or record.icon,
          record.highlight == nil and vim.NIL or record.highlight,
          record.right_text == nil and vim.NIL or record.right_text,
          record.fields == nil and vim.NIL or record.fields,
          record.completeness == nil and vim.NIL or record.completeness
        signature = "m" .. vim.mpack.encode(values)
      end
      snapshot.signatures[record.key] = signature
      if snapshot.updates then
        if previous.topology[index] ~= record.key or previous.topology[index + 1] ~= (record.parent or false) then
          self:_restart_import()
          return false
        elseif previous.signatures[record.key] ~= signature then
          if type(record.label) ~= "string" or record.completeness and record.completeness ~= "complete" then
            self:_restart_import()
            return false
          end
          snapshot.updates[#snapshot.updates + 1] = record
          if #snapshot.updates > 256 then
            self:_restart_import()
            return false
          end
        end
      end
      if vim.uv.hrtime() >= deadline then
        return false
      end
    end
    return false
  end
  local ok, payload = coroutine.resume(self._copy)
  if not ok then
    error(payload)
  end
  if coroutine.status(self._copy) == "dead" then
    self.snapshot.entries, self.snapshot.data = payload.entries, payload.data
    self._copy, self._copies = nil, nil
    return true
  end
  return false
end

return M
