---@diagnostic disable: invisible
local __module_name__ = "std.source.notepad-sqlite" ---@type string

local sqlite_ffi = require("std.source.sqlite-ffi")

---@class std.source.NotepadSqliteSource : std.t.INotepadSource
---@field public name                   string
---@field protected filepath            string
---@field protected default_item_name   fun(): string
---@field protected flush_scheduler     std.collection.Scheduler|nil Debounced flush scheduler
---@field protected _data               std.t.INotepadSourceSaveData|nil Internal data cache
---@field protected _conn               std.source.sqlite.IConnection|nil Database connection
---@field protected _dirty_items        table<string, boolean> Track modified items
---@field protected _dirty_orders       boolean Track if orders changed
---@field protected _dirty_active       boolean Track if active_uuid changed
local M = {}
M.__index = M

local FLUSH_DEBOUNCE_MS = 3000 ---@type integer milliseconds
local SCHEMA_VERSION = 1

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

---@param config                        std.t.INotepadSourceConfig
---@return std.source.NotepadSqliteSource
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self.filepath = config.filepath
  self.default_item_name = config.default_item_name
  self._data = nil
  self._conn = nil
  self._dirty_items = {}
  self._dirty_orders = false
  self._dirty_active = false

  self.flush_scheduler = std.Scheduler.new({
    name = "notepad-sqlite-flush",
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

---Get or create database connection
---@private
---@return std.source.sqlite.IConnection
function M:_get_conn()
  if self._conn ~= nil then
    return self._conn
  end

  local dirpath = std.path.dirname(self.filepath)
  vim.fn.mkdir(dirpath, "p")

  self._conn = sqlite_ffi.Connection.new(self.filepath, {
    timeout_ms = 5000,
  })

  return self._conn
end

---Initialize database schema
---@private
---@return nil
function M:_init_schema()
  local conn = self:_get_conn()

  conn:exec([[
    CREATE TABLE IF NOT EXISTS notes (
      uuid TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CHECK(created_at GLOB '????-??-??T??:??:??Z'),
      CHECK(updated_at GLOB '????-??-??T??:??:??Z')
    );
  ]])

  conn:exec([[
    CREATE TABLE IF NOT EXISTS metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  ]])

  conn:exec([[
    CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at DESC);
  ]])

  local version_row = conn:prepare("SELECT value FROM metadata WHERE key = 'schema_version'"):execute_one()
  if version_row == nil then
    conn:prepare("INSERT INTO metadata (key, value) VALUES (?, ?)"):bind("schema_version", tostring(SCHEMA_VERSION)):execute()
  end
end

---Create default note if database is empty
---@private
---@return nil
function M:_ensure_default_note()
  local conn = self:_get_conn()
  local note_count_row = conn:prepare("SELECT COUNT(*) as count FROM notes"):execute_one()
  local note_count = note_count_row and note_count_row.count or 0

  if note_count == 0 then
    local uuid = rstd.fn.uuid()
    local now = now_iso_utc()
    local name = normalize_name(nil, self.default_item_name)

    conn:transaction(function()
      conn:prepare("INSERT INTO notes (uuid, name, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)")
        :bind(uuid, name, "", now, now)
        :execute()
      conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)"):bind("note_orders", vim.json.encode({ uuid })):execute()
      conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)"):bind("activated_item_uuid", uuid):execute()
    end)
  end
end

---Schedule a debounced flush operation
---@private
---@return nil
function M:_schedule_flush()
  if self.flush_scheduler ~= nil then
    self.flush_scheduler:schedule()
  end
end

---Mark orders as dirty (called when orders are modified externally)
---@return nil
function M:mark_orders_dirty()
  self._dirty_orders = true
  self:_schedule_flush()
end

---Mark active uuid as dirty (called when active item changes)
---@return nil
function M:mark_active_dirty()
  self._dirty_active = true
  self:_schedule_flush()
end

---@param force                         boolean
---@return std.t.INotepadSourceSaveData
function M:load(force)
  if self._data ~= nil and not force then
    return self._data
  end

  self:_init_schema()
  self:_ensure_default_note()

  local conn = self:_get_conn()

  local rows = conn:prepare([[
    SELECT uuid, name, content, created_at, updated_at
    FROM notes
    ORDER BY updated_at DESC, uuid ASC
  ]]):execute()

  local items_map = {} ---@type table<string, std.t.INotepadItem>
  local default_orders = {} ---@type string[]

  for _, row in ipairs(rows) do
    items_map[row.uuid] = {
      uuid = row.uuid,
      name = row.name,
      content = row.content,
      created_at = row.created_at,
      updated_at = row.updated_at,
    }
    default_orders[#default_orders + 1] = row.uuid
  end

  local orders_row = conn:prepare("SELECT value FROM metadata WHERE key = 'note_orders'"):execute_one()
  local orders = default_orders ---@type string[]

  if orders_row ~= nil and type(orders_row.value) == "string" then
    local ok, decoded = pcall(vim.json.decode, orders_row.value)
    if ok and type(decoded) == "table" then
      local valid_orders = {} ---@type string[]
      local seen = {} ---@type table<string, boolean>

      for _, uuid in ipairs(decoded) do
        if items_map[uuid] ~= nil then
          valid_orders[#valid_orders + 1] = uuid
          seen[uuid] = true
        end
      end

      for _, uuid in ipairs(default_orders) do
        if not seen[uuid] then
          valid_orders[#valid_orders + 1] = uuid
        end
      end

      orders = valid_orders
    end
  end

  local active_row = conn:prepare("SELECT value FROM metadata WHERE key = 'activated_item_uuid'"):execute_one()
  local active_uuid = active_row and active_row.value or orders[1]

  if active_uuid == nil or items_map[active_uuid] == nil then
    active_uuid = orders[1]
  end

  self._data = {
    items = items_map,
    orders = orders,
    active_uuid = active_uuid,
  }

  self._dirty_items = {}
  self._dirty_orders = false
  self._dirty_active = false

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

  self._dirty_items[uuid] = true
  self._dirty_orders = true
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
    self._dirty_items[uuid] = true
    self:_schedule_flush()
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
  self._dirty_items[uuid] = true
  self:_schedule_flush()

  return true
end

---@param uuid                          string
---@return boolean
function M:remove(uuid)
  local data = self:load(false) ---@type std.t.INotepadSourceSaveData

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

  self._dirty_items[uuid] = true
  self._dirty_orders = true
  self:_schedule_flush()

  return true
end

---@return boolean
function M:flush()
  if self._data == nil then
    return true
  end

  if self.flush_scheduler ~= nil then
    self.flush_scheduler:cancel()
  end

  local conn = self:_get_conn()

  local ok, err = pcall(function()
    conn:transaction(function()
      local delete_note_stmt = conn:prepare("DELETE FROM notes WHERE uuid = ?")
      local check_exists_stmt = conn:prepare("SELECT 1 FROM notes WHERE uuid = ?")
      local insert_note_stmt = conn:prepare("INSERT INTO notes (uuid, name, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)")
      local update_note_stmt = conn:prepare("UPDATE notes SET name = ?, content = ?, updated_at = ? WHERE uuid = ?")

      for uuid, _ in pairs(self._dirty_items) do
        local item = self._data.items[uuid]

        if item == nil then
          delete_note_stmt:bind(uuid):execute()
        else
          local exists_row = check_exists_stmt:bind(uuid):execute_one()

          if exists_row == nil then
            insert_note_stmt:bind(item.uuid, item.name, item.content, item.created_at, item.updated_at):execute()
          else
            update_note_stmt:bind(item.name, item.content, item.updated_at, uuid):execute()
          end
        end
      end

      if self._dirty_orders then
        conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)")
          :bind("note_orders", vim.json.encode(self._data.orders))
          :execute()
      end

      if self._dirty_active and self._data.active_uuid ~= nil then
        conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)")
          :bind("activated_item_uuid", self._data.active_uuid)
          :execute()
      end
    end)
  end)

  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "Flush Failed",
      message = "Failed to write notes to SQLite database",
      details = { filepath = self.filepath, error = err },
    })
    return false
  end

  self._dirty_items = {}
  self._dirty_orders = false
  self._dirty_active = false

  return true
end

---Export to standard JSON format
---@return std.t.INotepadSourceJsonData
function M:dump_to_json()
  local data = self:load(false)
  local items = {}

  for _, uuid in ipairs(data.orders) do
    local item = data.items[uuid]
    if item ~= nil then
      items[#items + 1] = {
        uuid = item.uuid,
        name = item.name,
        content = item.content,
        created_at = item.created_at,
        updated_at = item.updated_at,
      }
    end
  end

  return {
    items = items,
    orders = vim.deepcopy(data.orders),
    activated_item_uuid = data.active_uuid,
  }
end

---Import from standard JSON format
---@param json_data                     std.t.INotepadSourceJsonData
---@return boolean
function M:load_from_json(json_data)
  if type(json_data) ~= "table" then
    return false
  end

  local conn = self:_get_conn()

  local ok, err = pcall(function()
    conn:transaction(function()
      conn:prepare("DELETE FROM notes"):execute()

      if type(json_data.items) == "table" then
        local insert_note_stmt = conn:prepare("INSERT INTO notes (uuid, name, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)")

        for _, entry in ipairs(json_data.items) do
          if type(entry) == "table" and type(entry.uuid) == "string" and #entry.uuid > 0 then
            local uuid = entry.uuid
            local name = normalize_name(entry.name, self.default_item_name)
            local content = type(entry.content) == "string" and entry.content or ""
            local created_at = type(entry.created_at) == "string" and entry.created_at or now_iso_utc()
            local updated_at = type(entry.updated_at) == "string" and entry.updated_at or created_at

            insert_note_stmt:bind(uuid, name, content, created_at, updated_at):execute()
          end
        end
      end

      if type(json_data.orders) == "table" then
        conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)")
          :bind("note_orders", vim.json.encode(json_data.orders))
          :execute()
      end

      local activated_uuid = json_data.activated_item_uuid
      if type(activated_uuid) == "string" and #activated_uuid > 0 then
        conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)")
          :bind("activated_item_uuid", activated_uuid)
          :execute()
      end
    end)
  end)

  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "Import Failed",
      message = "Failed to import JSON data to SQLite",
      details = { error = err },
    })
    return false
  end

  self._data = nil
  self:load(true)

  return true
end

return M
