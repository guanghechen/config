---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_source" ---@type string

---Producer records for a result set. UI state and row topology belong to ux.treeview.
---@class era.view.ResultSource
---@field public root                   string
---@field public revision               integer
---@field public records                table<string, {key: string, parent: string|nil, data: table, children: string[]}>
local M = {}
M.__index = M

---@param root                          string
---@param data                          ?table
---@return era.view.ResultSource
function M.new(root, data)
  return setmetatable({
    root = root,
    revision = 0,
    records = { [root] = { key = root, data = data or {}, children = {} } },
  }, M)
end

---@return nil
function M:clear()
  local root = self.records[self.root]
  self.records = { [self.root] = { key = self.root, data = root and root.data or {}, children = {} } }
  self.revision = self.revision + 1
end

---@return nil
function M:dispose()
  self.records = {}
end

---@param key                           ?string
---@return boolean
function M:contains(key)
  return key ~= nil and self.records[key] ~= nil
end

---@param key                           ?string
---@return table|nil
function M:get(key)
  local record = key and self.records[key]
  return record and record.data
end

---@param key                           string
---@return string|nil
function M:parent(key)
  local record = self.records[key]
  return record and record.parent
end

---@param key                           string
---@return string[]|nil
function M:children(key)
  local record = self.records[key]
  return record and record.children
end

---@param parent                        string
---@param key                           string
---@param data                          table
---@param index                         ?integer
---@return era.view.ResultSource
function M:insert(parent, key, data, index)
  assert(not self.records[key], "duplicate result key: " .. key)
  local owner = assert(self.records[parent], "missing result parent: " .. parent)
  self.records[key] = { key = key, parent = parent, data = data, children = {} }
  table.insert(owner.children, index or (#owner.children + 1), key)
  self.revision = self.revision + 1
  return self
end

---@param key                           string
---@param data                          table
---@return nil
function M:update(key, data)
  assert(self.records[key], "missing result key: " .. key).data = data
  self.revision = self.revision + 1
end

---@param key                           string
---@param parent                        string
---@param index                         ?integer
---@return nil
function M:move(key, parent, index)
  local record = assert(self.records[key], "missing result key: " .. key)
  local current = parent
  while current do
    assert(current ~= key, "cyclic result parent")
    current = self:parent(current)
  end
  local target = assert(self.records[parent], "missing result parent: " .. parent)
  local siblings = self:children(record.parent)
  for at, sibling in ipairs(siblings or {}) do
    if sibling == key then
      table.remove(siblings, at)
      break
    end
  end
  record.parent = parent
  table.insert(target.children, index or (#target.children + 1), key)
  self.revision = self.revision + 1
end

---@param root                          ?string
---@param visit                         fun(key: string, data: table): nil
---@return nil
function M:walk(root, visit)
  local pending = { root or self.root }
  while #pending > 0 do
    local key = table.remove(pending)
    local record = self.records[key]
    if record then
      visit(key, record.data)
      local children = self:children(key)
      for index = #children, 1, -1 do
        pending[#pending + 1] = children[index]
      end
    end
  end
end

---@param key                           string
---@return nil
function M:remove(key)
  if key == self.root then
    self:clear()
    return
  end
  local record = self.records[key]
  if not record then
    return
  end
  local keys = {}
  self:walk(key, function(child)
    keys[#keys + 1] = child
  end)
  local siblings = self:children(record.parent)
  for at, sibling in ipairs(siblings or {}) do
    if sibling == key then
      table.remove(siblings, at)
      break
    end
  end
  for _, child in ipairs(keys) do
    self.records[child] = nil
  end
  self.revision = self.revision + 1
end

return M
