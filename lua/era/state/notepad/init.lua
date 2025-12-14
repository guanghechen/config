---@class era.state.notepad.ISourceConfig : era.t.INotepadSourceConfig
---@field public title                  string Human-readable source title
---@field public engine                 'json'|'folder' Source engine type

local NotepadJsonSource = require("era.state.notepad.source-json")
local NotepadFolderSource = require("era.state.notepad.source-folder")

---@type era.state.notepad.ISourceConfig[]
local source_configs = {
  {
    name = "workspace:notes",
    title = "Notes (workspace)",
    engine = "json",
    filepath = dot.path.locate_workspace_filepath("notepad/notes.json"),
    default_item_name = function()
      return "Note"
    end,
  },
  {
    name = "shared:notes",
    title = "Notes (shared)",
    engine = "json",
    filepath = dot.path.locate_shared_filepath("notepad/notes.json"),
    default_item_name = function()
      return "Note"
    end,
  },
  {
    name = "shared:todos",
    title = "Todos (shared)",
    engine = "folder",
    filepath = dot.path.locate_shared_filepath("notepad/todos"),
    default_item_name = function()
      return tostring(os.date("%Y-%m-%d"))
    end,
  },
}

---@type table<string, era.state.notepad.ISourceConfig>
local source_config_map = {}
for _, config in ipairs(source_configs) do
  source_config_map[config.name] = config
end

---@type table<string, era.t.INotepadSource>
local _source_cache = {}

---Observable for the currently activated note UUID
---@type ark.c.Observable
local o_activated_uuid = ark.c.Observable.from_value("")

---@class era.state.notepad
---@field public source_configs         era.state.notepad.ISourceConfig[]
---@field public source_config_map      table<string, era.state.notepad.ISourceConfig>
---@field public o_activated_uuid       ark.c.Observable Observable for activated note UUID
local M = {
  source_configs = source_configs,
  source_config_map = source_config_map,
  o_activated_uuid = o_activated_uuid,
}

---Build name-to-uuid index from items
---@param items                         table<string, era.t.INotepadItemState>
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

---Focus a note by UUID in the current source
---@param uuid                          string|nil Note UUID to focus
---@return boolean success
function M.focus_note(uuid)
  local source_name = era.context.option.notepad_source:snapshot() ---@type string
  local source = M.retrieve_source(source_name)

  if not source:set_activated_uuid(uuid) then
    return false
  end

  o_activated_uuid:next(uuid or "")

  return true
end

---Initialize history stack based on current active UUID
---@param active_uuid                   string|nil
---@return string[]
---@return integer
function M.initialize_history(active_uuid)
  if type(active_uuid) == "string" and #active_uuid > 0 then
    return { active_uuid }, 1
  end
  return {}, 0
end

---Migrate source engine and update config
---@param name                          string Source name
---@param target_engine                 'json'|'folder' Target engine
---@return boolean success
function M.migrate_source_engine(name, target_engine)
  local config = M.source_config_map[name]
  if config == nil then
    ark.reporter.error({
      from = "era.state.notepad",
      subject = "Migration Failed",
      message = string.format("Source '%s' not found", name),
    })
    return false
  end

  if config.engine == target_engine then
    ark.reporter.warn({
      from = "era.state.notepad",
      subject = "Migration Skipped",
      message = string.format("Source '%s' is already using %s engine", name, target_engine),
    })
    return false
  end

  local source_engine = config.engine
  local source = _source_cache[name]

  if source == nil then
    source, _ = M.retrieve_source(name)
  end

  source:flush()
  local json_data = source:dump_to_json()

  local new_filepath
  if target_engine == "folder" then
    new_filepath = config.filepath:gsub("%.json$", "")
  else
    new_filepath = config.filepath:gsub("/$", ".json")
  end

  local new_config = vim.tbl_extend("force", config, {
    engine = target_engine,
    filepath = new_filepath,
  })

  local new_source
  if target_engine == "folder" then
    new_source = NotepadFolderSource.new(new_config)
  else
    new_source = NotepadJsonSource.new(new_config)
  end

  if not new_source:load_from_json(json_data) then
    ark.reporter.error({
      from = "era.state.notepad",
      subject = "Migration Failed",
      message = string.format("Failed to import data to %s engine", target_engine),
    })
    return false
  end

  local old_filepath = config.filepath
  if vim.fn.filereadable(old_filepath) == 1 then
    local backup_filepath = old_filepath .. ".bak"
    vim.fn.rename(old_filepath, backup_filepath)
  end

  config.engine = target_engine
  config.filepath = new_filepath
  _source_cache[name] = new_source

  ark.reporter.info({
    from = "era.state.notepad",
    subject = "Migration Complete",
    message = string.format("Migrated '%s' from %s to %s", config.title, source_engine, target_engine),
  })

  return true
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

---Generate ISO 8601 UTC timestamp
---@return string
function M.now_iso_utc()
  return tostring(os.date("!%Y-%m-%dT%H:%M:%SZ"))
end

---Remove name from index
---@param name_to_uuid                  table<string, string>
---@param name                          string
---@return nil
function M.remove_from_name_index(name_to_uuid, name)
  name_to_uuid[name] = nil
end

---@param name                          string
---@return era.t.INotepadSource
---@return era.state.notepad.ISourceConfig
function M.retrieve_source(name)
  local config = M.source_config_map[name]

  if config ~= nil then
    if _source_cache[name] ~= nil then
      return _source_cache[name], config
    end

    local source
    if config.engine == "folder" then
      source = NotepadFolderSource.new(config)
    else
      source = NotepadJsonSource.new(config)
    end
    _source_cache[name] = source
    return source, config
  end

  local default_config = source_configs[1]
  local default_name = default_config.name
  if _source_cache[default_name] == nil then
    _source_cache[default_name] = NotepadJsonSource.new(default_config)
  end
  return _source_cache[default_name], default_config
end

---Toggle source engine between json and folder
---@param name                          string Source name
---@return boolean success
function M.toggle_source_engine(name)
  local config = M.source_config_map[name]
  if config == nil then
    ark.reporter.error({
      from = "era.state.notepad",
      subject = "Toggle Failed",
      message = string.format("Source '%s' not found", name),
    })
    return false
  end

  local target_engine
  if config.engine == "json" then
    target_engine = "folder"
  else
    target_engine = "json"
  end

  return M.migrate_source_engine(name, target_engine)
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

return M
