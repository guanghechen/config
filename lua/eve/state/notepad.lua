---@class eve.state.notepad.ISourceConfig : std.source.INotepadJsonSourceConfig
---@field public title                  string Human-readable source title
---@field public engine                 'json'|'sqlite' Source engine type

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
    name = "workspace:todos",
    title = "Todos (workspace)",
    engine = "json",
    filepath = std.path.locate_workspace_filepath("notepad/todos.json"),
    default_item_name = function()
      return "Note"
    end,
  },
  {
    name = "shared:notes",
    title = "Notes (shared)",
    engine = "sqlite",
    filepath = std.path.locate_shared_filepath("notepad/notes.db"),
    default_item_name = function()
      return "Note"
    end,
  },
  {
    name = "shared:todos",
    title = "Todos (shared)",
    engine = "json",
    filepath = std.path.locate_shared_filepath("notepad/todos.json"),
    default_item_name = function()
      return "todo:" .. os.date("%Y-%m-%d")
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

---@class eve.state.notepad
---@field public source_configs         eve.state.notepad.ISourceConfig[]
---@field public source_config_map      table<string, eve.state.notepad.ISourceConfig>
local M = {
  source_configs = source_configs,
  source_config_map = source_config_map,
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
    if config.engine == "sqlite" then
      source = std.source.NotepadSqliteSource.new(config)
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

return M
