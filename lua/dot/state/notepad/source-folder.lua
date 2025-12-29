---@diagnostic disable: invisible
local __module_name__ = "dot.state.notepad.source-folder" ---@type string

---@class dot.state.notepad.source.FolderState : dot.t.INotepadSourceState
---Folder-specific state (inherits all fields from INotepadSourceState)

---@class dot.state.notepad.source.Folder : dot.t.INotepadSource
---@field protected default_item_name   fun(): string
---@field protected _flush_debounced    stl.timer.IDisposableCallable|nil Debounced flush
---@field protected _state              dot.state.notepad.source.FolderState|nil Internal state cache
---@field protected _dirty_orders       boolean Track if orders changed
---@field protected _dirty_active       boolean Track if active_uuid changed
---@field protected _dirpath            string Directory path for notes
---@field protected _metadata_path      string Path to .__notepad__ metadata file
local M = {}
M.__index = M

local FLUSH_DEBOUNCE_MS = 3000 ---@type integer milliseconds
local METADATA_FILENAME = ".__notepad__"

---Sanitize name to be filesystem-safe
---@param name                          string
---@return string
local function sanitize_filename(name)
  local sanitized = name:gsub('[/\\:*?"<>|]', "_")
  sanitized = sanitized:gsub("^%.+", "_")
  return sanitized
end

---Build filename from note name
---@param name                          string
---@return string
local function name_to_filename(name)
  return sanitize_filename(name) .. ".md"
end

---@param config                        dot.t.INotepadSourceConfig
---@return dot.state.notepad.source.Folder
function M.new(config)
  local self = setmetatable({}, M)
  self.name = config.name
  self._dirpath = config.filepath
  self._metadata_path = dot.path.join(self._dirpath, METADATA_FILENAME)
  self.filepath = self._metadata_path
  self.default_item_name = config.default_item_name
  self._state = nil
  self._dirty_orders = false
  self._dirty_active = false

  self._flush_debounced = stl.timer.debounce(function()
    self:flush()
  end, FLUSH_DEBOUNCE_MS)

  return self
end

---Mark orders as dirty (called when orders are modified externally)
---@return nil
function M:mark_orders_dirty()
  self._dirty_orders = true
  self:__schedule_flush__()
end

---Mark active uuid as dirty (called when active item changes)
---@return nil
function M:mark_active_dirty()
  self._dirty_active = true
  self:__schedule_flush__()
end

---@param force                         boolean
---@return dot.state.notepad.source.FolderState
function M:load(force)
  if self._state ~= nil and not force then
    return self._state
  end

  stl.env.mkdirs(self._dirpath, true)

  local items_map = {} ---@type table<string, dot.t.INotepadItemState>
  local name_to_uuid = {} ---@type table<string, string>
  local orders = {} ---@type string[]
  local active_uuid = nil ---@type string|nil

  local ok, result = pcall(function()
    local raw_data = ark.fs.read_json({
      filepath = self._metadata_path,
      silent_on_bad_path = true,
      silent_on_bad_json = false,
    })

    if type(raw_data) == "table" then
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
                original = nil,
                created_at = created_at,
                updated_at = updated_at,
              }
              name_to_uuid[name] = uuid
            end
          end
        end
      end

      local raw_orders = raw_data.orders
      if type(raw_orders) == "table" then
        for _, uuid in ipairs(raw_orders) do
          if type(uuid) == "string" and #uuid > 0 and items_map[uuid] ~= nil then
            orders[#orders + 1] = uuid
          end
        end
      end

      local activated = raw_data.activated_item_uuid
      if type(activated) == "string" and items_map[activated] ~= nil then
        active_uuid = activated
      end
    end

    return true
  end)

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "Load Failed",
      message = "Failed to load notes metadata",
      details = { filepath = self._metadata_path, error = result },
    })
  end

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
    self:__save_note_content__(item)
  elseif active_uuid == nil then
    active_uuid = orders[1]
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

  self._dirty_orders = false
  self._dirty_active = false

  return self._state
end

---@return dot.t.INotepadItemMeta[]
function M:list()
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState
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
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState
  return state.active_uuid
end

---@param uuid                          string|nil
---@return boolean
function M:set_activated_uuid(uuid)
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

  if uuid == nil then
    state.active_uuid = nil
    self._dirty_active = true
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
  self._dirty_active = true
  self:__schedule_flush__()
  return true
end

---@param uuid                          string
---@param createIfNonexistent           boolean|nil
---@return dot.t.INotepadItemState|nil
function M:retrieve(uuid, createIfNonexistent)
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState
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
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

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
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

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

  self:__save_note_content__(item)
  self._dirty_orders = true
  self:__schedule_flush__()

  return item
end

---@param uuid                          string
---@param patch                         dot.t.INotepadItemPatch
---@return boolean
function M:update(uuid, patch)
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:__load_note_content__(item)

  local modified = false
  local name_changed = false
  local old_name = item.name

  local normalized_name = dot.state.notepad.normalize_name(patch.name, self.default_item_name)
  if normalized_name ~= item.name then
    local has_conflict = dot.state.notepad.check_name_conflict(state.name_to_uuid, normalized_name, uuid)
    if has_conflict then
      stl.reporter.warn({
        from = __module_name__,
        subject = "Update Rejected",
        message = string.format("Note with name '%s' already exists", normalized_name),
      })
      return false
    end

    dot.state.notepad.update_name_index(state.name_to_uuid, item.name, normalized_name, uuid)
    item.name = normalized_name
    name_changed = true
    modified = true
  end

  if patch.content ~= item.content then
    item.content = patch.content
    modified = true
  end

  if modified then
    item.updated_at = dot.state.notepad.now_iso_utc()
    self:__save_note_content__(item)

    if name_changed then
      self:__rename_note_file__(old_name, item.name)
    end

    self:__schedule_flush__()
  end

  return modified
end

---@param uuid                          string
---@param new_name                      string
---@return boolean
function M:rename(uuid, new_name)
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

  local item = state.items[uuid]
  if item == nil then
    return false
  end

  self:__load_note_content__(item)

  local normalized_name = dot.state.notepad.normalize_name(new_name, self.default_item_name)

  if normalized_name == item.name then
    return false
  end

  local has_conflict = dot.state.notepad.check_name_conflict(state.name_to_uuid, normalized_name, uuid)
  if has_conflict then
    stl.reporter.warn({
      from = __module_name__,
      subject = "Rename Rejected",
      message = string.format("Note with name '%s' already exists", normalized_name),
    })
    return false
  end

  local old_name = item.name
  dot.state.notepad.update_name_index(state.name_to_uuid, item.name, normalized_name, uuid)
  item.name = normalized_name
  item.updated_at = dot.state.notepad.now_iso_utc()

  self:__rename_note_file__(old_name, item.name)
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

  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

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
  self:__save_note_content__(item)
  self:__schedule_flush__()

  return true
end

---@param uuid                          string
---@return boolean
function M:remove(uuid)
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

  if #state.orders <= 1 then
    stl.reporter.warn({
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

  self:__delete_note_file__(item.name)
  dot.state.notepad.remove_from_name_index(state.name_to_uuid, item.name)
  state.items[uuid] = nil
  stl.table.filter_inline(state.orders, function(element)
    return element ~= uuid
  end)

  self._dirty_orders = true
  self:__schedule_flush__()

  return true
end

---@param uuid                          string
---@return nil
function M:push_history(uuid)
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

  if state.items[uuid] == nil then
    return
  end

  if state.history_index > 0 and state.history_index < #state.note_uuid_history then
    for i = #state.note_uuid_history, state.history_index + 1, -1 do
      state.note_uuid_history[i] = nil
    end
  end

  if #state.note_uuid_history > 0 and state.note_uuid_history[#state.note_uuid_history] == uuid then
    return
  end

  state.note_uuid_history[#state.note_uuid_history + 1] = uuid
  state.history_index = #state.note_uuid_history
end

---@return boolean
function M:can_go_backward()
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState
  return state.history_index > 1
end

---@return boolean
function M:can_go_forward()
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState
  return state.history_index > 0 and state.history_index < #state.note_uuid_history
end

---@return string|nil
function M:go_backward()
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

  while state.history_index > 1 do
    state.history_index = state.history_index - 1
    local uuid = state.note_uuid_history[state.history_index]

    if uuid ~= nil and state.items[uuid] ~= nil then
      return uuid
    end
  end

  return nil
end

---@return string|nil
function M:go_forward()
  local state = self:load(false) ---@type dot.state.notepad.source.FolderState

  while state.history_index < #state.note_uuid_history do
    state.history_index = state.history_index + 1
    local uuid = state.note_uuid_history[state.history_index]

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

  stl.env.mkdirs(self._dirpath, true)

  local items = {}
  for _, uuid in ipairs(self._state.orders) do
    local item = self._state.items[uuid]
    if item ~= nil then
      items[#items + 1] = {
        uuid = item.uuid,
        name = item.name,
        created_at = item.created_at,
        updated_at = item.updated_at,
      }
    end
  end

  local save_data = {
    items = items,
    orders = self._state.orders,
    activated_item_uuid = self._state.active_uuid or vim.NIL,
  }

  local ok, err = pcall(function()
    ark.fs.write_json(self._metadata_path, save_data, true)
  end)

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "Flush Failed",
      message = "Failed to write notes metadata",
      details = { filepath = self._metadata_path, error = err },
    })
    return false
  end

  self._dirty_orders = false
  self._dirty_active = false

  return true
end

---Export to standard JSON format
---@return dot.t.INotepadSourceData
function M:dump_to_json()
  local state = self:load(false)
  local items = {}

  for _, uuid in ipairs(state.orders) do
    local item = state.items[uuid]
    if item ~= nil then
      self:__load_note_content__(item)
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
        local content = type(entry.content) == "string" and entry.content or ""

        items_map[uuid] = {
          uuid = uuid,
          name = name,
          content = content,
          original = content,
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

  for _, item in pairs(items_map) do
    self:__save_note_content__(item)
  end

  self:flush()
  return true
end

----------------------------------------------------------------------------------------------------

---@protected
---@param name                          string
---@return boolean
function M:__delete_note_file__(name)
  local filepath = self:__get_note_path__(name)
  local ok = pcall(function()
    vim.fn.delete(filepath)
  end)
  return ok
end

---@protected
---@param name                          string
---@return string
function M:__get_note_path__(name)
  return dot.path.join(self._dirpath, name_to_filename(name))
end

---@protected
---@param item                          dot.t.INotepadItemState
---@return nil
function M:__load_note_content__(item)
  if item.original ~= nil then
    return
  end

  local filepath = self:__get_note_path__(item.name)
  local ok, content = pcall(function()
    return vim.fn.readfile(filepath)
  end)

  if ok and type(content) == "table" then
    item.content = table.concat(content, "\n")
    item.original = item.content
  else
    item.content = ""
    item.original = ""
  end
end

---@protected
---@param old_name                      string
---@param new_name                      string
---@return boolean
function M:__rename_note_file__(old_name, new_name)
  local old_path = self:__get_note_path__(old_name)
  local new_path = self:__get_note_path__(new_name)

  local ok = pcall(function()
    vim.fn.rename(old_path, new_path)
  end)

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "Rename Failed",
      message = "Failed to rename note file",
      details = { old_path = old_path, new_path = new_path },
    })
  end

  return ok
end

---@protected
---@param item                          dot.t.INotepadItemState
---@return boolean
function M:__save_note_content__(item)
  if item.content == nil then
    return true
  end

  local filepath = self:__get_note_path__(item.name)
  local ok, err = pcall(function()
    local lines = vim.split(item.content, "\n", { plain = true })
    vim.fn.writefile(lines, filepath)
  end)

  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "Save Failed",
      message = "Failed to save note content",
      details = { filepath = filepath, error = err },
    })
    return false
  end

  item.original = item.content
  return true
end

---@protected
---@return nil
function M:__schedule_flush__()
  if self._flush_debounced ~= nil then
    self._flush_debounced()
  end
end

return M
