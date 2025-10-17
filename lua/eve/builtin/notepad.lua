local FILE_NAME = "notepad.json" ---@type string
local AUTOSAVE_DELAY = 10000 ---@type integer milliseconds
local DEFAULT_ITEM_NAME = eve.setting.BUF_UNTITLED ---@type string

---@class eve.builtin.notepad.INotepadItem
---@field public uuid                   string
---@field public name                   string
---@field public content                string
---@field public created_at             string
---@field public updated_at             string

local items_map = {} ---@type table<string, eve.builtin.notepad.INotepadItem>
local orders = {} ---@type string[]
local activated_uuid = nil ---@type string|nil
local data_filepath = nil ---@type string|nil
local data_loaded = false ---@type boolean
local data_dirty = false ---@type boolean

---@type std.collection.IObservable
local o_active_uuid = std.Observable.from_value("")

local schedule_save ---@type fun()

---@return string
local function now_iso_utc()
  local text = tostring(os.date("!%Y-%m-%dT%H:%M:%SZ")) ---@type string
  return text
end

---@return nil
local function mark_dirty()
  data_dirty = true
end

---@return nil
local function mark_dirty_and_schedule()
  mark_dirty()
  if schedule_save ~= nil then
    schedule_save()
  end
end

---@return nil
local function notify_active_changed()
  o_active_uuid:next(activated_uuid or "")
end

---@return string
---@param name string|nil
---@return string
local function normalize_name(name)
  if type(name) == "string" then
    name = vim.trim(name)
  else
    name = ""
  end
  if #name == 0 then
    return DEFAULT_ITEM_NAME
  end
  return name
end

---@param item eve.builtin.notepad.INotepadItem
---@return eve.builtin.notepad.INotepadItem
local function clone_item(item)
  return {
    uuid = item.uuid,
    name = item.name,
    content = item.content,
    created_at = item.created_at,
    updated_at = item.updated_at,
  }
end

---@param name string|nil
---@return eve.builtin.notepad.INotepadItem
local function allocate_item(name)
  local uuid = oxi.fn.uuid() ---@type string
  local now = now_iso_utc() ---@type string
  local normalized_name = normalize_name(name)
  local item = {
    uuid = uuid,
    name = normalized_name,
    content = "",
    created_at = now,
    updated_at = now,
  } ---@type eve.builtin.notepad.INotepadItem
  items_map[uuid] = item
  orders[#orders + 1] = uuid
  return item
end

---@return nil
local function cleanup_orders()
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
  orders = filtered
end

---@return nil
local function ensure_default_item()
  if #orders > 0 then
    return
  end
  local item = allocate_item(nil)
  activated_uuid = item.uuid
  notify_active_changed()
  mark_dirty_and_schedule()
end

---@return nil
local function ensure_loaded()
  if data_loaded then
    return
  end

  data_filepath = std.path.locate_workspace_filepath(FILE_NAME) ---@type string
  items_map = {}
  orders = {}
  activated_uuid = nil

  local raw_data = std.fs.read_json({
    filepath = data_filepath,
    silent_on_bad_path = true,
    silent_on_bad_json = false,
  }) ---@type table|nil
  local mutated = false ---@type boolean

  if type(raw_data) == "table" then
    local raw_items = raw_data.items ---@type any
    if type(raw_items) == "table" then
      for _, entry in ipairs(raw_items) do
        if type(entry) == "table" then
          local uuid = type(entry.uuid) == "string" and entry.uuid or nil ---@type string|nil
          if uuid ~= nil and #uuid > 0 then
            local created_at = type(entry.created_at) == "string" and entry.created_at or now_iso_utc()
            local updated_at = type(entry.updated_at) == "string" and entry.updated_at or created_at
            local original_name = type(entry.name) == "string" and entry.name or nil ---@type string|nil
            local name = normalize_name(original_name) ---@type string
            if original_name ~= name then
              mutated = true
            end
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

    local raw_orders = raw_data.orders ---@type any
    if type(raw_orders) == "table" then
      for _, uuid in ipairs(raw_orders) do
        if type(uuid) == "string" and #uuid > 0 then
          orders[#orders + 1] = uuid
        end
      end
    end

    local activated = raw_data.activated_item_uuid
    if type(activated) == "string" and items_map[activated] ~= nil then
      activated_uuid = activated
    end
  end

  cleanup_orders()

  if activated_uuid == nil and #orders > 0 then
    activated_uuid = orders[1]
  end

  data_loaded = true

  if activated_uuid == nil then
    ensure_default_item()
  else
    notify_active_changed()
  end

  if mutated then
    mark_dirty_and_schedule()
    eve.status.dirtier_notepadline:mark_dirty()
  end
end

---@class eve.builtin.notepad
---@field public o_active_uuid          std.collection.IObservable
local M = {
  o_active_uuid = o_active_uuid,
}

---@return string
function M.load()
  ensure_loaded()
  ---@cast data_filepath string
  return data_filepath
end

---@return string
function M.get_filepath()
  ensure_loaded()
  ---@cast data_filepath string
  return data_filepath
end

---@return boolean
function M.save(force)
  ensure_loaded()
  if not data_dirty and not force then
    return true
  end

  if data_filepath == nil or #data_filepath == 0 then
    return false
  end

  local dirpath = std.path.dirname(data_filepath) ---@type string
  vim.fn.mkdir(dirpath, "p")

  cleanup_orders()

  local items = {} ---@type eve.builtin.notepad.INotepadItem[]
  local existing = {} ---@type table<string, boolean>
  for _, uuid in ipairs(orders) do
    local item = items_map[uuid]
    if item ~= nil then
      items[#items + 1] = clone_item(item)
      existing[uuid] = true
    end
  end
  for uuid, item in pairs(items_map) do
    if not existing[uuid] then
      orders[#orders + 1] = uuid
      items[#items + 1] = clone_item(item)
    end
  end

  local data = {
    items = items,
    orders = vim.deepcopy(orders),
    activated_item_uuid = activated_uuid or vim.NIL,
  }

  std.fs.write_json(data_filepath, data, true)
  data_dirty = false
  return true
end

schedule_save = std.timer.debounce(function()
  M.save(false)
end, AUTOSAVE_DELAY)

---@return integer
function M.size()
  ensure_loaded()
  return #orders
end

---@param uuid string|nil
---@return integer
function M.indexof(uuid)
  ensure_loaded()
  if uuid == nil then
    return -1
  end
  for index, target in ipairs(orders) do
    if target == uuid then
      return index
    end
  end
  return -1
end

---@param index integer
---@return string|nil
---@return eve.builtin.notepad.INotepadItem|nil
function M.at(index)
  ensure_loaded()
  local uuid = orders[index]
  if uuid ~= nil then
    return uuid, items_map[uuid]
  end
  return nil, nil
end

---@return integer
---@return string|nil
function M.current()
  ensure_loaded()
  return M.indexof(activated_uuid), activated_uuid
end

---@return eve.builtin.notepad.INotepadItem|nil
function M.current_item()
  ensure_loaded()
  if activated_uuid == nil then
    return nil
  end
  return items_map[activated_uuid]
end

---@param uuid string
---@return eve.builtin.notepad.INotepadItem|nil
function M.get(uuid)
  ensure_loaded()
  return items_map[uuid]
end

---@return fun():eve.builtin.notepad.INotepadItem|nil, integer|nil
function M:iterator()
  ensure_loaded()
  local index = 0 ---@type integer
  return function()
    index = index + 1
    if index > #orders then
      return nil, nil
    end
    local uuid = orders[index] ---@type string
    local item = items_map[uuid]
    if item == nil then
      return nil, nil
    end
    return item, index
  end
end

---@param uuid string|nil
---@return boolean
function M.focus_uuid(uuid)
  ensure_loaded()
  if uuid == nil then
    return false
  end
  if items_map[uuid] == nil then
    return false
  end
  if activated_uuid == uuid then
    return true
  end
  activated_uuid = uuid
  notify_active_changed()
  mark_dirty_and_schedule()
  eve.status.dirtier_notepadline:mark_dirty()
  return true
end

---@param index integer
---@return boolean
function M.focus_index(index)
  ensure_loaded()
  local uuid = orders[index]
  if uuid == nil then
    return false
  end
  return M.focus_uuid(uuid)
end

---@param step integer
---@return boolean
function M.focus_step(step)
  ensure_loaded()
  local count = #orders ---@type integer
  if count == 0 then
    return false
  end
  local index_current = M.indexof(activated_uuid)
  if index_current < 1 then
    index_current = 1
  end
  local index_next = std.fn.navigate_circular(index_current, step, count) ---@type integer
  return M.focus_index(index_next)
end

---@param name string|nil
---@return eve.builtin.notepad.INotepadItem
function M.create(name)
  ensure_loaded()
  local trimmed = type(name) == "string" and vim.trim(name) or ""
  local item = allocate_item(#trimmed > 0 and trimmed or nil)
  mark_dirty()
  eve.status.dirtier_notepadline:mark_dirty()
  M.focus_uuid(item.uuid)
  return item
end

---@param uuid string|nil
---@return boolean
function M.remove(uuid)
  ensure_loaded()
  uuid = uuid or activated_uuid
  if uuid == nil or items_map[uuid] == nil then
    return false
  end

  items_map[uuid] = nil
  for index = #orders, 1, -1 do
    if orders[index] == uuid then
      table.remove(orders, index)
      break
    end
  end

  local active_changed = false ---@type boolean
  if activated_uuid == uuid then
    activated_uuid = orders[1]
    if activated_uuid == nil then
      local item = allocate_item(nil)
      activated_uuid = item.uuid
      active_changed = true
    else
      active_changed = true
    end
  end

  mark_dirty_and_schedule()
  eve.status.dirtier_notepadline:mark_dirty()

  if active_changed then
    notify_active_changed()
  end

  return true
end

---@param uuid string|nil
---@param name string
---@return boolean
function M.rename(uuid, name)
  ensure_loaded()
  uuid = uuid or activated_uuid
  if uuid == nil then
    return false
  end
  local item = items_map[uuid]
  if item == nil then
    return false
  end

  name = vim.trim(name or "")
  if #name == 0 or name == item.name then
    return false
  end

  item.name = name
  item.updated_at = now_iso_utc()

  mark_dirty_and_schedule()
  eve.status.dirtier_notepadline:mark_dirty()
  return true
end

---@param uuid string|nil
---@param content string
---@return boolean
function M.set_content(uuid, content)
  ensure_loaded()
  uuid = uuid or activated_uuid
  if uuid == nil then
    return false
  end
  local item = items_map[uuid]
  if item == nil then
    return false
  end

  content = content or ""
  if item.content == content then
    return false
  end

  item.content = content
  item.updated_at = now_iso_utc()
  mark_dirty_and_schedule()
  return true
end

---@param step integer|nil
---@return boolean
function M.swap_left(step)
  ensure_loaded()
  local count = #orders ---@type integer
  if count <= 1 then
    return false
  end

  local index_current = M.indexof(activated_uuid)
  if index_current < 1 then
    return false
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = std.fn.navigate_circular(index_current, -step, count) ---@type integer
  if index_next == index_current then
    return false
  end

  orders[index_current], orders[index_next] = orders[index_next], orders[index_current]
  mark_dirty_and_schedule()
  eve.status.dirtier_notepadline:mark_dirty()
  return true
end

---@param step integer|nil
---@return boolean
function M.swap_right(step)
  ensure_loaded()
  local count = #orders ---@type integer
  if count <= 1 then
    return false
  end

  local index_current = M.indexof(activated_uuid)
  if index_current < 1 then
    return false
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = std.fn.navigate_circular(index_current, step, count) ---@type integer
  if index_next == index_current then
    return false
  end

  orders[index_current], orders[index_next] = orders[index_next], orders[index_current]
  mark_dirty_and_schedule()
  eve.status.dirtier_notepadline:mark_dirty()
  return true
end

---@return nil
function M.flush()
  M.save(true)
end

return M
