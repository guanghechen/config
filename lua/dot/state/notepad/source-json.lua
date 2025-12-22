---@diagnostic disable: invisible
local __module_name__ = "dot.state.notepad.source-json" ---@type string

---@class dot.state.notepad.source.JsonState : dot.t.INotepadSourceState
---JSON-specific state (inherits all fields from INotepadSourceState)

---@class dot.state.notepad.source.Json : dot.t.INotepadSource
---@field protected default_item_name   fun(): string
---@field protected _flush_debounced    ark.timer.IDisposableCallable|nil Debounced flush
---@field protected _state              dot.state.notepad.source.JsonState|nil Internal state cache
local M = {}
M.__index = M

local FLUSH_DEBOUNCE_MS = 3000 ---@type integer milliseconds

---@param items_map                     table<string, dot.t.INotepadItemState>
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

---@param config                        dot.t.INotepadSourceConfig
---@return dot.state.notepad.source.Json
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self.filepath = config.filepath
  self.default_item_name = config.default_item_name
  self._state = nil

  self._flush_debounced = ark.timer.debounce(function()
    self:flush()
  end, FLUSH_DEBOUNCE_MS)

  return self
end

---Mark orders as dirty (called when orders are modified externally)
---For JSON source, this triggers a flush since entire file is rewritten anyway
---@return nil
function M:mark_orders_dirty()
  self:__schedule_flush__()
end

---Mark active uuid as dirty (called when active item changes)
---For JSON source, this triggers a flush since entire file is rewritten anyway
---@return nil
function M:mark_active_dirty()
  self:__schedule_flush__()
end

---@param force                         boolean
---@return dot.state.notepad.source.JsonState
function M:load(force)
  if self._state ~= nil and not force then
    return self._state
  end

  local items_map = {} ---@type table<string, dot.t.INotepadItemState>
  local name_to_uuid = {} ---@type table<string, string>
  local orders = {} ---@type string[]
  local active_uuid = nil ---@type string|nil

  local ok, result = pcall(function()
    local raw_data = ark.fs.read_json({
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
              local created_at = type(entry.created_at) == "string" and entry.created_at or dot.state.notepad.now_iso_utc()
              local updated_at = type(entry.updated_at) == "string" and entry.updated_at or created_at
              local original_name = type(entry.name) == "string" and entry.name or nil
              local name = dot.state.notepad.normalize_name(original_name, self.default_item_name)

              items_map[uuid] = {
                uuid = uuid,
                name = name,
                content = nil,
                original = type(entry.content) == "string" and entry.content or "",
                created_at = created_at,
                updated_at = updated_at,
              }
              name_to_uuid[name] = uuid
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
      local uuid = yoz.fn.uuid()
      local now = dot.state.notepad.now_iso_utc()
      local name = dot.state.notepad.normalize_name(nil, self.default_item_name)
      local item = {
        uuid = uuid,
        name = name,
        content = "",
        original = "",
        created_at = now,
        updated_at = now,
      }
      items_map[uuid] = item
      name_to_uuid[name] = uuid
      orders[1] = uuid
      active_uuid = uuid
    elseif active_uuid == nil then
      active_uuid = orders[1]
    end

    return true
  end)

  -- Error handling for corrupted JSON
  if not ok then
    ark.reporter.error({
      from = __module_name__,
      subject = "Load Failed",
      message = "Failed to load notes from JSON file",
      details = { filepath = self.filepath, error = result },
    })

    -- Return empty state on error
    items_map = {}
    name_to_uuid = {}
    orders = {}

    -- Create default note even on error
    local uuid = yoz.fn.uuid()
    local now = dot.state.notepad.now_iso_utc()
    local name = dot.state.notepad.normalize_name(nil, self.default_item_name)
    local item = {
      uuid = uuid,
      name = name,
      content = "",
      original = "",
      created_at = now,
      updated_at = now,
    }
    items_map[uuid] = item
    name_to_uuid[name] = uuid
    orders[1] = uuid
    active_uuid = uuid
  end

  local history, history_index = dot.state.notepad.initialize_history(active_uuid)

  self._state = {
    items = items_map,
    orders = orders,
    active_uuid = active_uuid,
    name_to_uuid = name_to_uuid,
    note_uuid_history = history,
    history_index = history_index,
  }

  return self._state
end

---@return dot.t.INotepadItemMeta[]
function M:list()
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState
  local result = {} ---@type dot.t.INotepadItemMeta[]

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
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState
  return state.active_uuid
end

---@param uuid                          string|nil
---@return boolean
function M:set_activated_uuid(uuid)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

  if uuid == nil then
    state.active_uuid = nil
    self:__schedule_flush__()
    return true
  end

  if state.items[uuid] == nil then
    return false
  end

  if state.active_uuid == uuid then
    return true
  end

  state.active_uuid = uuid
  self:__schedule_flush__()
  return true
end

---@param uuid                          string
---@param createIfNonexistent           boolean|nil
---@return dot.t.INotepadItemState|nil
function M:retrieve(uuid, createIfNonexistent)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState
  local item = state.items[uuid]

  if item == nil and createIfNonexistent then
    return self:create(nil, nil)
  end

  if item ~= nil then
    self:__load_note_content__(item)
  end

  return item
end

---@param name                          string
---@param createIfNonexistent           boolean|nil
---@return dot.t.INotepadItemState|nil
function M:retrieve_by_name(name, createIfNonexistent)
  if type(name) ~= "string" or #name == 0 then
    return nil
  end

  local normalized_name = dot.state.notepad.normalize_name(name, self.default_item_name)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

  local uuid = state.name_to_uuid[normalized_name]
  if uuid ~= nil then
    local item = state.items[uuid]
    if item ~= nil then
      self:__load_note_content__(item)
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
---@return dot.t.INotepadItemState
function M:create(name, content)
  local normalized_name = dot.state.notepad.normalize_name(name, self.default_item_name)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

  -- Check if note with this name already exists using index
  local existing_uuid = state.name_to_uuid[normalized_name]
  if existing_uuid ~= nil then
    local existing_item = state.items[existing_uuid]
    self:__load_note_content__(existing_item)
    return existing_item
  end

  local uuid = yoz.fn.uuid()
  local now = dot.state.notepad.now_iso_utc()
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
  self:__schedule_flush__()
  return item
end

---@param uuid                          string
---@param patch                         dot.t.INotepadItemPatch
---@return boolean
function M:update(uuid, patch)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:__load_note_content__(item)

  local modified = false

  local normalized_name = dot.state.notepad.normalize_name(patch.name, self.default_item_name)
  if normalized_name ~= item.name then
    -- Check if new name conflicts with another note using index
    local has_conflict = dot.state.notepad.check_name_conflict(state.name_to_uuid, normalized_name, uuid)
    if has_conflict then
      ark.reporter.warn({
        from = __module_name__,
        subject = "Update Rejected",
        message = string.format("Note with name '%s' already exists", normalized_name),
      })
      return false
    end

    -- Update name index
    dot.state.notepad.update_name_index(state.name_to_uuid, item.name, normalized_name, uuid)
    item.name = normalized_name
    modified = true
  end

  if patch.content ~= item.content then
    item.content = patch.content
    modified = true
  end

  if modified then
    item.updated_at = dot.state.notepad.now_iso_utc()
    self:__schedule_flush__()
  end
  return modified
end

---@param uuid                          string
---@param new_name                      string
---@return boolean
function M:rename(uuid, new_name)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:__load_note_content__(item)

  local normalized_name = dot.state.notepad.normalize_name(new_name, self.default_item_name)

  if normalized_name == item.name then
    return false
  end

  -- Check if new name conflicts with another note using index
  local has_conflict = dot.state.notepad.check_name_conflict(state.name_to_uuid, normalized_name, uuid)
  if has_conflict then
    ark.reporter.warn({
      from = __module_name__,
      subject = "Rename Rejected",
      message = string.format("Note with name '%s' already exists", normalized_name),
    })
    return false
  end

  -- Update name index
  dot.state.notepad.update_name_index(state.name_to_uuid, item.name, normalized_name, uuid)
  item.name = normalized_name
  item.updated_at = dot.state.notepad.now_iso_utc()
  self:__schedule_flush__()

  return true
end

---@param uuid                          string|nil
---@param text                          string
---@return boolean
function M:append_content(uuid, text)
  if type(text) ~= "string" or #text == 0 then
    return false
  end

  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

  uuid = uuid or state.active_uuid
  if uuid == nil then
    return false
  end

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:__load_note_content__(item)

  local existing = type(item.content) == "string" and item.content or ""
  local new_content = existing .. text

  if new_content == item.content then
    return false
  end

  item.content = new_content
  item.updated_at = dot.state.notepad.now_iso_utc()
  self:__schedule_flush__()
  return true
end

---@param uuid                          string
---@return boolean
function M:remove(uuid)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

  -- Reject if last note
  if #state.orders <= 1 then
    ark.reporter.warn({
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
  dot.state.notepad.remove_from_name_index(state.name_to_uuid, item.name)
  state.items[uuid] = nil
  ark.table.filter_inline(state.orders, function(element)
    return element ~= uuid
  end)

  self:__schedule_flush__()
  return true
end

---@param uuid                          string
---@return nil
function M:push_history(uuid)
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

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
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState
  return state.history_index > 1
end

---@return boolean
function M:can_go_forward()
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState
  return state.history_index > 0 and state.history_index < #state.note_uuid_history
end

---@return string|nil
function M:go_backward()
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

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
  local state = self:load(false) ---@type dot.state.notepad.source.JsonState

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

  if self._flush_debounced ~= nil then
    self._flush_debounced:cancel()
  end

  if self.filepath == nil or #self.filepath == 0 then
    return false
  end

  -- Error handling for file write failures
  local ok, err = pcall(function()
    local dirpath = dot.path.dirname(self.filepath)
    ark.env.mkdirs(dirpath, true)

    cleanup_orders(self._state.items, self._state.orders)

    -- Build items array
    local items = {}
    local existing = {}
    for _, uuid in ipairs(self._state.orders) do
      local item = self._state.items[uuid]
      if item ~= nil then
        local content_to_save = item.content or item.original or ""
        items[#items + 1] = {
          uuid = item.uuid,
          name = item.name,
          content = content_to_save,
          created_at = item.created_at,
          updated_at = item.updated_at,
        }
        existing[uuid] = true
        -- Update original after successful save preparation
        if item.content ~= nil then
          item.original = item.content
        end
      end
    end

    -- Add any items not in orders
    for uuid, item in pairs(self._state.items) do
      if not existing[uuid] then
        local content_to_save = item.content or item.original or ""
        items[#items + 1] = {
          uuid = item.uuid,
          name = item.name,
          content = content_to_save,
          created_at = item.created_at,
          updated_at = item.updated_at,
        }
        -- Update original after successful save preparation
        if item.content ~= nil then
          item.original = item.content
        end
      end
    end

    local save_data = {
      items = items,
      orders = self._state.orders,
      activated_item_uuid = self._state.active_uuid or vim.NIL,
    }

    ark.fs.write_json(self.filepath, save_data, true)
  end)

  if not ok then
    ark.reporter.error({
      from = __module_name__,
      subject = "Flush Failed",
      message = "Failed to write notes to JSON file",
      details = { filepath = self.filepath, error = err },
    })
    return false
  end

  return true
end

---Export to standard JSON format (identity for JSON source)
---@return dot.t.INotepadSourceData
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

---Import from standard JSON format (identity for JSON source)
---@param json_data                     dot.t.INotepadSourceData
---@return boolean
function M:load_from_json(json_data)
  if type(json_data) ~= "table" then
    return false
  end

  local items_map = {}
  local orders = {}

  if type(json_data.items) == "table" then
    for _, entry in ipairs(json_data.items) do
      if type(entry) == "table" and type(entry.uuid) == "string" and #entry.uuid > 0 then
        local uuid = entry.uuid
        local created_at = type(entry.created_at) == "string" and entry.created_at or dot.state.notepad.now_iso_utc()
        local updated_at = type(entry.updated_at) == "string" and entry.updated_at or created_at
        local name = dot.state.notepad.normalize_name(entry.name, self.default_item_name)

        items_map[uuid] = {
          uuid = uuid,
          name = name,
          content = nil,
          original = type(entry.content) == "string" and entry.content or "",
          created_at = created_at,
          updated_at = updated_at,
        }
      end
    end
  end

  if type(json_data.orders) == "table" then
    for _, uuid in ipairs(json_data.orders) do
      if type(uuid) == "string" and #uuid > 0 and items_map[uuid] ~= nil then
        orders[#orders + 1] = uuid
      end
    end
  end

  cleanup_orders(items_map, orders)

  local active_uuid = json_data.activated_item_uuid
  if type(active_uuid) ~= "string" or items_map[active_uuid] == nil then
    active_uuid = orders[1]
  end

  local name_to_uuid = dot.state.notepad.build_name_index(items_map)
  local history, history_index = dot.state.notepad.initialize_history(active_uuid)

  self._state = {
    items = items_map,
    orders = orders,
    active_uuid = active_uuid,
    name_to_uuid = name_to_uuid,
    note_uuid_history = history,
    history_index = history_index,
  }

  self:flush()
  return true
end

----------------------------------------------------------------------------------------------------

---@protected
---@param item                          dot.t.INotepadItemState
---@return nil
function M:__load_note_content__(item)
  if item.content ~= nil then
    return
  end

  if type(item.original) == "string" then
    item.content = item.original
  else
    item.content = ""
    item.original = ""
  end
end

---@protected
---@return nil
function M:__schedule_flush__()
  if self._flush_debounced ~= nil then
    self._flush_debounced()
  end
end

return M
