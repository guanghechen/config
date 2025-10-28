---@class std.notepad
local M = {}

---Generate ISO 8601 UTC timestamp
---@return string
function M.now_iso_utc()
  return tostring(os.date("!%Y-%m-%dT%H:%M:%SZ"))
end

---Normalize note name with default fallback
---@param name                          string|nil
---@param default_name                  fun(): string
---@return string
function M.normalize_name(name, default_name)
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

---Build name-to-uuid index from items
---@param items                         table<string, std.t.INotepadItem>
---@return table<string, string>
function M.build_name_index(items)
  local name_to_uuid = {} ---@type table<string, string>
  for uuid, item in pairs(items) do
    name_to_uuid[item.name] = uuid
  end
  return name_to_uuid
end

---Check if a name conflicts with another note (excluding current uuid)
---@param name_to_uuid                  table<string, string>
---@param normalized_name               string
---@param current_uuid                  string|nil
---@return boolean has_conflict
---@return string|nil conflicting_uuid
function M.check_name_conflict(name_to_uuid, normalized_name, current_uuid)
  local conflicting_uuid = name_to_uuid[normalized_name]
  if conflicting_uuid ~= nil and conflicting_uuid ~= current_uuid then
    return true, conflicting_uuid
  end
  return false, nil
end

---Update name index when renaming a note
---@param name_to_uuid                  table<string, string>
---@param old_name                      string
---@param new_name                      string
---@param uuid                          string
---@return nil
function M.update_name_index(name_to_uuid, old_name, new_name, uuid)
  name_to_uuid[old_name] = nil
  name_to_uuid[new_name] = uuid
end

---Remove name from index
---@param name_to_uuid                  table<string, string>
---@param name                          string
---@return nil
function M.remove_from_name_index(name_to_uuid, name)
  name_to_uuid[name] = nil
end

---Initialize history stack based on current active UUID
---@param active_uuid                    string|nil
---@return string[]
---@return integer
function M.initialize_history(active_uuid)
  if type(active_uuid) == "string" and #active_uuid > 0 then
    return { active_uuid }, 1
  end
  return {}, 0
end

return M
