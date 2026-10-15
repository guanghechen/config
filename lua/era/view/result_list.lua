---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_list" ---@type string

local LEAF = { nodetype = "leaf" }
local ROOT = { nodetype = "container" }
local EMPTY = {}

---A privately prepared, then immutable flat producer. Native Data owns published topology.
---@class era.view.ResultList
---@field root                          string
---@field revision                      integer
---@field keys                          string[]
---@field labels                        string[]
---@field items                         era.m.picker.composer.list.IItem[]
---@field positions                     table<string, integer>
---@field entries                       table
---@field payloads                      table
---@field metadata                      table
---@field _sealed                       ?boolean
local M = {}
M.__index = M

---@param version                       integer
---@return era.view.ResultList
function M.new(version)
  local keys, labels, items, positions = {}, {}, {}, {}
  local root = { payload_version = version }
  local payloads = setmetatable({}, {
    __index = function(_, key)
      local index = positions[key]
      return index and items[index]
    end,
  })
  local data = setmetatable({ list = root }, {
    __index = function(_, key)
      local index = positions[key]
      return index and labels[index]
    end,
  })
  local entries = setmetatable({ list = ROOT }, {
    __index = function(_, key)
      return positions[key] and LEAF or nil
    end,
  })
  return setmetatable({
    root = "list",
    revision = version,
    keys = keys,
    labels = labels,
    items = items,
    positions = positions,
    entries = entries,
    payloads = payloads,
    metadata = { entries = entries, data = data, payloads = payloads },
  }, M)
end

---@param item                          era.m.picker.composer.list.IItem
---@return nil
function M:append(item)
  assert(not self._sealed, "published List records are immutable")
  assert(type(item.uuid) == "string", "list item identities must be strings")
  local key = "item:" .. item.uuid
  assert(not self.positions[key], "duplicate result key: " .. key)
  local index = #self.keys + 1
  self.keys[index], self.labels[index], self.items[index], self.positions[key] = key, item.text, item, index
end

---@return era.view.ResultList
function M:seal()
  self._sealed = true
  return self
end

---@param key                           ?string
---@return boolean
function M:contains(key)
  return key == self.root or key ~= nil and self.positions[key] ~= nil
end

---@param key                           ?string
---@return table|string|nil
function M:get(key)
  return key and self.metadata.data[key]
end

---@param key                           string
---@return string|nil
function M:parent(key)
  return self.positions[key] and self.root or nil
end

---@param key                           string
---@return string[]|nil
function M:children(key)
  return key == self.root and self.keys or self.positions[key] and EMPTY or nil
end

---@param root                          ?string
---@param visit                         fun(key: string, data: table|string): nil
---@return nil
function M:walk(root, visit)
  if root and root ~= self.root then
    local index = self.positions[root]
    if index then
      visit(root, self.labels[index])
    end
    return
  end
  visit(self.root, self.metadata.data[self.root])
  for index, key in ipairs(self.keys) do
    visit(key, self.labels[index])
  end
end

---@return nil
function M:dispose()
  -- Published metadata may still refer to this version; release it with its last owner.
end

return M
