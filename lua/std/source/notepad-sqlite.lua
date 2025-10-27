---@diagnostic disable: invisible
local __module_name__ = "std.source.notepad-sqlite" ---@type string

local sqlite_ffi = require("std.source.sqlite-ffi")

---@class std.source.INotepadSqliteSourceConfig
---@field public name                   string Unique source identifier
---@field public filepath               string Absolute path to SQLite database file
---@field public default_item_name      fun(): string Default name generator for untitled items

---@class std.source.NotepadSqliteSource : std.t.INotepadSource
---@field public name                   string
---@field protected filepath            string
---@field protected default_item_name   fun(): string
---@field protected flush_scheduler     std.collection.Scheduler|nil Debounced flush scheduler
---@field protected _data               std.t.INotepadSourceSaveData|nil Internal data cache
---@field protected _conn               std.source.sqlite.IConnection|nil Database connection
---@field protected _dirty_items        table<string, boolean> Track modified items
local M = {}
M.__index = M

local FLUSH_DEBOUNCE_MS = 3000 ---@type integer milliseconds
local SCHEMA_VERSION = 1
local MAX_POSITION = 999999 ---@type integer Fallback position for notes without explicit order

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

---@param config                        std.source.INotepadSqliteSourceConfig
---@return std.source.NotepadSqliteSource
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self.filepath = config.filepath
  self.default_item_name = config.default_item_name
  self._data = nil
  self._conn = nil
  self._dirty_items = {}

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
    CREATE TABLE IF NOT EXISTS note_orders (
      uuid TEXT PRIMARY KEY REFERENCES notes(uuid) ON DELETE CASCADE,
      position INTEGER NOT NULL UNIQUE
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
      conn:prepare("INSERT INTO note_orders (uuid, position) VALUES (?, ?)"):bind(uuid, 1):execute()
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
    SELECT n.uuid, n.name, n.content, n.created_at, n.updated_at, o.position
    FROM notes n
    LEFT JOIN note_orders o ON n.uuid = o.uuid
    ORDER BY COALESCE(o.position, ?)
  ]]):bind(MAX_POSITION):execute()

  local items_map = {} ---@type table<string, std.t.INotepadItem>
  local orders = {} ---@type string[]

  for _, row in ipairs(rows) do
    items_map[row.uuid] = {
      uuid = row.uuid,
      name = row.name,
      content = row.content,
      created_at = row.created_at,
      updated_at = row.updated_at,
    }
    orders[#orders + 1] = row.uuid
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
      local delete_order_stmt = conn:prepare("DELETE FROM note_orders WHERE uuid = ?")
      local check_exists_stmt = conn:prepare("SELECT 1 FROM notes WHERE uuid = ?")
      local insert_note_stmt = conn:prepare("INSERT INTO notes (uuid, name, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)")
      local update_note_stmt = conn:prepare("UPDATE notes SET name = ?, content = ?, updated_at = ? WHERE uuid = ?")

      for uuid, _ in pairs(self._dirty_items) do
        local item = self._data.items[uuid]

        if item == nil then
          delete_note_stmt:bind(uuid):execute()
          delete_order_stmt:bind(uuid):execute()
        else
          local exists_row = check_exists_stmt:bind(uuid):execute_one()

          if exists_row == nil then
            insert_note_stmt:bind(item.uuid, item.name, item.content, item.created_at, item.updated_at):execute()
          else
            update_note_stmt:bind(item.name, item.content, item.updated_at, uuid):execute()
          end
        end
      end

      conn:prepare("DELETE FROM note_orders"):execute()
      local insert_order_stmt = conn:prepare("INSERT INTO note_orders (uuid, position) VALUES (?, ?)")
      for position, uuid in ipairs(self._data.orders) do
        insert_order_stmt:bind(uuid, position):execute()
      end

      if self._data.active_uuid ~= nil then
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

  return true
end

return M
