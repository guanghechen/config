---@diagnostic disable: invisible
local __module_name__ = "std.source.notepad-sqlite" ---@type string

local sqlite_ffi = require("std.source.sqlite-ffi")

---@class std.t.INotepadSourceSqliteState : std.t.INotepadSourceState
---SQLite-specific state (inherits all fields from INotepadSourceState)

---@class std.source.NotepadSqliteSource : std.t.INotepadSource
---@field protected default_item_name   fun(): string
---@field protected flush_scheduler     std.collection.Scheduler|nil Debounced flush scheduler
---@field protected _state              std.t.INotepadSourceSqliteState|nil Internal state cache
---@field protected _conn               std.source.sqlite.IConnection|nil Database connection
---@field protected _dirty_orders       boolean Track if orders changed
---@field protected _dirty_active       boolean Track if active_uuid changed
local M = {}
M.__index = M

local FLUSH_DEBOUNCE_MS = 3000 ---@type integer milliseconds
local SCHEMA_VERSION = 1

---@param config                        std.t.INotepadSourceConfig
---@return std.source.NotepadSqliteSource
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self.filepath = config.filepath
  self.default_item_name = config.default_item_name
  self._state = nil
  self._conn = nil
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
    local now = std.notepad.now_iso_utc()
    local name = std.notepad.normalize_name(nil, self.default_item_name)

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

---Load note content on demand
---@private
---@param item                          std.t.INotepadItemState
---@return nil
function M:_load_note_content(item)
  if item.original ~= nil then
    return
  end

  local raw_content = item._raw_content
  if type(raw_content) == "string" then
    item.content = raw_content
    item.original = raw_content
    item._raw_content = nil
  else
    item.content = ""
    item.original = ""
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
---@return std.t.INotepadSourceSqliteState
function M:load(force)
  if self._state ~= nil and not force then
    return self._state
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
  local name_to_uuid = {} ---@type table<string, string>
  local default_orders = {} ---@type string[]

  for _, row in ipairs(rows) do
    items_map[row.uuid] = {
      uuid = row.uuid,
      name = row.name,
      content = nil,
      original = nil,
      created_at = row.created_at,
      updated_at = row.updated_at,
      _raw_content = row.content,
    }
    name_to_uuid[row.name] = row.uuid
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

  local history, history_index = std.notepad.initialize_history(active_uuid)

  self._state = {
    items = items_map,
    orders = orders,
    active_uuid = active_uuid,
    name_to_uuid = name_to_uuid,
    note_uuid_history = history,
    history_index = history_index,
  }

  self._dirty_orders = false
  self._dirty_active = false

  return self._state
end

---@return std.t.INotepadItemMeta[]
function M:list()
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState
  local result = {} ---@type std.t.INotepadItemMeta[]

  for _, uuid in ipairs(state.orders) do
    local item = state.items[uuid]
    if item ~= nil then
      result[#result + 1] = {
        uuid = item.uuid,
        name = item.name,
        created_at = item.created_at,
        updated_at = item.updated_at,
      }
    end
  end

  return result
end

---@return string|nil
function M:get_activated_uuid()
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState
  return state.active_uuid
end

---@param uuid                          string|nil
---@return boolean
function M:set_activated_uuid(uuid)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  if uuid == nil then
    state.active_uuid = nil
    self._dirty_active = true
    self:_schedule_flush()
    return true
  end

  if state.items[uuid] == nil then
    return false
  end

  if state.active_uuid == uuid then
    return true
  end

  state.active_uuid = uuid
  self._dirty_active = true
  self:_schedule_flush()
  return true
end

---@param uuid                          string
---@param createIfNonexistent           boolean|nil
---@return std.t.INotepadItemState|nil
function M:retrieve(uuid, createIfNonexistent)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState
  local item = state.items[uuid]

  if item == nil and createIfNonexistent then
    return self:create(nil, nil)
  end

  if item ~= nil then
    self:_load_note_content(item)
  end

  return item
end

---@param name                          string
---@param createIfNonexistent           boolean|nil
---@return std.t.INotepadItemState|nil
function M:retrieve_by_name(name, createIfNonexistent)
  if type(name) ~= "string" or #name == 0 then
    return nil
  end

  local normalized_name = std.notepad.normalize_name(name, self.default_item_name)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  local uuid = state.name_to_uuid[normalized_name]
  if uuid ~= nil then
    local item = state.items[uuid]
    if item ~= nil then
      self:_load_note_content(item)
    end
    return item
  end

  if createIfNonexistent then
    return self:create(normalized_name, nil)
  end

  return nil
end

---@param name                          string|nil
---@param content                       string|nil
---@return std.t.INotepadItemState
function M:create(name, content)
  local normalized_name = std.notepad.normalize_name(name, self.default_item_name)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  -- Check if note with this name already exists using index
  local existing_uuid = state.name_to_uuid[normalized_name]
  if existing_uuid ~= nil then
    local existing_item = state.items[existing_uuid]
    self:_load_note_content(existing_item)
    return existing_item
  end

  local uuid = rstd.fn.uuid()
  local now = std.notepad.now_iso_utc()

  local initial_content = content or ""
  local item = {
    uuid = uuid,
    name = normalized_name,
    content = initial_content,
    original = initial_content,
    created_at = now,
    updated_at = now,
  }

  state.items[uuid] = item
  state.name_to_uuid[normalized_name] = uuid
  state.orders[#state.orders + 1] = uuid

  self._dirty_orders = true
  self:_schedule_flush()

  return item
end

---@param uuid                          string
---@param item_data                     std.t.INotepadItemData
---@return boolean
function M:update(uuid, item_data)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:_load_note_content(item)

  local modified = false

  local normalized_name = std.notepad.normalize_name(item_data.name, self.default_item_name)
  if normalized_name ~= item.name then
    -- Check if new name conflicts with another note using index
    local has_conflict = std.notepad.check_name_conflict(state.name_to_uuid, normalized_name, uuid)
    if has_conflict then
      std.reporter.warn({
        from = __module_name__,
        subject = "Update Rejected",
        message = string.format("Note with name '%s' already exists", normalized_name),
      })
      return false
    end

    -- Update name index
    std.notepad.update_name_index(state.name_to_uuid, item.name, normalized_name, uuid)
    item.name = normalized_name
    modified = true
  end

  if item_data.content ~= item.content then
    item.content = item_data.content
    modified = true
  end

  if modified then
    item.updated_at = std.notepad.now_iso_utc()
    self:_schedule_flush()
  end

  return modified
end

---@param uuid                          string
---@param new_name                      string
---@return boolean
function M:rename(uuid, new_name)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:_load_note_content(item)

  local normalized_name = std.notepad.normalize_name(new_name, self.default_item_name)

  if normalized_name == item.name then
    return false
  end

  -- Check if new name conflicts with another note using index
  local has_conflict = std.notepad.check_name_conflict(state.name_to_uuid, normalized_name, uuid)
  if has_conflict then
    std.reporter.warn({
      from = __module_name__,
      subject = "Rename Rejected",
      message = string.format("Note with name '%s' already exists", normalized_name),
    })
    return false
  end

  -- Update name index
  std.notepad.update_name_index(state.name_to_uuid, item.name, normalized_name, uuid)
  item.name = normalized_name
  item.updated_at = std.notepad.now_iso_utc()
  self:_schedule_flush()

  return true
end

---@param uuid                          string|nil
---@param text                          string
---@return boolean
function M:append_content(uuid, text)
  if type(text) ~= "string" or #text == 0 then
    return false
  end

  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  uuid = uuid or state.active_uuid
  if uuid == nil then
    return false
  end

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:_load_note_content(item)

  local existing = type(item.content) == "string" and item.content or ""
  local new_content = existing .. text

  if new_content == item.content then
    return false
  end

  item.content = new_content
  item.updated_at = std.notepad.now_iso_utc()
  self:_schedule_flush()

  return true
end

---@param uuid                          string
---@return boolean
function M:remove(uuid)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  if #state.orders <= 1 then
    std.reporter.warn({
      from = __module_name__,
      subject = "Delete Rejected",
      message = "Cannot delete the last note",
    })
    return false
  end

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  -- Remove from name index
  std.notepad.remove_from_name_index(state.name_to_uuid, item.name)
  state.items[uuid] = nil
  std.table.filter_inline(state.orders, function(element)
    return element ~= uuid
  end)

  self._dirty_orders = true
  self:_schedule_flush()

  return true
end

---@param uuid                          string
---@return nil
function M:push_history(uuid)
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  if state.items[uuid] == nil then
    return
  end

  -- Remove all forward history when pushing new entry
  if state.history_index > 0 and state.history_index < #state.note_uuid_history then
    for i = #state.note_uuid_history, state.history_index + 1, -1 do
      state.note_uuid_history[i] = nil
    end
  end

  -- Don't add duplicate if already at the top
  if #state.note_uuid_history > 0 and state.note_uuid_history[#state.note_uuid_history] == uuid then
    return
  end

  state.note_uuid_history[#state.note_uuid_history + 1] = uuid
  state.history_index = #state.note_uuid_history
end

---@return boolean
function M:can_go_backward()
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState
  return state.history_index > 1
end

---@return boolean
function M:can_go_forward()
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState
  return state.history_index > 0 and state.history_index < #state.note_uuid_history
end

---@return string|nil
function M:go_backward()
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  -- Keep going back until we find a valid note or reach the start
  while state.history_index > 1 do
    state.history_index = state.history_index - 1
    local uuid = state.note_uuid_history[state.history_index]

    -- Return the first valid note we find
    if uuid ~= nil and state.items[uuid] ~= nil then
      return uuid
    end
  end

  return nil
end

---@return string|nil
function M:go_forward()
  local state = self:load(false) ---@type std.t.INotepadSourceSqliteState

  -- Keep going forward until we find a valid note or reach the end
  while state.history_index < #state.note_uuid_history do
    state.history_index = state.history_index + 1
    local uuid = state.note_uuid_history[state.history_index]

    -- Return the first valid note we find
    if uuid ~= nil and state.items[uuid] ~= nil then
      return uuid
    end
  end

  return nil
end

---@return boolean
function M:flush()
  if self._state == nil then
    return true
  end

  if self.flush_scheduler ~= nil then
    self.flush_scheduler:cancel()
  end

  local conn = self:_get_conn()

  local ok, err = pcall(function()
    conn:transaction(function()
      local check_exists_stmt = conn:prepare("SELECT 1 FROM notes WHERE uuid = ?")
      local insert_note_stmt = conn:prepare("INSERT INTO notes (uuid, name, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)")
      local update_note_stmt = conn:prepare("UPDATE notes SET name = ?, content = ?, updated_at = ? WHERE uuid = ?")

      for uuid, item in pairs(self._state.items) do
        if item.content ~= nil and item.content ~= item.original then
          local exists_row = check_exists_stmt:bind(uuid):execute_one()

          local content_to_save = item.content
          if content_to_save == nil then
            content_to_save = ""
          end

          if exists_row == nil then
            insert_note_stmt:bind(item.uuid, item.name, content_to_save, item.created_at, item.updated_at):execute()
          else
            update_note_stmt:bind(item.name, content_to_save, item.updated_at, uuid):execute()
          end

          item.original = item.content
        end
      end

      if self._dirty_orders then
        conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)")
          :bind("note_orders", vim.json.encode(self._state.orders))
          :execute()
      end

      if self._dirty_active and self._state.active_uuid ~= nil then
        conn:prepare("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)")
          :bind("activated_item_uuid", self._state.active_uuid)
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

  self._dirty_orders = false
  self._dirty_active = false

  return true
end

---Export to standard JSON format
---@return std.t.INotepadSourceData
function M:dump_to_json()
  local state = self:load(false)
  local items = {}

  for _, uuid in ipairs(state.orders) do
    local item = state.items[uuid]
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
    orders = vim.deepcopy(state.orders),
    activated_item_uuid = state.active_uuid,
  }
end

---Import from standard JSON format
---@param json_data                     std.t.INotepadSourceData
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
            local name = std.notepad.normalize_name(entry.name, self.default_item_name)
            local content = type(entry.content) == "string" and entry.content or ""
            local created_at = type(entry.created_at) == "string" and entry.created_at or std.notepad.now_iso_utc()
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

  self._state = nil
  self:load(true)

  return true
end

return M
