---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.directory" ---@type string

local Filetree = require("ux.filetree")
local Treeview = require("ux.treeview")
local Future = require("stl.c.future")
local namespace = vim.api.nvim_create_namespace("era.directory")

---@class era.view.directory.IListing
---@field layout                        ux.treeview.Revision
---@field source                        yoz.ux.treeview.Source
---@field first                         integer
---@field last                          integer
---@field entries                       table<ux.treeview.NodeId, ux.filetree.IListingRow>

---A Directory owner caches listing rows on whichever Treeview View it decorates.
---@class era.view.directory.View : ux.treeview.View
---@field _directory_listing            ?era.view.directory.IListing

---@class era.view.Directory
---@field data                          ?ux.filetree.Data
---@field state                         ?ux.treeview.State
---@field view                          ?ux.treeview.View
---@field _disposed                     boolean
---@field _generation                   integer
---@field _display                      ux.treeview.IDisplay
---@field _icons                        table<string, table>
---@field _icon_count                   integer
local M = {}
M.__index = M

---@param value                         any
---@return any
local function checked(value)
  if type(value) == "table" and value.kind == "Rejected" then
    error(type(value.error) == "table" and value.error.message or tostring(value.error), 0)
  end
  return value
end

---@param state                         ux.treeview.State
---@param command                       ux.treeview.ICommand
---@param retries                       ?integer
---@return stl.c.Future
local function absolute(state, command, retries)
  retries = retries or 8
  return state:dispatch(command, { expected_state = state:status().revisions.state }):then_(function(reply)
    if reply.kind == "Rejected" and reply.error.code == "Stale" and retries > 0 then
      return absolute(state, command, retries - 1)
    end
    return checked(reply)
  end)
end

---@param error                         any
---@return nil
local function report(error)
  stl.reporter.error({ from = __module_name__, message = tostring(error) })
end

---@return era.view.Directory
function M.new()
  return setmetatable({
    _disposed = false,
    _generation = 0,
    _icons = {},
    _icon_count = 0,
    _display = {
      mode = "list",
      list_text = "label",
      list_depth = 0,
      context_label = "../",
      branch_suffix = "/",
      show_hidden = true,
    },
  }, M)
end

---@return yoz.ux.treeview.Frame|nil
function M:frame()
  if self.view and not self.view:is_suspended() then
    return self.view:frame()
  end
  return self.state and self.state:snapshot()
end

---@param row                           integer
---@return yoz.ux.filetree.Resource|nil
---@return boolean
function M:retrieve(row)
  local frame = self:frame()
  local id = frame and frame:node_at(row)
  if not frame or not id or not self.data then
    return nil, false
  end
  local root = frame:header().root
  local parent = root.kind == "children_of" and root.node == id
  if parent then
    id = frame:source():node(id).parent or id
  end
  return self.data:inspect(frame:source(), id), parent
end

---@param directory                     string
---@param focus                         ?string
---@return stl.c.Future
function M:open(directory, focus)
  self._generation = self._generation + 1
  local generation = self._generation
  if not self._opening then
    self._opening = self.data and Future.resolve(self.data) or Filetree.open(directory):map(checked)
  end
  local future = self._opening:then_(function(data)
    if self._disposed or generation ~= self._generation then
      return nil
    end
    self.data = data
    return data:resolve(directory):map(checked):then_(function(resource)
      if self._disposed or generation ~= self._generation then
        return nil
      end
      local root = { kind = "children_of", node = resource:node() }
      local update = self.state
          and absolute(self.state, { kind = "set_root", root = root }):map(function()
            return self.state
          end)
        or data:create_state(root, self._display):map(checked)
      return update:map(function(state)
        if self._disposed or generation ~= self._generation then
          return nil
        end
        self.state = state
        self:_filter()
        self._focus = { root = resource:node(), path = focus, sequence = state:navigation_sequence() }
        self:_attach()
        if self.view then
          self.view:refresh_decorations()
        end
        return resource
      end)
    end)
  end)
  future:finally(function(ok, error)
    if not ok and generation == self._generation and not self._disposed then
      self._opening = nil
      report(error)
    end
  end)
  return future
end

---@param display                       ux.treeview.IDisplay
---@return nil
function M:filter(display)
  local next_display = vim.tbl_extend("force", self._display, display)
  if vim.deep_equal(next_display, self._display) then
    return
  end
  self._display = next_display
  self:_filter()
end

---@return nil
function M:_filter()
  if not self.state or self._filtering or self._disposed then
    return
  end
  local display = self._display
  self._filtering = true
  absolute(self.state, { kind = "set_display", display = display }):finally(function(ok, error)
    self._filtering = false
    if not ok then
      report(error)
    end
    if self._display ~= display then
      self:_filter()
    end
  end)
end

---@return stl.c.Future
function M:refresh()
  return self.state and self.data:refresh(self.state):map(checked) or Future.resolve(nil)
end

---@param path                          ?string
---@param row                           ?integer Fallback row after a mutation.
---@return nil
function M:focus_path(path, row)
  local frame = self:frame()
  if frame then
    self._focus =
      { root = frame:header().root.node, path = path, row = row, sequence = self.state:navigation_sequence() }
    if self.view then
      self.view:refresh_decorations()
    end
  end
end

---@param frame                         yoz.ux.treeview.Frame
---@return nil
function M:_focused(frame)
  local focus = self._focus
  if not focus or focus.submitted or focus.root ~= frame:header().root.node then
    return
  end
  if focus.sequence ~= self.state:navigation_sequence() then
    self._focus = nil
    return
  end
  local root = frame:source():node(focus.root)
  if not root or root.completeness ~= "complete" then
    return
  end
  if frame:header().data_revision ~= self.data:source():revision() then
    return
  end
  focus.submitted = true
  local target = focus.path and self.data:resolve(focus.path):map(checked) or Future.resolve(nil)
  target
    :then_(function(resource)
      if self._disposed or self._focus ~= focus then
        return
      end
      self._focus = nil
      if
        self.state:navigation_sequence() ~= focus.sequence or self.state:snapshot():header().root.node ~= focus.root
      then
        return
      end
      local latest = self.state:snapshot()
      local id = resource and resource:node()
      if not id or not latest:position(id) then
        local row = math.min(focus.row or 2, latest:header().row_count)
        id = row > 0 and latest:node_at(row) or nil
      end
      if id then
        return self.state:dispatch({ kind = "set_cursor", node = id }, { frame = latest }):map(checked)
      end
    end)
    :catch(function(error)
      if self._focus == focus then
        self._focus = nil
      end
      report(error)
    end)
end

---@param frame                         yoz.ux.treeview.Frame
---@param view                          ux.treeview.View
---@param first                         integer
---@param last                          integer
---@return stl.c.Future
function M:prepare_frame(frame, view, first, last)
  ---@cast view era.view.directory.View
  local cache = view._directory_listing
  local header, source = frame:header(), frame:source()
  if
    cache
    and cache.layout == header.layout_revision
    and cache.first <= first
    and cache.last >= last
    and cache.source:same_content(source)
  then
    return Future.resolve(function()
      return true
    end)
  end
  return self.data:listing(frame, first + 1, last, true):map(checked):map(function(rows)
    local entries = {}
    for _, entry in ipairs(rows) do
      entries[entry.node] = entry
    end
    return function()
      view._directory_listing =
        { layout = header.layout_revision, source = source, first = first, last = last, entries = entries }
      return false
    end
  end)
end

---@param view                          ux.treeview.View
---@param frame                         yoz.ux.treeview.Frame
---@param row                           integer
---@param id                            string
---@param col                           integer
---@param label                         string
---@param expanded                      boolean
---@return nil
function M:decorate_row(view, frame, row, id, col, label, expanded)
  ---@cast view era.view.directory.View
  local cache = view._directory_listing
  local entry = cache and cache.entries[id]
  if not entry then
    return
  end
  local icon = entry.directory and { stl.icon.kind.Folder, "m_fe_name_dir" } or self._icons[label]
  if not icon then
    if self._icon_count >= 512 then
      self._icons, self._icon_count = {}, 0
    end
    local glyph, highlight = stl.fileicon.get_file_icon(label)
    icon = { glyph, highlight }
    self._icons[label] = icon
    self._icon_count = self._icon_count + 1
  end
  vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, math.max(0, col - 2), {
    ephemeral = true,
    virt_text = { icon },
    virt_text_pos = "overlay",
    hl_mode = "combine",
    priority = 140,
  })
  local directory = entry.directory
  vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, col, {
    ephemeral = true,
    end_col = col + #label,
    hl_group = directory and "m_fe_name_dir" or "m_fe_name_file",
    priority = 130,
  })
  local chunks = {
    { "  " },
    { entry.permissions:sub(1, 1), directory and "m_fe_perm_dir" or "m_fe_perm_file" },
    { entry.permissions:sub(2) .. "  ", "m_fe_perm" },
    { string.format("%8s  ", entry.size), "m_fe_size" },
  }
  if view ~= self.view and not stl.env.IS_WIN then
    chunks[#chunks + 1] = { entry.owner .. " ", "m_fe_owner" }
    chunks[#chunks + 1] = { entry.group .. "  ", "m_fe_group" }
  end
  chunks[#chunks + 1] = { entry.date .. "  ", "m_fe_date" }
  local width = 0
  for _, chunk in ipairs(chunks) do
    width = width + vim.api.nvim_strwidth(chunk[1])
  end
  local available = view._decorations.rightcol - view._decorations.leftcol
  if available >= width + 12 then
    vim.api.nvim_buf_set_extmark(view.bufnr, namespace, row, 0, {
      ephemeral = true,
      virt_text = chunks,
      virt_text_win_col = available - width,
      hl_mode = "combine",
      priority = 200,
    })
  end
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

---@return nil
function M:_attach()
  local mount = self._mount
  if not mount or not self.state or not vim.api.nvim_win_is_valid(mount.winnr) then
    return
  end
  if self.view and not self.view:status().closed then
    if self.view:is_suspended() then
      self.view:resume(mount.winnr)
    end
    return
  end
  self.view = Treeview.attach(self.state, {
    winnr = mount.winnr,
    bufnr = mount.bufnr,
    keymaps = false,
    glyphs = { leaf = "", collapsed = "", expanded = "" },
    on_attach = function(view)
      if self._mount and self._mount.on_attach then
        self._mount.on_attach(view)
      end
    end,
    prepare_frame = function(view, frame, first, last)
      return self:prepare_frame(frame, view, first, last)
    end,
    decorate_row = function(view, frame, row, id, col, label, expanded)
      self:decorate_row(view, frame, row, id, col, label, expanded)
    end,
    on_frame = function(frame)
      self:_focused(frame)
      if self._mount then
        self._mount.on_frame(frame)
      end
    end,
    on_error = report,
  })
end

---@param retain                        ?boolean
---@return nil
function M:unmount(retain)
  self._mount = nil
  if self.view then
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
  local root = { kind = "children_of", node = key }
  if state then
    return absolute(state, { kind = "set_root", root = root }):map(function()
      return state
    end)
  end
  return self.data
    :create_state(root, { mode = "list", list_text = "label", list_depth = 0, branch_suffix = "/", show_hidden = true })
    :map(checked)
end

---@return nil
function M:dispose()
  self._disposed = true
  self._generation = self._generation + 1
  self:unmount()
  self.data, self.state, self._opening, self._focus, self._icons = nil, nil, nil, nil, {}
end

return M
