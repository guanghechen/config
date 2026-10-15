---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_paths" ---@type string

local Source = require("era.view.result_source")

---@class era.view.result_paths.IFile
---@field public filepath               string
---@field public filepath_lower         string
---@field public basename               string
---@field public filetype               "directory"|"file"

---@class era.view.ResultPaths : era.view.ResultSource
---@field public get                    fun(self: era.view.ResultPaths, key?: string): era.view.result_paths.IFile|nil
---@field public walk                   fun(self: era.view.ResultPaths, root?: string, visit: fun(key: string, data: era.view.result_paths.IFile): nil): nil
---@field _paths                        table<string, string> Canonical path to result key.
---@field _sorted                       table<string, integer> Parent key to the revision its children were sorted at.
---@field _reset                        ?{cwd: string, paths: string[], with_locations: boolean, revision: integer}
local M = setmetatable({}, { __index = Source })
M.__index = M

---@param path                          string
---@return string
function M.key(path)
  if path:find("\\", 1, true) then
    path = yoz.canonical_path.from_os_path(path, false)
  end
  assert(yoz.canonical_path.is_absolute(path), "result path must be absolute")
  -- Frecency storage uses these keys; native identities remain session-local.
  return yoz.fn.md5(path)
end

---@param path                          string
---@param kind                          "directory"|"file"
---@return era.view.result_paths.IFile
local function file_data(path, kind)
  local basename = yoz.canonical_path.basename(path)
  return {
    filepath = path,
    filepath_lower = path:lower(),
    basename = basename,
    filetype = kind,
  }
end

---@return era.view.ResultPaths
function M.new()
  local self = Source.new(M.key("/"), file_data("/", "directory")) --[[@as era.view.ResultPaths]]
  self._paths = { ["/"] = self.root }
  self._sorted = {}
  return setmetatable(self, M)
end

---@return nil
function M:clear()
  Source.clear(self)
  self._reset = nil
  self._paths = { ["/"] = self.root }
  self._sorted = {}
end

---@return nil
function M:dispose()
  Source.dispose(self)
  self._reset = nil
  self._paths = {}
  self._sorted = {}
end

---@param key                           string
---@return nil
function M:remove(key)
  self:walk(key, function(child, data)
    self._paths[data.filepath], self._sorted[child] = nil, nil
  end)
  Source.remove(self, key)
end

---@param key                           string
---@return string[]|nil
function M:children(key)
  local children = Source.children(self, key)
  if children and #children > 1 and self._sorted[key] ~= self.revision then
    local records = self.records
    table.sort(children, function(left, right)
      local a, b = records[left].data, records[right].data
      if a.filetype ~= b.filetype then
        return a.filetype == "directory"
      end
      return a.basename < b.basename
    end)
    self._sorted[key] = self.revision
  end
  return children
end

---@param path                          string
---@param kind                          "directory"|"file"
---@return string
function M:_insert_path(path, kind)
  if path:find("\\", 1, true) then
    path = yoz.canonical_path.from_os_path(path, false)
  end
  assert(yoz.canonical_path.is_absolute(path), "result path must be absolute")
  local existing = self._paths[path]
  if existing and self:contains(existing) then
    return existing
  end
  local pending, current = {}, path
  while not (self._paths[current] and self:contains(self._paths[current])) do
    pending[#pending + 1] = current
    local parent = yoz.canonical_path.dirname(current, false)
    if parent == current or parent == "" then
      current = "/"
      break
    end
    current = parent
  end
  local parent = self._paths[current] or self.root
  for index = #pending, 1, -1 do
    local item = pending[index]
    local key = M.key(item)
    self:insert(parent, key, file_data(item, index == 1 and kind or "directory"))
    self._paths[item] = key
    parent = key
  end
  return parent
end

---@param path                          string
---@return string
function M:insert_file_absolute(path)
  return self:_insert_path(path, "file")
end

---@param path                          string
---@return string
function M:insert_directory_absolute(path)
  return self:_insert_path(path, "directory")
end

---@param cwd                           string
---@param paths                         string[]
---@param with_locations                boolean
---@return boolean
function M:matches(cwd, paths, with_locations)
  local previous = self._reset
  if
    previous
    and previous.revision == self.revision
    and previous.cwd == cwd
    and previous.with_locations == with_locations
    and #previous.paths == #paths
  then
    local same = true
    for index, path in ipairs(paths) do
      if previous.paths[index] ~= path then
        same = false
        break
      end
    end
    if same then
      return true
    end
  end
  return false
end

---@param cwd                           string
---@param paths                         string[]
---@param with_locations                boolean
---@return nil
function M:reset(cwd, paths, with_locations)
  if self:matches(cwd, paths, with_locations) then
    return
  end
  self:clear()
  self:insert_directory_absolute(cwd)
  for _, path in ipairs(paths) do
    if with_locations then
      path = stl.string.parse_filepath_with_location(path)
    end
    if not yoz.canonical_path.is_absolute(path) then
      path = yoz.canonical_path.join(cwd, path, false)
    end
    self:insert_file_absolute(path)
  end
  self._reset = { cwd = cwd, paths = vim.list_slice(paths), with_locations = with_locations, revision = self.revision }
end

---Prepare a private producer. The caller owns yielding, cancellation and atomic adoption.
---@param cwd                           string
---@param paths                         string[] Owned input array; not mutated during preparation.
---@param checkpoint                    fun(): nil
---@return era.view.ResultPaths
function M:prepare(cwd, paths, checkpoint)
  if self:matches(cwd, paths, false) then
    return self
  end
  local prepared = M.new()
  prepared:insert_directory_absolute(cwd)
  for _, path in ipairs(paths) do
    if not yoz.canonical_path.is_absolute(path) then
      path = yoz.canonical_path.join(cwd, path, false)
    end
    prepared:insert_file_absolute(path)
    checkpoint()
  end
  local records = prepared.records
  local order = require("era.view.result_order")
  for key, record in pairs(records) do
    if record.children and #record.children > 1 then
      record.children = order.sort(record.children, function(left, right)
        local a, b = records[left].data, records[right].data
        if a.filetype ~= b.filetype then
          return a.filetype == "directory"
        end
        return a.basename < b.basename
      end, checkpoint)
      prepared._sorted[key] = prepared.revision
    end
    checkpoint()
  end
  prepared._reset = { cwd = cwd, paths = paths, with_locations = false, revision = prepared.revision }
  return prepared
end

---@param prepared                      era.view.ResultPaths
---@return nil
function M:adopt(prepared)
  assert(self.root == prepared.root, "result paths must share the canonical root")
  self.records, self._paths = prepared.records, prepared._paths
  self.revision = self.revision + 1
  self._sorted = {}
  for key in pairs(prepared._sorted) do
    self._sorted[key] = self.revision
  end
  self._reset = {
    cwd = prepared._reset.cwd,
    paths = prepared._reset.paths,
    with_locations = false,
    revision = self.revision,
  }
end

return M
