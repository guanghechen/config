---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.commits.cache" ---@type string

local LIMIT = 20000
---@class era.m.diffview.view.commits.Cache
local M = {}
M.__index = M

---@param state                         era.m.diffview.view.commits.State
---@return era.m.diffview.view.commits.Cache
function M.new(state)
  return setmetatable({ _state = state, _recent = {}, _closed = {}, _clock = 0, _pending = 0, _disposed = false }, M)
end

---@param commits                       era.m.diffview.ICommit[]
---@return nil
function M:reset(commits)
  local present = {}
  for _, commit in ipairs(commits) do
    present[commit.hash] = true
  end
  for _, values in ipairs({ self._recent, self._closed }) do
    for hash in pairs(values) do
      if not present[hash] then
        values[hash] = nil
      end
    end
  end
end

---@param owner                         era.view.ResultTree
---@param render                        fun(omitted: table<string, true>): stl.c.Future|nil
---@return nil
function M:bind(owner, render)
  self._owner, self._render = owner, render
end

---@param hash                          ?string
---@return nil
function M:touch(hash)
  if hash then
    self._clock = self._clock + 1
    self._recent[hash] = self._clock
  end
  self:schedule()
end

---@param frame                         yoz.ux.treeview.Frame
---@return nil
function M:observe(frame)
  local header = frame:header()
  if self._data ~= header.data_revision or self._layout ~= header.layout_revision then
    self._data, self._layout = header.data_revision, header.layout_revision
    self:schedule()
  end
end

---@return nil
function M:schedule()
  if self._disposed or not self._owner or self._scheduled or self._trimming or self._pending > 0 then
    return
  end
  self._scheduled = true
  vim.schedule(function()
    if self._disposed then
      return
    end
    self._owner:ready():finally(function(ok, reply)
      self._scheduled = false
      if not self._disposed and ok and reply.kind == "Applied" and not self._trimming and self._pending == 0 then
        self:_trim()
      end
    end)
  end)
end

---@param requested                     ?string
---@return nil
function M:_trim(requested)
  local owner, state = self._owner, self._state
  local frame = owner:frame()
  local source = frame:source()
  local current = state:get_current_commit()
  local candidates, count = {}, 0
  for _, commit in ipairs(state:get_commits()) do
    local key = "commit:" .. commit.hash
    local record = owner:data(key)
    if record and record.files_loaded and commit.hash ~= requested and (not current or current.hash ~= commit.hash) then
      local id = source:id(key)
      if id and not frame:flags(id).expanded then
        local nodes = record.file_nodes or 0
        count = count + nodes
        candidates[#candidates + 1] = { hash = commit.hash, key = key, nodes = nodes }
      end
    end
  end
  if count <= LIMIT then
    return
  end
  table.sort(candidates, function(left, right)
    local a, b = self._recent[left.hash] or 0, self._recent[right.hash] or 0
    return a < b or a == b and left.hash < right.hash
  end)
  local omitted, checkpoints = {}, {}
  for _, candidate in ipairs(candidates) do
    if count <= LIMIT then
      break
    end
    omitted[candidate.hash] = true
    count = count - candidate.nodes
    local closed = {}
    owner.source:walk(candidate.key, function(key, data)
      if data.item and data.item.type == "directory" then
        local id = source:id(key)
        if id and not frame:flags(id).expanded then
          closed[key] = id
        end
      end
    end)
    checkpoints[candidate.hash] = closed
  end
  local previous_source, previous_entries = owner.source, owner.entries
  local ok, future = pcall(self._render, omitted)
  local requested_source = owner.source
  if not ok then
    owner.source, owner.entries = previous_source, previous_entries
    owner:invalidate()
    stl.reporter.error({ from = __module_name__, subject = "cache", message = tostring(future) })
    return
  end
  if not future then
    return
  end
  self._trimming = future
  future:finally(function(applied, reply)
    if self._disposed then
      return
    end
    self._trimming = nil
    local current_source = owner._data:source()
    local present = {}
    for _, commit in ipairs(state:get_commits()) do
      present[commit.hash] = true
    end
    for hash, closed in pairs(checkpoints) do
      local lost = {}
      for key, id in pairs(closed) do
        if current_source:id(key) ~= id then
          lost[key] = id
        end
      end
      if present[hash] and next(lost) then
        self._closed[hash] = lost
      end
    end
    if applied and reply.kind == "Applied" then
      self:schedule()
    elseif owner.source == requested_source then
      owner.source, owner.entries = previous_source, previous_entries
      owner:invalidate()
    end
  end)
end

---Pin materialization across source publication and expansion; wait out an already accepted eviction.
---@async
---@param callback                      fun(): nil
---@param requested                     ?string Preserve the incoming commit while reclaiming an over-budget cache first.
---@return nil
function M:run(callback, requested)
  if self._disposed then
    return
  end
  self._pending = self._pending + 1
  local ok, failure = pcall(function()
    if self._trimming then
      -- A failed trim already reports through the result owner and restores its producer.
      pcall(self._trimming.await, self._trimming)
    end
    if not self._disposed and requested and self._owner and self._owner:is_current() then
      local ready = self._owner:ready():await()
      if ready.kind == "Applied" and not self._disposed then
        self:_trim(requested)
        if self._trimming then
          pcall(self._trimming.await, self._trimming)
        end
      end
    end
    if not self._disposed then
      callback()
    end
  end)
  self._pending = self._pending - 1
  self:schedule()
  if not ok and not self._disposed then
    error(failure, 0)
  end
end

---@async
---@param owner                         era.view.ResultTree
---@param hash                          string
---@return nil
function M:restore(owner, hash)
  local closed = self._closed[hash]
  if not closed then
    return
  end
  local source, nodes = owner:frame():source(), {}
  for key, previous in pairs(closed) do
    local id = source:id(key)
    if id and id ~= previous then
      nodes[#nodes + 1] = id
    end
  end
  if #nodes > 0 then
    local reply = owner.state:set_expanded(nodes, false, false):await()
    if reply.kind == "Rejected" then
      error(reply.error.message, 0)
    end
  end
  self._closed[hash] = nil
end

---@return nil
function M:dispose()
  self._disposed = true
  self._owner, self._state, self._render = nil, nil, nil
  self._recent, self._closed, self._trimming = {}, {}, nil
end

return M
