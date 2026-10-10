---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.view" ---@type string

local namespace = vim.api.nvim_create_namespace("era.explorer")
local views = {} ---@type table<integer, table>
local Future = require("stl.c.future")
local icons = require("era.m.explorer.icons")
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
  entry.generation = entry.generation + 1
  entry.key, entry.cache = nil, nil
  entry.rows, entry.icons, entry.links = nil, nil, nil
end

---@param session                       era.m.explorer.Session
---@param view                          ux.filetree.View
---@return nil
function M.attach(session, view)
  local entry = { view = view, session = session, generation = 0 }
  views[view.bufnr] = entry
  local prepare_frame = view._options.prepare_frame
  view._options.prepare_frame = function(current, frame, first, last, rows)
    local generation = entry.generation
    local prepared_frame = prepare_frame(current, frame, first, last, rows)
    local reuse_icons = entry.rows == rows and entry.cache and entry.first == first and entry.last == last
    local prepared_icons = reuse_icons
        and Future.resolve({ cache = entry.cache, icons = entry.icons, links = entry.links })
      or icons
        .prepare(session, frame, rows, entry.cache, function()
          return not view._closed and entry.generation == generation
        end)
        :map(function(value)
          if value and not view._closed and entry.generation == generation then
            -- Pure icon values remain reusable if a newer frame supersedes this preparation.
            -- Displayed rows and glyphs still change only in the publication callback.
            entry.cache = value.cache
          end
          return value
        end)
    return Future.all({
      prepared_frame,
      prepared_icons,
    }):map(function(prepared)
      if not prepared[1] or not prepared[2] or view._closed or entry.generation ~= generation then
        return false
      end
      return function(published)
        local unchanged = prepared[1](published)
        local value = prepared[2]
        entry.key, entry.first, entry.last, entry.rows = published:id(), first, last, rows
        entry.icons, entry.links = value.icons, value.links
        return unchanged and reuse_icons == true
      end
    end)
  end
  local on_frame = view._options.on_frame
  view._options.on_frame = function(frame)
    local header = frame:header()
    if header.row_count == 0 then
      clear_cache(entry)
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

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("ExplorerIcons", { clear = true }),
  callback = function()
    for _, entry in pairs(views) do
      entry.generation, entry.cache = entry.generation + 1, nil
      entry.view:refresh_decorations()
    end
  end,
})

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
      return false
    end
    if entry.key ~= frame:id() or not entry.rows then
      return false
    end
    local header = view._header
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
  on_range = function(_, winnr, bufnr, first, _, last, end_col)
    local entry = views[bufnr]
    if not entry or not entry.rows then
      return
    end
    local view, rows = entry.view, entry.rows
    if view.winnr ~= winnr or view._closed or view._publishing or view._desynced then
      return false
    end
    local frame = view:frame()
    if not frame or entry.key ~= frame:id() then
      return false
    end
    first, last = math.max(first, entry.first), math.min(last + (end_col > 0 and 1 or 0), entry.last)
    local annotations = view._filetree_annotations
    if annotations and annotations.frame ~= frame:id() then
      annotations = nil
    end
    local depth = view._header.mode == "tree" and 1 or 0
    local indent, slots = view._context.indent, view._context.slots
    for row = first, last - 1 do
      local index = row - entry.first + 1
      local start = (rows.depths[index] + depth) * indent
      local value = annotations and annotations.rows[row - annotations.first + 2] or nil
      local git_group = git_highlight(value)
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row, start + slots, {
        ephemeral = true,
        end_col = start + slots + #rows.labels[index],
        hl_group = highlight(value, git_group),
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
          -- Nerd Font glyphs can overhang into the padding cell.
          end_col = start + slots,
          hl_group = group,
          virt_text = { { icon[1], group } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
          priority = 121,
        })
      end
    end
  end,
})

return M
