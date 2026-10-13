---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_tree" ---@type string

local treeview = require("ux.treeview")
local Future = require("stl.c.future")
local Snapshot = require("era.view.result_snapshot")
local namespace = vim.api.nvim_create_namespace("era.result_tree")
local RECORD_DEFAULTS = {
  can_expand = false,
  foldable = false,
  hidden = false,
  scores = 0,
  icons = false,
  highlights = false,
  right_texts = false,
  fields = false,
  completeness = "complete",
}

---@alias era.view.result_tree.Viewtype "tree"|"list"

---@class era.view.result_tree.IEntry
---@field public nodetype               "container"|"leaf"|"location"
---@field public collapsed              ?boolean Read from the published native frame.
---@field public leafuuid               ?string
---@field public locationuuid           ?string
---@field public locations              ?era.view.result_tree.IEntry[]
---@field public text                   ?string
---@field public highlights             ?stl.t.IHighlightInline[]
---@field public lnum                   ?integer
---@field public col                    ?integer
---@field public col_end                ?integer
---@field public cache_match            ?{score: number, matches: table[]}

---@class era.view.result_tree.IRead
---@field frame                         yoz.ux.treeview.Frame
---@field header                        ux.treeview.IFrameHeader
---@field source                        yoz.ux.treeview.Source
---@field selected                      table<boolean, yoz.ux.treeview.NodeIds>

---@class era.view.ResultTree
---@field public entries                table<string, era.view.result_tree.IEntry> Producer metadata; never stores selection or expansion.
---@field public source                 era.view.ResultSource|era.view.ResultList
---@field public view                   ?ux.treeview.View
---@field public state                  ?ux.treeview.State
local M = {}
M.__index = M

---@param result                        any
---@return any
local function checked(result)
  if type(result) == "table" and result.kind == "Rejected" then
    error(type(result.error) == "table" and result.error.message or tostring(result.error))
  end
  return result
end

---@param state                         ux.treeview.State
---@param command                       ux.treeview.ICommand
---@return stl.c.Future
local function absolute(state, command)
  ---@param attempts                    integer
  ---@return stl.c.Future
  local function submit(attempts)
    return state:dispatch(command, { expected_state = state:status().revisions.state }):then_(function(reply)
      -- A preceding accepted selection can finish between status() and this command.
      if reply.kind == "Rejected" and reply.error.code == "Stale" and attempts > 0 then
        return submit(attempts - 1)
      end
      return checked(reply)
    end)
  end
  return submit(8)
end

---@param props                         table
---@return era.view.ResultTree
function M.new(props)
  local self = setmetatable({
    fullname = props.name,
    source = props.tree,
    entries = {},
    _data = treeview.new_data(),
    _versions = {},
    _revision = 0,
    _disposed = false,
    _present = props.present,
    _hidden = {},
    _icons = {},
    _directory_icons = {},
    _commands = {},
    _ready = {},
  }, M)
  self._data._after_poll = function(preparing)
    if self.view and self.view:status().closed then
      self.view, self._mount = nil, nil
    end
    local mounted = self.view ~= nil and not self.view:is_suspended()
    if self.state and (self._waiting or #self._ready > 0) then
      local failure = self.state:status().projection_error
      if failure then
        self:_fail(failure.message)
        if next(self._data._views) ~= nil then
          return false
        end
        return nil
      end
    end
    if self._waiting and not mounted and self.state then
      self._frame = self.state:snapshot()
      self:_published(self._frame)
    end
    self:_focus_pending()
    self:_settle_ready()
    if preparing or not mounted and (self._waiting ~= nil or self._focus ~= nil or #self._ready > 0) then
      return true
    end
    if next(self._data._views) ~= nil then
      return false
    end
  end
  return self
end

---@return nil
function M:__health__()
  assert(not self._disposed, self.fullname .. " has been disposed")
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  if self.view then
    self.view:detach()
  end
  if self._upload then
    self._upload:dispose()
  end
  for _, resolve in ipairs(self._ready) do
    resolve({ kind = "Rejected", error = "result tree disposed" })
  end
  self._ready = {}
  for _, pending in pairs({ self._request, self._waiting, self._active_request }) do
    if pending and pending.resolve then
      pending.resolve({ kind = "Rejected", error = "result tree disposed" })
    end
  end
  self._waiting, self._active_request, self._restore_selection = nil, nil, nil
  require("ux.treeview.async").unwatch(self._data)
  self._data._after_poll = nil
  self._focus, self._commands, self._selection_batch = nil, {}, nil
  self.view, self.state, self._data, self._request, self._mount = nil, nil, nil, nil, nil
  self.source:dispose()
  self.source, self._present, self._frame, self._configured = nil, nil, nil, nil
  self._matches, self._last_match_result = nil, nil
  self._icons, self._directory_icons = nil, nil
  self._hidden = {}
  self._read_cache, self._record_cache = nil, nil
  self._versions, self.entries = {}, {}
end

---@return nil
function M:invalidate()
  self._revision = self._revision + 1
  self._last_match_result = nil
end

---@return nil
function M:clear()
  self.entries, self._hidden, self._icons, self._directory_icons = {}, {}, {}, {}
  self:invalidate()
end

---@param key                           string
---@param entry                         era.view.result_tree.IEntry
---@return nil
function M:insert(key, entry)
  self:remove_all_locations(self.entries[key])
  entry.collapsed = nil
  self.entries[key] = entry
  for _, location in ipairs(entry.locations or {}) do
    self.entries[location.locationuuid] = location
  end
  self:invalidate()
end

---@param key                           string
---@return nil
function M:remove(key)
  self.source:walk(key, function(child)
    self:remove_all_locations(self.entries[child])
    self.entries[child] = nil
  end)
  self:invalidate()
end

---@param entry                         ?era.view.result_tree.IEntry
---@return nil
function M:remove_all_locations(entry)
  if not entry then
    return
  end
  local key = entry.locationuuid or entry.key
  if key and self.entries[key] then
    entry = self.entries[key]
  end
  for _, location in ipairs(entry.locations or {}) do
    self.entries[location.locationuuid] = nil
  end
  entry.locations = nil
  self:invalidate()
end

---@param entry                         era.view.result_tree.IEntry
---@param key                           string
---@return nil
function M:remove_location(entry, key)
  local location = self.entries[key]
  local leaf = location and self.entries[location.leafuuid] or entry
  local locations = {}
  for _, item in ipairs(leaf.locations or {}) do
    if item.locationuuid ~= key then
      locations[#locations + 1] = item
    end
  end
  leaf.locations = locations
  self.entries[key] = nil
  self:invalidate()
end

---@return yoz.ux.treeview.Frame|nil
function M:frame()
  if self.view and not self.view:is_suspended() then
    return self.view:frame()
  end
  return self.state and self.state:snapshot() or self._frame
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return era.view.result_tree.IRead|nil
function M:_read(frame)
  frame = frame or self:frame()
  if not frame then
    return nil
  end
  local read = self._read_cache
  if not read or read.frame ~= frame then
    read = { frame = frame, header = frame:header(), source = frame:source(), selected = {} }
    self._read_cache = read
  end
  return read
end

---@param frame                         yoz.ux.treeview.Frame
---@param id                            string
---@return string|nil
function M:_key(frame, id)
  local version = self._versions[self:_read(frame).header.data_revision]
  if version then
    local key = version.keys[id]
    if key then
      return key
    end
    local node = frame:node(id)
    key = node and node.key
    version.keys[id] = key
    return key
  end
end

---@param key                           string
---@return era.view.result_tree.IEntry|nil
function M:retrieve(key)
  local read = self:_read()
  if read then
    local version = self._versions[read.header.data_revision]
    local entry = version and version.entries[key]
    if entry then
      local expandable = entry.nodetype == "container" or entry.locations and #entry.locations > 0
      local id = expandable and read.source:id(key)
      local flags = id and read.frame:flags(id)
      local result = vim.tbl_extend("force", entry, {
        key = key,
        collapsed = expandable and flags and not flags.expanded or false,
      })
      result.cache_match = self._matches and self._matches[key]
      return result
    end
    return nil
  end
  return self.entries[key]
end

---@param key                           ?string
---@return table|string|nil
function M:data(key)
  local read = self:_read()
  local version = read and self._versions[read.header.data_revision]
  if read then
    local entry = version and version.entries[key]
    key = entry and entry.leafuuid or key
    return version and version.data[key]
  end
  return self.source:get(key)
end

---Opaque action payloads retain caller identity while presentation metadata is copied.
---@param key                           ?string
---@return any
function M:payload(key)
  local read = self:_read()
  if read then
    local version = self._versions[read.header.data_revision]
    return version and version.payloads[key]
  end
  return self.source.payloads[key]
end

---@return integer
function M:linecount()
  local read = self:_read()
  return read and read.header.row_count or 0
end

---@param row                           integer
---@return string|nil
function M:retrieve_uuid(row)
  local frame = self:frame()
  local id = frame and frame:node_at(row)
  return id and self:_key(frame, id)
end

---@param key                           string
---@return integer|nil
function M:retrieve_lnum(key)
  local read = self:_read()
  local id = read and read.source:id(key)
  return id and read.frame:position(id)
end

---@param key                           ?string
---@return integer|nil
---@return string|nil
function M:retrieve_parent(key)
  local read = self:_read()
  if not read or not key then
    return nil
  end
  local frame = read.frame
  local version = self._versions[read.header.data_revision]
  local entry = version and version.entries[key]
  if entry and entry.nodetype == "location" then
    local parent = read.source:id(entry.leafuuid)
    local row = parent and frame:position(parent)
    return row, row and entry.leafuuid
  end
  local id = read.source:id(key)
  local row = id and frame:position(id)
  local parent_row = row and frame:navigate(row, "parent")
  local parent = parent_row and frame:node_at(parent_row)
  return parent_row, parent and self:_key(frame, parent)
end

---@param row                           integer
---@return integer|nil
function M:retrieve_lastchild_lnum(row)
  local frame = self:frame()
  if frame and row > 0 and row <= frame:header().row_count then
    return frame:rows(row, row).last_descendants[1]
  end
end

---@param key                           string
---@return boolean
function M:isselected(key)
  local read = self:_read()
  local id = read and read.source:id(key)
  local flags = id and read.frame:flags(id)
  return flags ~= nil and flags.marked
end

---@return table<string, true>
function M:collect_selected()
  local selected = {}
  for _, key in ipairs(self:selected_keys(false)) do
    selected[key] = true
  end
  return selected
end

---@param visible_only                  boolean
---@return era.view.result_tree.IRead|nil
---@return yoz.ux.treeview.NodeIds|nil
function M:_selected(visible_only)
  local read = self:_read()
  if not read then
    return nil
  end
  local ids = read.selected[visible_only]
  if not ids then
    ids = read.frame:marked_nodes(visible_only)
    read.selected[visible_only] = ids
  end
  return read, ids
end

---@return boolean
function M:has_selected()
  local _, ids = self:_selected(true)
  return ids ~= nil and ids:len() > 0
end

---@param visible_only                  boolean
---@return string[]
function M:selected_keys(visible_only)
  local read, ids = self:_selected(visible_only)
  local version = read and self._versions[read.header.data_revision]
  if not version or not ids then
    return {}
  end
  local selected = {}
  for first = 1, ids:len(), 1024 do
    local nodes = ids:slice(first, math.min(first + 1023, ids:len()))
    local keys = read.frame:node_keys(nodes)
    for index, key in ipairs(keys) do
      version.keys[nodes[index]] = key
      selected[#selected + 1] = key
    end
  end
  return selected
end

---@return integer[]
function M:collect_selected_rows()
  local read, ids = self:_selected(true)
  local rows = {}
  if read and ids then
    for first = 1, ids:len(), 1024 do
      for _, id in ipairs(ids:slice(first, math.min(first + 1023, ids:len()))) do
        rows[#rows + 1] = read.frame:position(id)
      end
    end
  end
  return rows
end

---@param key                           string
---@param value                         boolean
---@param recursive                     ?boolean
---@return nil
function M:toggle_select(key, value, recursive)
  self:_flush_selection()
  local frame = self:frame()
  local id = frame and frame:source():id(key)
  if id and self.state then
    self:_track_selection(self.state:dispatch({
      kind = value and "select_node" or "deselect_node",
      nodes = { id },
      recursive = recursive == true,
    }, { frame = frame }))
  end
end

---@param key                           string
---@param value                         boolean
---@return nil
function M:set_selected(key, value)
  local batch = self._selection_batch
  if not batch then
    local frame = self:frame()
    if not frame then
      return
    end
    batch = { frame = frame, values = {} }
    self._selection_batch = batch
    vim.schedule(function()
      if not self._disposed then
        self:_flush_selection()
      end
    end)
  end
  batch.values[key] = value
end

---@param future                        stl.c.Future
---@return nil
function M:_track_selection(future)
  self._selection_busy = (self._selection_busy or 0) + 1
  future:map(checked):finally(function(ok, error)
    self._selection_busy = math.max(0, (self._selection_busy or 0) - 1)
    if not ok then
      self:_fail(error)
    end
  end)
end

---@return nil
function M:_flush_selection()
  local batch = self._selection_batch
  if not batch or not self.state then
    return
  end
  self._selection_batch = nil
  local before, current = batch.frame:source(), self._data:source()
  local selected, deselected = {}, {}
  for key, value in pairs(batch.values) do
    local id = before:id(key)
    if id and id == current:id(key) then
      local target = value and selected or deselected
      target[#target + 1] = id
    end
  end
  if #selected > 0 then
    self:_track_selection(self.state:select_node(selected, false))
  end
  if #deselected > 0 then
    self:_track_selection(self.state:deselect_node(deselected, false))
  end
end

---@return boolean
function M:selection_pending()
  if self._selection_batch or (self._selection_busy or 0) > 0 then
    return true
  end
  local frame = self:frame()
  return self.state ~= nil
    and frame ~= nil
    and frame:header().selection_revision ~= self.state:status().revisions.selection
end

---@param callback                      fun(): nil
---@return boolean
function M:after_selection(callback)
  if not self:selection_pending() then
    return false
  end
  self
    :ready()
    :map(checked)
    :map(function()
      if not self._disposed then
        callback()
      end
    end)
    :catch(function(error)
      if not self._failure then
        self:_error(error)
      end
    end)
  return true
end

---@return nil
function M:toggle_selection()
  self:_flush_selection()
  if self.view then
    self:_track_selection(self.view:range_action(function(frame, first, last, visual)
      if visual and first ~= last then
        local read = self:_read(frame)
        local version = self._versions[read.header.data_revision]
        local nodes = {}
        for at = first, last, 1024 do
          local ids = {}
          for row = at, math.min(at + 1023, last) do
            ids[#ids + 1] = frame:node_at(row)
          end
          for index, key in ipairs(frame:node_keys(ids)) do
            local entry = version and version.entries[key]
            if entry and entry.nodetype ~= "location" then
              nodes[#nodes + 1] = ids[index]
            end
          end
        end
        if #nodes == 0 then
          return Future.resolve({ kind = "NoChange" })
        end
        local select = read.header.summary.is_empty or not frame:all_marked(nodes)
        return self.state:dispatch({
          kind = select and "select_node" or "deselect_node",
          nodes = nodes,
          recursive = false,
        }, { frame = frame })
      end
      local key = self:retrieve_uuid(first)
      local entry = key and self:retrieve(key)
      if entry and entry.nodetype == "location" then
        return self.state:dispatch({
          kind = "toggle_node",
          nodes = { frame:source():id(entry.leafuuid) },
          recursive = true,
        }, { frame = frame })
      end
      return self.state:dispatch({
        kind = "toggle_node",
        range = { frame = frame, first = first, last = last },
        recursive = true,
      })
    end, false))
  end
end

---@param key                           string
---@param action                        "toggle"|"collapse"|"expand"
---@param recursive                     ?boolean
---@return nil
function M:collapse(key, action, recursive)
  local frame = self:frame()
  local id = frame and frame:source():id(key)
  if id and self.state then
    self.state
      :dispatch({
        kind = action == "toggle" and "toggle_expanded" or "set_expanded",
        node = id,
        nodes = { id },
        value = action == "expand",
        recursive = recursive == true,
      }, { frame = frame })
      :map(checked)
      :catch(function(error)
        self:_error(error)
      end)
  end
end

---@param key                           string
---@return boolean
function M:isvisible(key)
  return not self._hidden[key]
end

---@param key                           string
---@return nil
function M:mark_node_invisible(key)
  self._hidden[key] = true
  self:invalidate()
end

---@return nil
function M:reset_hidden()
  self._hidden = {}
  self:invalidate()
end

---@param root                          ?string
---@return string[]
function M:collect_leafs(root)
  local keys = {}
  self.source:walk(root, function(key)
    local entry = self.entries[key]
    if entry and entry.nodetype == "leaf" then
      keys[#keys + 1] = key
    end
  end)
  return keys
end

---@return nil
function M:clear_match()
  self._matches, self._last_match_result = nil, nil
end

---@param params                        table
---@return string[]
function M:match(params)
  local cached = self._last_match_result
  if cached and cached.revision == self.source.revision and vim.deep_equal(cached.params, params) then
    return vim.list_slice(cached.keys)
  end
  local keys, lines = {}, {}
  local previous = cached and cached.params
  local narrow = cached
    and cached.revision == self.source.revision
    and not params.regex
    and not previous.regex
    and previous.rootuuid == params.rootuuid
    and previous.fuzzy == params.fuzzy
    and previous.case_sensitive == params.case_sensitive
    and params.pattern:sub(1, #previous.pattern) == previous.pattern
  if narrow then
    keys = vim.list_slice(cached.keys)
    for index, key in ipairs(keys) do
      local data, entry = self.source:get(key), self.entries[key]
      lines[index] = data.filepath or entry.text or data.name or ""
    end
  else
    self.source:walk(params.rootuuid, function(key, data)
      local entry = self.entries[key]
      if entry and (entry.text ~= nil or entry.nodetype == "leaf") then
        keys[#keys + 1] = key
        lines[#lines + 1] = data.filepath or entry.text or data.name or ""
      end
    end)
  end
  local matches = {}
  if params.pattern ~= "" then
    local result, error = yoz.search.search_in_lines({
      pattern = params.pattern,
      lines = lines,
      flag_fuzzy = params.fuzzy,
      flag_regex = params.regex,
      flag_case_sensitive = params.case_sensitive,
    })
    if not result then
      self:_error(error)
      keys = {}
    else
      local matched = {}
      for _, item in ipairs(result.lines or {}) do
        local key = keys[item.lnum]
        matched[#matched + 1] = key
        matches[key] = { score = item.score, matches = item.matches }
      end
      keys = matched
    end
  end
  self._matches = matches
  self._last_match_result = { params = vim.deepcopy(params), keys = keys, revision = self.source.revision }
  return vim.list_slice(keys)
end

---@param key                           string
---@return number
function M:match_score(key)
  local match = self._matches and self._matches[key]
  return match and match.score or 0
end

---@param error                         any
---@return nil
function M:_error(error)
  if not self._disposed then
    stl.reporter.error({
      from = self.fullname,
      subject = "Treeview",
      message = type(error) == "table" and error.message or tostring(error),
    })
  end
end

---@param error                         any
---@return nil
function M:_fail(error)
  self._failure, self._focus = error, nil
  if self._waiting then
    self._waiting.resolve({ kind = "Rejected", error = error })
    self._waiting = nil
  end
  local waiting = self._ready
  self._ready = {}
  for _, resolve in ipairs(waiting) do
    resolve({ kind = "Rejected", error = error })
  end
  self:_error(error)
end

---@return stl.c.Future
function M:_snapshot()
  local source, revision, input_revision = self.source, self._revision, self.source.revision
  local previous = self._record_cache
  if previous and previous.revision ~= self._data:source():revision() then
    previous = nil
  end
  local metadata = previous and self._versions[previous.revision]
  local builder = Snapshot.new(source, self.entries, self._hidden, self._present, previous, metadata)
  return Future.new(function(resolve, reject)
    ---@return nil
    local function step()
      if self._disposed then
        reject("result tree disposed")
        return
      end
      if self.source ~= source or self._revision ~= revision or source.revision ~= input_revision then
        resolve(nil)
        return
      end
      local ok, done = pcall(builder.step, builder)
      if not ok then
        reject(done)
      elseif done then
        resolve(builder.snapshot)
      else
        vim.schedule(step)
      end
    end
    step()
  end)
end

---@param snapshot                      table
---@return stl.c.Future
function M:_import(snapshot)
  if snapshot.updates then
    if snapshot.base_revision ~= self._data:source():revision() then
      return Future.reject("result source changed while preparing updates")
    end
    if #snapshot.updates == 0 then
      return Future.resolve(true)
    end
    local operations = {}
    for _, record in ipairs(snapshot.updates) do
      local score, fields = record.score, record.fields
      if score == nil then
        score = 0
      end
      if fields == nil then
        fields = {}
      end
      operations[#operations + 1] = {
        kind = "update",
        node = record.key,
        label = record.label,
        can_expand = record.can_expand or false,
        foldable = record.foldable or false,
        hidden = record.hidden or false,
        score = score,
        icon = record.icon or false,
        highlight = record.highlight or false,
        right_text = record.right_text or false,
        fields = fields,
        completeness = "complete",
      }
    end
    return self._data:batch(operations, snapshot.base_revision):map(checked)
  end
  local upload = self._data:begin_import()
  self._upload = upload
  local records = {}
  for name, values in pairs(snapshot.records) do
    if name == "keys" or name == "labels" or next(values) ~= nil then
      records[name] = values
    end
  end
  return Future.new(function(resolve, reject)
    local first = 1
    ---@return nil
    local function append()
      if self._disposed then
        upload:dispose()
        reject("result tree disposed")
        return
      end
      local last = math.min(first + 255, #records.keys)
      if first <= last then
        local columns = {}
        for name, values in pairs(records) do
          local default = RECORD_DEFAULTS[name]
          local needed = default == nil
          if not needed then
            for index = first, last do
              if values[index] ~= nil and values[index] ~= default then
                needed = true
                break
              end
            end
          end
          if needed then
            local column = {}
            for index = first, last do
              local value = values[index]
              if value == nil then
                value = default
              end
              column[#column + 1] = value
            end
            columns[name] = column
          end
        end
        local reply = upload:append(columns)
        if reply.kind == "Rejected" then
          upload:dispose()
          reject(reply.error.message)
          return
        end
        first = last + 1
        vim.schedule(append)
      else
        upload:commit():map(checked):finally(function(ok, result)
          self._upload = nil
          if ok then
            resolve(result)
          else
            reject(result)
          end
        end)
      end
    end
    append()
  end)
end

---@param request                       table
---@return stl.c.Future
function M:_display(request)
  local source = self._data:source()
  local root = source:id(request.rootuuid or self.source.root)
  local filtered = not request.all_rows
    and (request.mode == "list" or request.list_from_depth ~= nil or request.only_matched)
  local signature = {
    revision = filtered and source:revision() or nil,
    root = request.rootuuid,
    root_id = root,
    mode = request.mode,
    compress = request.foldempty,
    selected = request.only_selected,
    matched = request.only_matched,
    orders = filtered and request.orders or nil,
    all_rows = request.all_rows,
    list_text = request.list_text,
    list_from_depth = request.list_from_depth,
  }
  local same = self._configured ~= nil
  for key, value in pairs(signature) do
    same = same and self._configured[key] == value
  end
  if same then
    for key, value in pairs(self._configured) do
      same = same and signature[key] == value
    end
  end
  local display = {
    mode = request.mode,
    compress = request.foldempty and request.list_from_depth == nil,
    show_hidden = false,
    selected_only = request.only_selected,
    sort = "source",
    list_text = request.list_text or "label",
    list_from_depth = request.list_from_depth,
  }
  if not same and filtered then
    local filter = {}
    local keys = request.orders or self:collect_leafs(request.rootuuid)
    for _, key in ipairs(keys) do
      local id = source:id(key)
      if id then
        filter[#filter + 1] = id
        local entry = self.entries[key]
        for _, location in ipairs(entry and entry.locations or {}) do
          local child = source:id(location.locationuuid)
          if child then
            filter[#filter + 1] = child
          end
        end
      end
    end
    display.filter = filter
  end
  local native_root = root and { kind = "children_of", node = root } or { kind = "forest", nodes = {} }
  local future
  if self.state and same then
    future = Future.resolve(true)
  elseif self.state then
    local rooted = self._configured and self._configured.root_id == root
    future = rooted and Future.resolve(true) or absolute(self.state, { kind = "set_root", root = native_root })
    future = future:then_(function()
      return absolute(self.state, { kind = "set_display", display = display })
    end)
  else
    future = self._data:create_state(native_root, display):map(checked):then_(function(state)
      if self._disposed then
        return Future.reject("result tree disposed")
      end
      self.state = state
      local base = source:id(self.source.root)
      return base and state:set_expanded({ base }, true, true):map(checked) or Future.resolve(true)
    end)
  end
  return future
    :then_(function()
      if self._disposed then
        return Future.reject("result tree disposed")
      end
      self._configured = signature
      local closed = {}
      for _, key in ipairs(request.new_closed or {}) do
        local id = source:id(key)
        if id then
          closed[#closed + 1] = id
        end
      end
      return #closed > 0 and self.state:set_expanded(closed, false, false):map(checked) or true
    end)
    :then_(function()
      if self._disposed then
        return Future.reject("result tree disposed")
      end
      local selected = {}
      for key in pairs(self._restore_selection or {}) do
        local id = source:id(key)
        if id then
          selected[#selected + 1] = id
        end
      end
      self._restore_selection = nil
      return #selected > 0 and self.state:select_node(selected, false):map(checked) or true
    end)
    :map(function()
      if self._disposed then
        return
      end
      self:_attach()
      local waiting = self._waiting
      if waiting then
        waiting.resolve({ kind = "Superseded" })
      end
      self._waiting = { resolve = request.resolve }
      if not self.view then
        self._frame = self.state:snapshot()
      end
      self:_published(self:frame())
      self:_run_commands()
    end)
end

---@param request                       table
---@return stl.c.Future
function M:publish(request)
  self:__health__()
  if self._request and self._request.resolve then
    self._request.resolve({ kind = "Superseded" })
  end
  local future, resolve = Future.new_with_resolver()
  request.resolve = resolve
  self._request = request
  if self._busy or self._scheduled then
    return future
  end
  self._scheduled = true
  vim.schedule(function()
    self._scheduled = false
    if not self._disposed then
      self:_drain()
    end
  end)
  return future
end

---@return nil
function M:_drain()
  local request = self._request
  if not request then
    return
  end
  self._failure = nil
  self._request, self._busy, self._active_request = nil, true, request
  local revision, input_revision = self._revision, self.source.revision
  local changed = self._accepted_revision ~= revision or self._accepted_input ~= input_revision
  local snapshot, superseded
  request.new_closed = {}
  local future = changed and self:_snapshot() or Future.resolve(nil)
  future
    :then_(function(prepared)
      snapshot = prepared
      if changed and not snapshot then
        superseded = true
        if self._request then
          request.resolve({ kind = "Superseded" })
        else
          self._request = request
        end
        return
      end
      if snapshot then
        local source = self._data:source()
        for _, key in ipairs(request.default_closed or {}) do
          if not source:id(key) then
            request.new_closed[#request.new_closed + 1] = key
          end
        end
        return self:_import(snapshot)
      end
    end)
    :then_(function()
      if self._disposed or superseded then
        return
      end
      if snapshot then
        local data_revision = self._data:source():revision()
        self._record_cache =
          { topology = snapshot.topology, signatures = snapshot.signatures, revision = data_revision }
        snapshot.records, snapshot.updates, snapshot.topology, snapshot.signatures, snapshot.base_revision =
          nil, nil, nil, nil, nil
        self._versions[data_revision] = snapshot
        self._accepted_revision, self._accepted_input = revision, input_revision
        for view in pairs(self._data._views) do
          view:refresh_decorations()
        end
      end
      return self:_display(request)
    end)
    :finally(function(ok, error)
      self._busy, self._active_request = false, nil
      if not ok then
        self:_fail(error)
        request.resolve({ kind = "Rejected", error = error })
      end
      if self._request and not self._disposed then
        vim.schedule(function()
          if not self._disposed and not self._busy then
            self:_drain()
          end
        end)
      end
    end)
end

---@return boolean
function M:is_current()
  local frame = self:frame()
  return frame ~= nil
    and self._accepted_revision == self._revision
    and self._accepted_input == self.source.revision
    and frame:header().data_revision == self._data:source():revision()
end

---@param winnr                         integer
---@param bufnr                         integer
---@param on_frame                      fun(frame: yoz.ux.treeview.Frame): nil
---@param on_attach                     ?fun(view: ux.treeview.View): nil
---@return nil
function M:mount(winnr, bufnr, on_frame, on_attach)
  self._mount = { winnr = winnr, bufnr = bufnr, on_frame = on_frame, on_attach = on_attach }
  self:_attach()
end

---@param view                          ux.treeview.View
---@param frame                         yoz.ux.treeview.Frame
---@param row                           integer
---@param id                            string
---@param col                           integer
---@param label                         string
---@param expanded                      boolean
---@return ux.treeview.INode|nil
function M:decorate_row(view, frame, row, id, col, label, expanded)
  local node = frame:node(id)
  local directory = node and node.fields.directory_icon
  local name = directory or node and node.fields.file_icon
  if name then
    local icon
    if directory then
      local icons = self._directory_icons[name]
      if not icons then
        local glyph, highlight = stl.fileicon.get_directory_icon(name)
        icons = { { glyph, highlight }, { stl.icon.filetype.FolderOpen, highlight } }
        self._directory_icons[name] = icons
      end
      icon = icons[expanded and 2 or 1]
    else
      icon = self._icons[name]
      if not icon then
        local glyph, highlight = stl.fileicon.get_file_icon(name)
        icon = { glyph, highlight }
        self._icons[name] = icon
      end
    end
    vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, col - 2, {
      ephemeral = true,
      virt_text = { icon },
      virt_text_pos = "overlay",
      hl_mode = "combine",
      priority = 130,
    })
  end
  local offset = node and #label - #node.label or 0
  for _, highlight in ipairs(node and node.fields.highlights or {}) do
    local first = offset + highlight.coll
    local last = highlight.colr < 0 and #label or math.min(#label, offset + highlight.colr)
    if first < last then
      vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, col + first, {
        ephemeral = true,
        end_col = col + last,
        hl_group = highlight.hlname,
        priority = 160,
      })
    end
  end
  if node and node.fields.overlay then
    vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, 0, {
      ephemeral = true,
      virt_text = node.fields.overlay,
      virt_text_pos = "right_align",
      hl_mode = "combine",
      priority = 100,
    })
  end
  local match = node and self._matches and self._matches[node.key]
  if match then
    local version = self._versions[frame:header().data_revision]
    local data = version and version.data[node.key]
    local base = data and data.filepath and #data.filepath - #data.basename - offset or -offset
    local length = data and data.basename and offset + #data.basename or #label
    for _, point in ipairs(match.matches) do
      local regions = node.fields.match_regions or { { base, base + length, 0 } }
      for _, region in ipairs(regions) do
        local first = math.max(point.l, region[1]) - region[1] + region[3]
        local last = math.min(point.r, region[2]) - region[1] + region[3]
        if node.fields.match_regions then
          first, last = first + offset, last + offset
        end
        first, last = math.max(0, first), math.min(#label, last)
        if first < last then
          vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, col + first, {
            ephemeral = true,
            end_col = col + last,
            hl_group = "TreeviewMatch",
            priority = 180,
          })
        end
      end
    end
  end
  return node
end

---@param frame                         yoz.ux.treeview.Frame
---@return stl.c.Future
function M:prepare_frame(frame)
  if not self._versions[frame:header().data_revision] then
    return Future.resolve(false)
  end
  return Future.resolve(function(published)
    self:_prune_versions(published)
    return true
  end)
end

---@return nil
function M:_attach()
  local mount = self._mount
  if not self.state or not mount or not vim.api.nvim_win_is_valid(mount.winnr) then
    return
  end
  if self.view and not self.view:status().closed then
    if not self.view:is_suspended() then
      return
    end
    if self.view.bufnr == mount.bufnr then
      self.view:resume(mount.winnr)
      return
    end
    self.view:detach()
  end
  self.view = treeview.attach(self.state, {
    winnr = mount.winnr,
    bufnr = mount.bufnr,
    keymaps = false,
    on_attach = function(view)
      if self._mount and self._mount.on_attach then
        self._mount.on_attach(view)
      end
    end,
    prepare_frame = function(_, frame)
      return self:prepare_frame(frame)
    end,
    decorate_row = function(view, frame, row, id, col, label, expanded)
      self:decorate_row(view, frame, row, id, col, label, expanded)
    end,
    on_frame = function(frame)
      self._frame = frame
      self:_published(frame)
      if self._mount then
        self._mount.on_frame(frame)
      end
    end,
    on_error = function(error)
      self:_fail(error)
    end,
  })
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return nil
function M:_prune_versions(frame)
  if self._disposed then
    return
  end
  local keep = { [self._data:source():revision()] = true }
  if frame then
    keep[frame:header().data_revision] = true
  end
  local retained = self.view and self.view:frame()
  if retained then
    keep[retained:header().data_revision] = true
  end
  for view in pairs(self._data._views) do
    if view ~= self.view then
      local displayed = view:frame()
      if displayed then
        keep[displayed:header().data_revision] = true
      end
    end
  end
  for revision in pairs(self._versions) do
    if not keep[revision] then
      self._versions[revision] = nil
    end
  end
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return nil
function M:_published(frame)
  self:_prune_versions(frame)
  local waiting = self._waiting
  local presented = not self.view or self.view:is_suspended() or not self.view:status().preparing
  if waiting and frame and presented and not self:selection_pending() and self.state._native:applicable(frame) then
    self._waiting = nil
    waiting.resolve({ kind = "Applied", frame = frame })
  end
  self:_settle_ready()
end

---@return stl.c.Future
function M:ready()
  if self._disposed or self._failure then
    return Future.resolve({ kind = "Rejected", error = self._failure or "result tree disposed" })
  end
  local future, resolve = Future.new_with_resolver()
  self._ready[#self._ready + 1] = resolve
  self:_settle_ready()
  require("ux.treeview.async").watch(self._data)
  return future
end

---@return nil
function M:_settle_ready()
  if
    #self._ready == 0
    or self._busy
    or self._request
    or self._command_busy
    or self._focus
    or self.view and not self.view:is_suspended() and self.view:status().preparing
    or self:selection_pending()
    or not self:is_current()
  then
    return
  end
  local frame = self:frame()
  if frame:header().state_revision ~= self.state:status().revisions.state then
    return
  end
  local waiting = self._ready
  self._ready = {}
  for _, resolve in ipairs(waiting) do
    resolve({ kind = "Applied", frame = frame })
  end
end

---@param key                           string
---@return boolean
function M:expanded(key)
  local frame = self.state and self.state:snapshot()
  local id = frame and frame:source():id(key)
  local flags = id and frame:flags(id)
  return flags and flags.expanded
end

---@param key                           string
---@param value                         boolean|nil Nil toggles the current native value.
---@param recursive                     ?boolean
---@return nil
function M:set_expansion(key, value, recursive)
  self._commands[#self._commands + 1] = { key = key, value = value, recursive = recursive == true }
  self:_run_commands()
end

---@return nil
function M:_run_commands()
  if not self.state or self._command_busy or #self._commands == 0 or self._disposed then
    return
  end
  local command = table.remove(self._commands, 1)
  local frame = self.state:snapshot()
  local id = frame:source():id(command.key)
  if not id then
    self:_run_commands()
    return
  end
  self._command_busy = true
  self.state
    :dispatch({
      kind = command.value == nil and "toggle_expanded" or "set_expanded",
      node = id,
      nodes = { id },
      value = command.value,
      recursive = command.recursive,
    }, { frame = frame })
    :map(checked)
    :finally(function(ok, error)
      self._command_busy = false
      if not ok then
        self:_error(error)
      end
      self:_run_commands()
    end)
end

---@param key                           string
---@param fallback                      ?string
---@return nil
function M:focus_key(key, fallback)
  self._focus = { key = key, fallback = fallback }
  require("ux.treeview.async").watch(self._data)
end

---@return nil
function M:_focus_pending()
  local intent = self._focus
  if not intent or not self.state or self._busy or self._request or self._command_busy or intent.submitted then
    return
  end
  local frame = self.state:snapshot()
  local header = frame:header()
  if header.state_revision ~= self.state:status().revisions.state or not self:is_current() then
    return
  end
  local id = frame:source():id(intent.key)
  if intent.fallback and (not id or not frame:position(id)) then
    id = frame:source():id(intent.fallback)
  end
  if not id or not frame:position(id) then
    self._focus = nil
    return
  end
  intent.submitted = true
  self.state:dispatch({ kind = "set_cursor", node = id }, { frame = frame }):finally(function(ok, reply)
    if self._focus == intent then
      self._focus = nil
      if not ok or reply.kind == "Rejected" then
        self:_error(ok and reply.error.message or reply)
      end
    end
  end)
end

---@param retain                        ?boolean Keep the owned buffer and published Frame for a reusable result.
---@return nil
function M:unmount(retain)
  self._mount, self._read_cache = nil, nil
  if self.view then
    self._frame = self.view:frame()
    if retain then
      self.view:suspend()
    else
      self.view:detach()
      self.view = nil
    end
  end
end

---@param key                           string
---@param compress                      boolean
---@param state                         ?ux.treeview.State
---@return stl.c.Future
function M:preview_state(key, compress, state)
  local id = self._data:source():id(key)
  if not id then
    return Future.reject("preview node is no longer present")
  end
  local root = { kind = "children_of", node = id }
  local display = { mode = "tree", compress = compress, show_hidden = true }
  local future = state and absolute(state, { kind = "set_root", root = root }):map(function()
    return state
  end) or self._data:create_state(root, display):map(checked)
  return future:then_(function(current)
    return absolute(current, { kind = "set_display", display = display }):then_(function()
      return current:set_expanded({ id }, true, true):map(checked):map(function()
        return current
      end)
    end)
  end)
end

return M
