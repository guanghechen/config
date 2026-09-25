---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.filetree.annotations" ---@type string

local async = require("ux.treeview.async")
local Future = require("stl.c.future")
local namespace = vim.api.nvim_create_namespace("ux.filetree.annotations")
local views = setmetatable({}, { __mode = "v" }) ---@type table<integer, ux.filetree.View>
local M = {}

---@class ux.filetree.View : ux.treeview.View
---@field _filetree_annotations         ?ux.filetree.IAnnotationRows
---@field _filetree_pending             ?stl.c.Future
---@field _filetree_annotation_key      ?string
---@field _filetree_annotation_data     ?string
---@field _filetree_annotation_layout   ?string
---@field _filetree_annotation_source   ?yoz.ux.treeview.Source

---@param view                          ux.filetree.View
---@param header                        ux.treeview.IFrameHeader
---@param source                        yoz.ux.treeview.Source
---@return boolean
local function same_rows(view, header, source)
  return view._filetree_annotation_layout == header.layout_revision
    and (
      view._filetree_annotation_data == header.data_revision
      or view._filetree_annotation_source ~= nil and view._filetree_annotation_source:same_content(source)
    )
end

---@param view                          ux.filetree.View
---@param value                         ?ux.filetree.IAnnotationRows
---@param first                         integer
---@param last                          integer
---@param revision                      string
---@return fun(frame: yoz.ux.treeview.Frame): nil
local function publication(view, value, first, last, revision)
  return function(frame)
    local header = frame:header()
    view._filetree_annotation_key =
      table.concat({ header.data_revision, header.layout_revision, first, last, revision }, ":")
    view._filetree_annotations = value
    if value then
      value.frame = frame:id()
      view._filetree_annotation_data = header.data_revision
      view._filetree_annotation_layout = header.layout_revision
      view._filetree_annotation_source = frame:source()
    else
      view._filetree_annotation_source = nil
    end
  end
end

---@param view                          ux.filetree.View
---@param native                        yoz.ux.filetree.Data
---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@return stl.c.Future
function M.prepare(view, native, frame, first, last)
  local revision = native:annotation_revision()
  local cached = view._filetree_annotations
  if revision == "0" then
    return Future.resolve(publication(view, nil, first, last, revision))
  end
  if
    cached
    and cached.revision == revision
    and cached.first <= first + 1
    and cached.first + #cached.rows - 1 >= last
    and same_rows(view, frame:header(), frame:source())
  then
    return Future.resolve(publication(view, cached, first, last, revision))
  end
  if view._filetree_pending then
    return view._filetree_pending:map(function()
      return false
    end)
  end
  local pending = async.run(native:annotations(frame, first + 1, last))
  view._filetree_pending = pending
  return pending:map(function(value)
    if view._filetree_pending == pending then
      view._filetree_pending = nil
    end
    if view._closed then
      return false
    end
    if value.kind == "Rejected" then
      if value.error.code == "Busy" then
        return false
      end
      if value.error.code ~= "Stale" then
        async.report(value.error)
      end
      return publication(view, nil, first, last, revision)
    end
    if value.revision ~= native:annotation_revision() then
      return false
    end
    return publication(view, value, first, last, revision)
  end)
end

---@param view                          ux.filetree.View
---@return nil
function M.attach(view)
  views[view.bufnr] = view
  local on_frame = view._options.on_frame
  view._options.on_frame = function(frame)
    -- Loading-only source updates keep the same resource facts. Rebind before redraw;
    -- a fresh annotation query can then replace the still-valid viewport without a blank frame.
    if view._filetree_annotations then
      local header, source = frame:header(), frame:source()
      if same_rows(view, header, source) then
        view._filetree_annotations.frame = frame:id()
        view._filetree_annotation_data = header.data_revision
        view._filetree_annotation_source = source
      else
        view._filetree_annotations, view._filetree_annotation_source = nil, nil
      end
    end
    if on_frame then
      on_frame(frame)
    end
  end
  local detach = view.detach
  ---@param self                        ux.filetree.View
  ---@return nil
  view.detach = function(self)
    views[self.bufnr] = nil
    self._filetree_annotations, self._filetree_pending = nil, nil
    self._filetree_annotation_source = nil
    detach(self)
  end
end

---@param owner                         ux.treeview.Data
---@param native                        yoz.ux.filetree.Data
---@return boolean
function M.poll(owner, native)
  local revision = native:annotation_revision()
  if revision == "0" then
    return false
  end
  local busy = false
  for view in pairs(owner._views) do
    local cache = view._decorations
    if views[view.bufnr] == view and not view._closed and view._frame and cache then
      ---@cast view ux.filetree.View
      local frame = view._frame
      local header = view._header
      local key = table.concat({ header.data_revision, header.layout_revision, cache.first, cache.last, revision }, ":")
      if view._filetree_pending then
        busy = true
      elseif view._filetree_annotation_key ~= key and cache.last > cache.first then
        view._filetree_annotation_key = key
        local pending = async.run(native:annotations(frame, cache.first + 1, cache.last))
        view._filetree_pending = pending
        busy = true
        pending:then_(function(value)
          if view._closed then
            return
          end
          if view._filetree_pending == pending then
            view._filetree_pending = nil
          end
          if view._filetree_annotation_key ~= key then
            return
          end
          local current = view._decorations
          if not current or current.first ~= cache.first or current.last ~= cache.last then
            view._filetree_annotation_key = nil
            return
          end
          if value.kind == "Rejected" then
            if value.error.code == "Busy" then
              view._filetree_annotation_key = nil
            elseif value.error.code == "Stale" then
              -- A retained frame cannot recover until its source changes.
              view._filetree_annotations = nil
              view._filetree_annotation_source = nil
              view:_redraw()
            else
              async.report(value.error)
            end
          elseif
            view._frame
            and header.data_revision == view._header.data_revision
            and header.layout_revision == view._header.layout_revision
            and value.revision == native:annotation_revision()
          then
            value.frame = view._frame:id()
            view._filetree_annotations = value
            view._filetree_annotation_data = header.data_revision
            view._filetree_annotation_layout = header.layout_revision
            view._filetree_annotation_source = frame:source()
            view:_redraw()
          else
            view._filetree_annotation_key = nil
          end
        end)
      end
    end
  end
  return busy
end

---@param value                         ux.filetree.IAnnotation
---@return table[]
local function chunks(value)
  local result = {}
  for _, entry in ipairs({
    { 1, "E", "DiagnosticError" },
    { 2, "W", "DiagnosticWarn" },
    { 4, "H", "DiagnosticHint" },
    { 3, "I", "DiagnosticInfo" },
  }) do
    if value.diagnostics[entry[1]] > 0 then
      result[#result + 1] = { " " .. entry[2] .. ":" .. value.diagnostics[entry[1]], entry[3] }
      if #result == 2 then
        break
      end
    end
  end
  local git = {}
  -- Mixed rows keep working-tree colors; staging changes the color, not the status letter.
  local staged_highlight = value.staged and not value.unstaged and "m_ft_git_staged" or nil
  local labels = {
    { 1, "!", "m_ft_git_unmerged" },
    { 2, "", "m_ft_git_untracked" },
    { 4, "M", staged_highlight or "m_ft_git_change" },
    { 8, "D", "m_ft_git_delete" },
    { 16, "A", staged_highlight or "m_ft_git_add" },
    { 32, "R", staged_highlight or "m_ft_git_rename" },
    { 64, "C", staged_highlight or "m_ft_git_rename" },
    { 128, "T", staged_highlight or "m_ft_git_change" },
    { 256, "", "m_ft_git_ignored" },
  }
  for _, entry in ipairs(labels) do
    if bit.band(value.git, entry[1]) ~= 0 then
      git[#git + 1] = { entry[2], entry[3] }
    end
  end
  if #git > 0 then
    result[#result + 1] = { " " }
    for _, chunk in ipairs(git) do
      result[#result + 1] = chunk
    end
  end
  return result
end

vim.api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, winnr, bufnr)
    local view = views[bufnr]
    local cache = view and view._filetree_annotations
    return view ~= nil
      and not view._closed
      and not view._desynced
      and not view._publishing
      and view.winnr == winnr
      and view._frame ~= nil
      and cache ~= nil
      and cache.frame == view._frame:id()
  end,
  on_line = function(_, _, bufnr, row)
    local view = views[bufnr]
    local cache = view and view._filetree_annotations
    if not cache or view._closed or not view._frame or cache.frame ~= view._frame:id() then
      return
    end
    local value = cache.rows[row - cache.first + 2]
    if value then
      local text = chunks(value)
      if #text > 0 then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
          ephemeral = true,
          virt_text = text,
          virt_text_pos = "right_align",
          hl_mode = "combine",
          priority = 90,
        })
      end
    end
  end,
})

return M
