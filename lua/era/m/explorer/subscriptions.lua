---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.subscriptions" ---@type string

local async = require("stl.async")
local Future = require("stl.c.future")
local Subscriber = require("stl.c.subscriber")
local Git = require("era.m.git.state")
local Ignore = require("era.m.git.ignore")

---@class era.m.explorer.Subscriptions
---@field _data                         ux.filetree.Data
---@field _sessions                     table<era.m.explorer.Session, boolean>
---@field _group                        integer
---@field _subscriptions                stl.c.IUnsubscribable[]
---@field _buffers                      table<integer, boolean>
---@field _namespaces                   table<integer, table<integer, boolean>>
---@field _git_revision                 integer
---@field _source_revision              string
---@field _git                          boolean
---@field _running                      boolean
---@field _disposed                     boolean
local controllers = setmetatable({}, { __mode = "kv" })
local revisions = setmetatable({}, { __mode = "k" })
local namespaces_by_data = setmetatable({}, { __mode = "k" })
local M = {}
M.__index = M

---@param session                       era.m.explorer.Session
---@return era.m.explorer.Subscriptions
function M.new(session)
  session.watch = session.data:watch_status()
  local current = controllers[session.data]
  if current and not current._disposed then
    current._sessions[session] = true
    return current
  end
  local self = setmetatable({
    _data = session.data,
    _await = session.await,
    _report = session.report,
    _sessions = setmetatable({ [session] = true }, { __mode = "k" }),
    _buffers = {},
    _namespaces = namespaces_by_data[session.data] or {},
    _git_revision = 0,
    _source_revision = session.data:source():revision(),
    _git = true,
    _running = false,
    _disposed = false,
    _subscriptions = {},
    _group = vim.api.nvim_create_augroup(
      "ExplorerInputs" .. session.state:snapshot():header().data_id,
      { clear = true }
    ),
  }, M)
  namespaces_by_data[session.data] = self._namespaces
  controllers[session.data] = self
  local owner = session.data._tree
  self._poll_before, self._effect_before = owner._poll, owner._on_effect
  self._poll = function(data)
    local busy = self._poll_before(data)
    local revision = self._data:source():revision()
    if revision ~= self._source_revision then
      self._source_revision = revision
      Git.refresh(false)
    end
    local status = self._data._native:watch_status(self._watch_revision)
    if status then
      self._watch_revision = status.revision
      for member in pairs(self._sessions) do
        member.watch = status
        member:notify()
      end
    end
    return busy
  end
  self._effect = function(effect)
    if self._effect_before then
      self._effect_before(effect)
    end
    if effect.kind == "RootUnavailable" then
      for member in pairs(self._sessions) do
        if member.state:snapshot():header().state_id == effect.state then
          member._root_error = true
          member:notify()
        end
      end
    elseif effect.kind == "TaskFailed" then
      self._report(effect.error)
    end
  end
  owner._poll, owner._on_effect = self._poll, self._effect
  for _, event in ipairs({ Git.o_refreshed, Git.o_ignored_refreshed, Ignore.o_invalidated }) do
    self._subscriptions[#self._subscriptions + 1] = event:subscribe(
      Subscriber.new({
        on_next = function()
          self._git = true
          self:_drain()
        end,
      }),
      true
    )
  end
  vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufFilePost", "BufWipeout" }, {
    group = self._group,
    callback = function(event)
      self._buffers[event.buf] = true
      vim.schedule(function()
        self:_drain()
      end)
    end,
  })
  self:refresh()
  return self
end

---@return nil
function M:_drain()
  if self._running or self._disposed then
    return
  end
  self._running = true
  local data = self._data
  local retry = false
  ---@param future                      stl.c.Future
  ---@return boolean
  local function accept(future)
    local value = future:await()
    if type(value) == "table" and value.kind == "Rejected" then
      if value.error.code == "Busy" then
        retry = true
        return false
      end
      error(value.error, 0)
    end
    return true
  end
  async
    .run_future(function()
      while not self._disposed and (self._git or next(self._buffers)) do
        if self._git then
          self._git = false
          if dot.path.is_git_repo() then
            for session in pairs(self._sessions) do
              for view in pairs(session.views) do
                local frame = view:frame()
                if
                  frame
                  and view:_valid()
                  and vim.api.nvim_win_get_tabpage(view.winnr) == vim.api.nvim_get_current_tabpage()
                then
                  local first = vim.api.nvim_win_call(view.winnr, vim.fn.winsaveview).topline
                  local last = math.min(first + vim.api.nvim_win_get_height(view.winnr) - 1, frame:header().row_count)
                  self:visible(frame, first, last):await()
                end
              end
            end
          end
          if self._disposed then
            return
          end
          -- Preloading may invalidate this input again or complete another ignore query.
          if not self._git then
            revisions[data] = (revisions[data] or 0) + 1
            self._git_revision = revisions[data]
            local root = dot.path.workspace()
            local result
            if dot.path.is_git_repo() then
              result = data:set_git(root, self._git_revision, Git.snapshot(), Ignore.snapshot())
            else
              result = data:set_git(root, self._git_revision)
            end
            if not accept(result) then
              self._git = true
              break
            end
          end
        end
        local bufnr = next(self._buffers)
        if bufnr then
          self._buffers[bufnr] = nil
          local namespaces = self._namespaces[bufnr] or {}
          for namespace in pairs(vim.diagnostic.get_namespaces()) do
            if vim.api.nvim_buf_is_valid(bufnr) and #vim.diagnostic.get(bufnr, { namespace = namespace }) > 0 then
              namespaces[namespace] = true
            end
          end
          for namespace in pairs(namespaces) do
            if self._disposed then
              return
            end
            if not accept(data:sync_diagnostics(namespace, bufnr)) then
              self._buffers[bufnr] = true
              break
            end
          end
          self._namespaces[bufnr] = vim.api.nvim_buf_is_valid(bufnr) and namespaces or nil
          if retry then
            break
          end
        end
      end
    end)
    :finally(function(ok, error)
      self._running = false
      if not ok and not self._disposed then
        self._report(error)
      elseif retry and not self._disposed then
        vim.defer_fn(function()
          self:_drain()
        end, 40)
      end
    end)
end

---@return nil
function M:refresh()
  if self._disposed then
    return
  end
  self._git = true
  for bufnr in pairs(self._namespaces) do
    self._buffers[bufnr] = true
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if #vim.diagnostic.get(bufnr) > 0 then
      self._buffers[bufnr] = true
    end
  end
  self:_drain()
  Git.refresh(false)
end

---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@return stl.c.Future
function M:visible(frame, first, last)
  local paths = {}
  local workspace = dot.path.workspace()
  if stl.env.IS_WIN then
    workspace = workspace:gsub("\\", "/")
  end
  workspace = workspace:gsub("/+$", "")
  local prefix = workspace .. "/"
  for row = first, last do
    local node = frame:node_at(row)
    if node then
      local ok, path = pcall(function()
        return self._data:inspect(frame:source(), node):path()
      end)
      if ok then
        -- Native Resource paths are absolute byte strings on Unix, not necessarily UTF-8.
        local normalized = stl.env.IS_WIN and path:gsub("\\", "/") or path
        if normalized == workspace or normalized:sub(1, #prefix) == prefix then
          paths[#paths + 1] = path
        end
      else
        self._report(path)
      end
    end
  end
  if #paths > 0 then
    return Ignore.preload(paths)
  end
  return Future.resolve(nil)
end

---@param session                       era.m.explorer.Session
---@return nil
function M:dispose(session)
  self._sessions[session] = nil
  if next(self._sessions) then
    return
  end
  self._disposed = true
  local owner = self._data._tree
  if owner._poll == self._poll then
    owner._poll = self._poll_before
  end
  if owner._on_effect == self._effect then
    owner._on_effect = self._effect_before
  end
  controllers[self._data] = nil
  vim.api.nvim_del_augroup_by_id(self._group)
  for _, subscription in ipairs(self._subscriptions) do
    subscription:unsubscribe()
  end
  self._subscriptions, self._buffers = {}, {}
end

return M
