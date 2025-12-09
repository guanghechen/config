---@class eve.state.notepad.ISourceConfig : std.t.INotepadSourceConfig
---@field public title                  string Human-readable source title
---@field public engine                 'json'|'folder' Source engine type

---@type eve.state.notepad.ISourceConfig[]
local source_configs = {
  {
    name = "workspace:notes",
    title = "Notes (workspace)",
    engine = "json",
    filepath = std.path.locate_workspace_filepath("notepad/notes.json"),
    default_item_name = function()
      return "Note"
    end,
  },
  {
    name = "shared:notes",
    title = "Notes (shared)",
    engine = "json",
    filepath = std.path.locate_shared_filepath("notepad/notes.json"),
    default_item_name = function()
      return "Note"
    end,
  },
  {
    name = "shared:todos",
    title = "Todos (shared)",
    engine = "folder",
    filepath = std.path.locate_shared_filepath("notepad/todos"),
    default_item_name = function()
      return tostring(os.date("%Y-%m-%d"))
    end,
  },
}

---@type table<string, eve.state.notepad.ISourceConfig>
local source_config_map = {}
for _, config in ipairs(source_configs) do
  source_config_map[config.name] = config
end

---@type table<string, std.t.INotepadSource>
local _source_cache = {}

---Observable for the currently activated note UUID
---@type std.collection.IObservable
local o_activated_uuid = std.Observable.from_value("")

---@class eve.state.notepad
---@field public source_configs         eve.state.notepad.ISourceConfig[]
---@field public source_config_map      table<string, eve.state.notepad.ISourceConfig>
---@field public o_activated_uuid       std.collection.IObservable Observable for activated note UUID
local M = {
  source_configs = source_configs,
  source_config_map = source_config_map,
  o_activated_uuid = o_activated_uuid,
}

---@param name                          string
---@return std.t.INotepadSource
---@return eve.state.notepad.ISourceConfig
function M.retrieve_source(name)
  local config = M.source_config_map[name]

  if config ~= nil then
    if _source_cache[name] ~= nil then
      return _source_cache[name], config
    end

    local source
    if config.engine == "folder" then
      source = std.source.NotepadFolderSource.new(config)
    else
      source = std.source.NotepadJsonSource.new(config)
    end
    _source_cache[name] = source
    return source, config
  end

  local default_config = source_configs[1]
  local default_name = default_config.name
  if _source_cache[default_name] == nil then
    _source_cache[default_name] = std.source.NotepadJsonSource.new(default_config)
  end
  return _source_cache[default_name], default_config
end

---Migrate source engine and update config
---@param name                          string Source name
---@param target_engine                 'json'|'folder' Target engine
---@return boolean success
function M.migrate_source_engine(name, target_engine)
  local config = M.source_config_map[name]
  if config == nil then
    ark.reporter.error({
      from = "eve.state.notepad",
      subject = "Migration Failed",
      message = string.format("Source '%s' not found", name),
    })
    return false
  end

  if config.engine == target_engine then
    ark.reporter.warn({
      from = "eve.state.notepad",
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
    new_source = std.source.NotepadFolderSource.new(new_config)
  else
    new_source = std.source.NotepadJsonSource.new(new_config)
  end

  if not new_source:load_from_json(json_data) then
    ark.reporter.error({
      from = "eve.state.notepad",
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
    from = "eve.state.notepad",
    subject = "Migration Complete",
    message = string.format("Migrated '%s' from %s to %s", config.title, source_engine, target_engine),
  })

  return true
end

---Toggle source engine between json and folder
---@param name                          string Source name
---@return boolean success
function M.toggle_source_engine(name)
  local config = M.source_config_map[name]
  if config == nil then
    ark.reporter.error({
      from = "eve.state.notepad",
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

---Focus a note by UUID in the current source
---@param uuid                          string|nil Note UUID to focus
---@return boolean success
function M.focus_note(uuid)
  local source_name = eve.context.option.notepad_source:snapshot() ---@type string
  local source = M.retrieve_source(source_name)

  -- Update the source's activated UUID
  if not source:set_activated_uuid(uuid) then
    return false
  end

  -- Notify observers to trigger UI updates
  o_activated_uuid:next(uuid or "")

  return true
end

return M
