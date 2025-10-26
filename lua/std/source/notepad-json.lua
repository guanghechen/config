---@diagnostic disable: invisible
local __module_name__ = "std.source.notepad-json" ---@type string

---@class std.source.INotepadJsonSourceConfig
---@field public name                   string Unique source identifier
---@field public filepath               string Absolute path to JSON file
---@field public default_item_name      fun(): string Default name generator for untitled items

---@class std.source.NotepadJsonSource : std.t.INotepadSource
---@field public name                   string
---@field protected filepath            string
---@field protected default_item_name   fun(): string
---@field protected flush_scheduler     std.collection.Scheduler|nil Debounced flush scheduler
---@field protected _data               std.t.INotepadSourceSaveData|nil Internal data cache
local M = {}
M.__index = M

local FLUSH_DEBOUNCE_MS = 3000 ---@type integer milliseconds

---@return string
local function now_iso_utc()
  return tostring(os.date("!%Y-%m-%dT%H:%M:%SZ"))
end

---@param name                          string|nil
---@param default_name                  fun(): string
---@return string
local function normalize_name(name, default_name)
  if type(name) == "string" then
    name = vim.trim(name)
  else
    name = ""
  end
  if #name == 0 then
    return default_name()
  end
  return name
end

---@param items_map                     table<string, std.t.INotepadItem>
---@param orders                        string[]
---@return nil
local function cleanup_orders(items_map, orders)
  local filtered = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>
  for _, uuid in ipairs(orders) do
    if items_map[uuid] ~= nil and not seen[uuid] then
      filtered[#filtered + 1] = uuid
      seen[uuid] = true
    end
  end
  for uuid in pairs(items_map) do
    if not seen[uuid] then
      filtered[#filtered + 1] = uuid
      seen[uuid] = true
    end
  end
  for i = 1, #filtered do
    orders[i] = filtered[i]
  end
  for i = #filtered + 1, #orders do
    orders[i] = nil
  end
end

---@param config                        std.source.INotepadJsonSourceConfig
---@return std.source.NotepadJsonSource
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self.filepath = config.filepath
  self.default_item_name = config.default_item_name
  self._data = nil

  -- Create debounced flush scheduler
  self.flush_scheduler = std.Scheduler.new({
    name = "notepad-json-flush",
    mode = "debounce",
    ---@diagnostic disable-next-line: unused-local
    task = function(scheduler, context, callback)
      self:flush()
      callback(true, nil)
    end,
    value = std.Observable.from_value(nil),
    delay = FLUSH_DEBOUNCE_MS,
    timeout = 0,
  })

  return self
end

---Schedule a debounced flush operation
---@private
---@return nil
function M:_schedule_flush()
  if self.flush_scheduler ~= nil then
    self.flush_scheduler:schedule()
  end
end

---@param force                         boolean
---@return std.t.INotepadSourceSaveData
function M:load(force)
  if self._data ~= nil and not force then
    return self._data
  end

  local items_map = {} ---@type table<string, std.t.INotepadItem>
  local orders = {} ---@type string[]
  local active_uuid = nil ---@type string|nil

  local ok, result = pcall(function()
    local raw_data = std.fs.read_json({
      filepath = self.filepath,
      silent_on_bad_path = true,
      silent_on_bad_json = false,
    })

    if type(raw_data) == "table" then
      -- Parse items
      local raw_items = raw_data.items
      if type(raw_items) == "table" then
        for _, entry in ipairs(raw_items) do
          if type(entry) == "table" then
            local uuid = type(entry.uuid) == "string" and entry.uuid or nil
            if uuid ~= nil and #uuid > 0 then
              local created_at = type(entry.created_at) == "string" and entry.created_at or now_iso_utc()
              local updated_at = type(entry.updated_at) == "string" and entry.updated_at or created_at
              local original_name = type(entry.name) == "string" and entry.name or nil
              local name = normalize_name(original_name, self.default_item_name)

              items_map[uuid] = {
                uuid = uuid,
                name = name,
                content = type(entry.content) == "string" and entry.content or "",
                created_at = created_at,
                updated_at = updated_at,
              }
            end
          end
        end
      end

      -- Parse orders
      local raw_orders = raw_data.orders
      if type(raw_orders) == "table" then
        for _, uuid in ipairs(raw_orders) do
          if type(uuid) == "string" and #uuid > 0 then
            orders[#orders + 1] = uuid
          end
        end
      end

      -- Parse active UUID
      local activated = raw_data.activated_item_uuid
      if type(activated) == "string" and items_map[activated] ~= nil then
        active_uuid = activated
      end
    end

    cleanup_orders(items_map, orders)

    -- Ensure at least one note exists
    if #orders == 0 then
      local uuid = rstd.fn.uuid()
      local now = now_iso_utc()
      local item = {
        uuid = uuid,
        name = normalize_name(nil, self.default_item_name),
        content = "",
        created_at = now,
        updated_at = now,
      }
      items_map[uuid] = item
      orders[1] = uuid
      active_uuid = uuid
    elseif active_uuid == nil then
      active_uuid = orders[1]
    end

    return true
  end)

  -- Error handling for corrupted JSON
  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "Load Failed",
      message = "Failed to load notes from JSON file",
      details = { filepath = self.filepath, error = result },
    })

    -- Return empty state on error
    items_map = {}
    orders = {}

    -- Create default note even on error
    local uuid = rstd.fn.uuid()
    local now = now_iso_utc()
    local item = {
      uuid = uuid,
      name = normalize_name(nil, self.default_item_name),
      content = "",
      created_at = now,
      updated_at = now,
    }
    items_map[uuid] = item
    orders[1] = uuid
    active_uuid = uuid
  end

  self._data = {
    items = items_map,
    orders = orders,
    active_uuid = active_uuid,
  }

  return self._data
end

---@return std.t.INotepadItemMeta[]
function M:list()
  local data = self:load(false) ---@type std.t.INotepadSourceSaveData
  return data.items
end

---@param uuid                          string
---@return std.t.INotepadItem|nil
function M:retrieve(uuid)
  local data = self:load(false) ---@type std.t.INotepadSourceSaveData
  return data.items[uuid]
end

---@param name                          string|nil
---@param content                       string|nil
---@return std.t.INotepadItem
function M:create(name, content)
  local uuid = rstd.fn.uuid()
  local now = now_iso_utc()
  local normalized_name = normalize_name(name, self.default_item_name)
  local item = {
    uuid = uuid,
    name = normalized_name,
    content = content or "",
    created_at = now,
    updated_at = now,
  }

  local data = self:load(false) ---@type std.t.INotepadSourceSaveData
  data.items[uuid] = item
  data.orders[#data.orders + 1] = uuid
  self:_schedule_flush()
  return item
end

---@param uuid                          string
---@param item_data                     std.t.INotepadItemData
---@return boolean
function M:update(uuid, item_data)
  local data = self:load(false) ---@type std.t.INotepadSourceSaveData

  local item = data.items[uuid]
  if item == nil then
    return false
  end

  local modified = false

  local normalized_name = normalize_name(item_data.name, self.default_item_name)
  if normalized_name ~= item.name then
    item.name = normalized_name
    modified = true
  end

  if item_data.content ~= item.content then
    item.content = item_data.content
    modified = true
  end

  if modified then
    item.updated_at = now_iso_utc()
  end
  return modified
end

---@param uuid                          string|nil
---@param text                          string
---@return boolean
function M:append_content(uuid, text)
  if type(text) ~= "string" or #text == 0 then
    return false
  end

  local data = self:load(false) ---@type std.t.INotepadSourceSaveData

  uuid = uuid or data.active_uuid
  if uuid == nil then
    return false
  end

  local item = data.items[uuid]
  if item == nil then
    return false
  end

  local existing = type(item.content) == "string" and item.content or ""
  local new_content = existing .. text

  if new_content == item.content then
    return false
  end

  item.content = new_content
  item.updated_at = now_iso_utc()
  self:_schedule_flush()
  return true
end

---@param uuid                          string
---@return boolean
function M:remove(uuid)
  local data = self:load(false) ---@type std.t.INotepadSourceSaveData

  -- Reject if last note
  if #data.orders <= 1 then
    std.reporter.warn({
      from = __module_name__,
      subject = "Delete Rejected",
      message = "Cannot delete the last note",
    })
    return false
  end

  if data.items[uuid] == nil then
    return false
  end

  data.items[uuid] = nil
  std.table.filter_inline(data.orders, function(element)
    return element ~= uuid
  end)

  self:_schedule_flush()
  return true
end

---@return boolean
function M:flush()
  if self._data == nil then
    return true
  end

  -- Cancel any pending flush
  if self.flush_scheduler ~= nil then
    self.flush_scheduler:cancel()
  end

  if self.filepath == nil or #self.filepath == 0 then
    return false
  end

  -- Error handling for file write failures
  local ok, err = pcall(function()
    local dirpath = std.path.dirname(self.filepath)
    vim.fn.mkdir(dirpath, "p")

    cleanup_orders(self._data.items, self._data.orders)

    -- Build items array
    local items = {}
    local existing = {}
    for _, uuid in ipairs(self._data.orders) do
      local item = self._data.items[uuid]
      if item ~= nil then
        items[#items + 1] = {
          uuid = item.uuid,
          name = item.name,
          content = item.content,
          created_at = item.created_at,
          updated_at = item.updated_at,
        }
        existing[uuid] = true
      end
    end

    -- Add any items not in orders
    for uuid, item in pairs(self._data.items) do
      if not existing[uuid] then
        items[#items + 1] = {
          uuid = item.uuid,
          name = item.name,
          content = item.content,
          created_at = item.created_at,
          updated_at = item.updated_at,
        }
      end
    end

    local save_data = {
      items = items,
      orders = self._data.orders,
      activated_item_uuid = self._data.active_uuid or vim.NIL,
    }

    std.fs.write_json(self.filepath, save_data, true)
  end)

  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "Flush Failed",
      message = "Failed to write notes to JSON file",
      details = { filepath = self.filepath, error = err },
    })
    return false
  end

  return true
end

return M
