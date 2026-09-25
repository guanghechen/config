---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.view" ---@type string

local namespace = vim.api.nvim_create_namespace("era.explorer")
local views = {} ---@type table<integer, table>
local fileicon = require("stl.fileicon")
local Ignore = require("era.m.git.ignore")
-- Keep the glyph's overhang and trailing cell on the same row background.
local LINK_MARKER = "  " ---@type string
local M = {}

---@param value                         ?ux.filetree.IAnnotation
---@return string|nil
local function git_highlight(value)
  if not value then
    return nil
  end
  if bit.band(value.git, 256) ~= 0 then
    return "m_ft_git_ignored"
  end
  if bit.band(value.git, 1) ~= 0 then
    return "m_ft_git_unmerged"
  end
  if bit.band(value.git, 8) ~= 0 then
    return "m_ft_git_delete"
  end
  if bit.band(value.git, 2) ~= 0 then
    return "m_ft_git_untracked"
  end
  if value.unstaged then
    return "m_ft_git_unstaged"
  end
  if value.staged then
    return "m_ft_git_staged"
  end
  if bit.band(value.git, 16) ~= 0 then
    return "m_ft_git_add"
  end
  if bit.band(value.git, 96) ~= 0 then
    return "m_ft_git_rename"
  end
  if bit.band(value.git, 132) ~= 0 then
    return "m_ft_git_change"
  end
  return nil
end

---@param value                         ?ux.filetree.IAnnotation
---@param git_group                     ?string
---@return string
local function highlight(value, git_group)
  if not value then
    return "m_ft_filename"
  end
  if bit.band(value.git, 256) ~= 0 then
    return "m_ex_ignored"
  end
  if value.diagnostics[1] > 0 then
    return "DiagnosticError"
  end
  if value.diagnostics[2] > 0 then
    return "DiagnosticWarn"
  end
  return git_group or "m_ft_filename"
end

---@param entry                         table
---@return nil
local function clear_cache(entry)
  entry.key, entry.source, entry.icon_cache = nil, nil, nil
  entry.rows, entry.icons, entry.links = nil, nil, nil
end

---@param session                       era.m.explorer.Session
---@param view                          ux.filetree.View
---@return nil
function M.attach(session, view)
  local entry = { view = view, session = session }
  views[view.bufnr] = entry
  local on_frame = view._options.on_frame
  view._options.on_frame = function(frame)
    local header = frame:header()
    if header.row_count == 0 then
      clear_cache(entry)
    elseif entry.source and entry.data_revision ~= header.data_revision then
      local source = frame:source()
      if entry.source:same_content(source) then
        entry.source = source
      else
        clear_cache(entry)
      end
    end
    if on_frame then
      on_frame(frame)
    end
  end
  local detach = view.detach
  view.detach = function(current)
    views[current.bufnr] = nil
    clear_cache(entry)
    detach(current)
  end
end

vim.api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, winnr, bufnr, first, last)
    local entry = views[bufnr]
    local view = entry and entry.view
    if not view or view.winnr ~= winnr or view._closed or view._publishing or view._desynced then
      return false
    end
    local frame = view:frame()
    if not frame then
      return false
    end
    first, last = math.max(0, first), math.min(last + 1, frame:header().row_count)
    if first >= last then
      clear_cache(entry)
      return false
    end
    local header = view._header
    local key = frame:id() .. ":" .. first .. ":" .. last
    if entry.key ~= key then
      local prepared = view._decorations
      local rows = prepared
          and prepared.frame == frame:id()
          and prepared.first == first
          and prepared.last == last
          and prepared.rows
        or frame:rows(first + 1, last)
      local source = frame:source()
      local same_content = entry.data_revision == header.data_revision
        or entry.source ~= nil and entry.source:same_content(source)
      local previous = same_content and entry.icon_cache or {}
      local icons, links, cached = {}, {}, {}
      for index, node in ipairs(rows.ids) do
        local value = previous[node]
        -- Expanded directory glyphs also depend on loading completeness.
        if entry.data_revision ~= header.data_revision and rows.can_expand[index] and rows.expanded[index] then
          value = nil
        end
        if not value or value.expanded ~= rows.expanded[index] then
          local info = entry.session.data:inspect(source, node):info()
          local icon, group
          if info.directory then
            local fallback
            icon, group, fallback = fileicon.get_directory_icon(info.label)
            if fallback then
              icon, group = stl.icon.filetype.Folder, "m_ft_dirname"
            end
            if rows.expanded[index] then
              local node = source:node(node)
              icon = node.completeness == "complete" and node.child_count == 0 and stl.icon.filetype.FolderEmptyOpen
                or stl.icon.filetype.FolderOpen
            end
          else
            icon, group = fileicon.get_file_icon(info.label)
          end
          value = { expanded = rows.expanded[index], icon = { icon, group }, link = info.kind == "link" }
        end
        icons[index], links[index], cached[node] = value.icon, value.link, value
      end
      entry.key, entry.first, entry.last, entry.rows, entry.icons = key, first, last, rows, icons
      entry.links = links
      -- Keep only the current viewport; scrolling can reuse its overlapping rows.
      entry.data_revision, entry.source, entry.icon_cache = header.data_revision, source, cached
    end
    local visible_key =
      table.concat({ header.data_revision, header.layout_revision, first, last, Ignore.o_invalidated:snapshot() }, ":")
    if entry.visible_key ~= visible_key then
      entry.visible_key = visible_key
      vim.schedule(function()
        local current = view:frame()
        if
          not view._closed
          and current
          and entry.visible_key == visible_key
          and view._header.data_revision == header.data_revision
          and view._header.layout_revision == header.layout_revision
          and entry.session._subscriptions
        then
          entry.session._subscriptions:visible(current, first + 1, last):catch(entry.session.report)
        end
      end)
    end
    return true
  end,
  on_line = function(_, _, bufnr, row)
    local entry = views[bufnr]
    if not entry or not entry.rows or row < entry.first or row >= entry.last then
      return
    end
    local view, rows = entry.view, entry.rows
    local index = row - entry.first + 1
    local start = (rows.depths[index] + (view._header.mode == "tree" and 1 or 0)) * view._context.indent
    local annotations = view._filetree_annotations
    local value = annotations
        and annotations.frame == view:frame():id()
        and annotations.rows[row - annotations.first + 2]
      or nil
    local git_group = git_highlight(value)
    local label = highlight(value, git_group)
    vim.api.nvim_buf_set_extmark(bufnr, namespace, row, start + view._context.slots, {
      ephemeral = true,
      end_col = start + view._context.slots + #rows.labels[index],
      hl_group = label,
      priority = 100,
    })
    if entry.links[index] then
      local group = git_group and git_group:gsub("^m_ft_git_", "m_ex_symlink_") or "m_ex_symlink"
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
        ephemeral = true,
        virt_text = { { LINK_MARKER, group } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
        -- Right-aligned marks grow leftward by priority; the link follows status.
        priority = 80,
      })
    end
    if rows.load_states[index] ~= "loading" and rows.load_states[index] ~= "error" then
      local icon = entry.icons[index]
      local group = value and bit.band(value.git, 256) ~= 0 and "m_ex_ignored" or icon[2]
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row, start, {
        ephemeral = true,
        virt_text = { { icon[1], group } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
        priority = 121,
      })
    end
  end,
})

return M
