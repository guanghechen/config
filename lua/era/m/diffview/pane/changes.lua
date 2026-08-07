---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.changes" ---@type string

local view_filetree = require("era.view.filetree")
local config = require("era.m.diffview.config")

---Changes pane for workspace view.
---Renders staged + unstaged file entries as dual trees with separator.
---@class era.m.diffview.pane.changes
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local NS = config.NS

----------------------------------------------------------------------------------------------------
-- Buffer creation
----------------------------------------------------------------------------------------------------

---Create a changes panel buffer
---@return integer                      bufnr
function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  for opt, val in pairs(config.BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", config.FT.CHANGES, { buf = bufnr })

  return bufnr
end

----------------------------------------------------------------------------------------------------
-- Window options
----------------------------------------------------------------------------------------------------

---Generate winhighlight string for changes panel
---@return string
local function gen_winhl()
  local parts = {
    "CursorLine:m_dv_cursorline",
    "EndOfBuffer:m_dv_eob",
    "FoldColumn:m_dv_normal",
    "Normal:m_dv_normal",
    "SignColumn:m_dv_normal",
    "WinSeparator:m_dv_winsep",
  }
  return table.concat(parts, ",")
end

---Apply panel window options
---@param winnr                         integer
function M.apply_winopts(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  for opt, val in pairs(config.WINOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { win = winnr, scope = "local" })
  end
  vim.api.nvim_set_option_value("winhighlight", gen_winhl(), { win = winnr, scope = "local" })
end

----------------------------------------------------------------------------------------------------
-- Custom renderers for changes filetree
----------------------------------------------------------------------------------------------------

---Create directory renderer with collapse state
---@param stage_type                    stl.m.diffview.StageTypeEnum
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@param collapsed_dirs                table<string, boolean>
---@return era.view.filetree.IDirectoryRenderer
local function create_directory_renderer(stage_type, line_map, collapsed_dirs)
  ---@param node                        era.view.filetree.ITreeNode
  ---@param lnum                        integer
  ---@param indent                      string
  ---@return string, stl.t.IHighlight[]
  return function(node, lnum, indent)
    local is_collapsed = collapsed_dirs[node.filepath] == true ---@type boolean
    local icon = is_collapsed and stl.icon.filetype.Folder or stl.icon.filetype.FolderOpen ---@type string
    local line = indent .. icon .. " " .. node.name ---@type string

    local col = 0 ---@type integer
    local highlights = {} ---@type stl.t.IHighlight[]

    -- Highlight indent
    highlights[#highlights + 1] = {
      hlname = "f_utw_indent",
      lnum = lnum,
      coll = col,
      colr = #indent,
    }
    col = #indent

    -- Highlight icon
    highlights[#highlights + 1] = {
      hlname = "m_ft_dirname",
      lnum = lnum,
      coll = col,
      colr = col + #icon,
    }
    col = col + #icon + 1

    -- Highlight name
    highlights[#highlights + 1] = {
      hlname = "m_ft_dirname",
      lnum = lnum,
      coll = col,
      colr = #line,
    }

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "directory",
      entry = nil,
      stage_type = stage_type,
      uuid = node.filepath,
    }

    return line, highlights
  end
end

---Create file renderer
---@param stage_type                    stl.m.diffview.StageTypeEnum
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@return era.view.filetree.IFileRenderer
local function create_file_renderer(stage_type, line_map)
  ---@param node                        era.view.filetree.ITreeNode
  ---@param lnum                        integer
  ---@param indent                      string
  ---@return string, stl.t.IHighlight[]
  return function(node, lnum, indent)
    local entry = node.data ---@type era.m.diffview.IFileEntry|nil
    local fileicon, fileicon_hln = stl.fileicon.get_file_icon(node.name)
    local line = indent .. fileicon .. " " .. node.name ---@type string

    local col = 0 ---@type integer
    local highlights = {} ---@type stl.t.IHighlight[]

    -- Highlight indent
    highlights[#highlights + 1] = {
      hlname = "f_utw_indent",
      lnum = lnum,
      coll = col,
      colr = #indent,
    }
    col = #indent

    -- Highlight file icon
    highlights[#highlights + 1] = {
      hlname = fileicon_hln,
      lnum = lnum,
      coll = col,
      colr = col + #fileicon,
    }
    col = col + #fileicon + 1

    -- Highlight filename
    highlights[#highlights + 1] = {
      hlname = "m_dv_ft_filename",
      lnum = lnum,
      coll = col,
      colr = col + #node.name,
    }

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "file",
      entry = entry,
      stage_type = stage_type,
      uuid = node.filepath,
    }

    return line, highlights
  end
end

----------------------------------------------------------------------------------------------------
-- Section rendering helpers
----------------------------------------------------------------------------------------------------

---Get entries in filetree traversal order.
---@param entries                       era.m.diffview.IFileEntry[]
---@return era.m.diffview.IFileEntry[]
local function get_sorted_section_entries(entries)
  local items = {} ---@type era.view.filetree.IFileItem[]
  for _, entry in ipairs(entries) do
    items[#items + 1] = {
      filepath = entry.filepath,
      data = entry,
    }
  end

  local sorted_entries = {} ---@type era.m.diffview.IFileEntry[]
  for _, item in ipairs(view_filetree.get_sorted_files(items)) do
    sorted_entries[#sorted_entries + 1] = item.data --[[@as era.m.diffview.IFileEntry]]
  end
  return sorted_entries
end

---Get entries in the same order used by the rendered changes panel.
---@param entries                       era.m.diffview.IFileEntry[]
---@return era.m.diffview.IFileEntry[]
function M.get_entries_in_render_order(entries)
  local staged = {} ---@type era.m.diffview.IFileEntry[]
  local unstaged = {} ---@type era.m.diffview.IFileEntry[]

  for _, entry in ipairs(entries) do
    if entry.stage_type == "staged" then
      staged[#staged + 1] = entry
    else
      unstaged[#unstaged + 1] = entry
    end
  end

  local ordered = get_sorted_section_entries(staged)
  vim.list_extend(ordered, get_sorted_section_entries(unstaged))
  return ordered
end

---Render a section (staged or unstaged) as tree
---@param entries                       era.m.diffview.IFileEntry[]
---@param stage_type                    stl.m.diffview.StageTypeEnum
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@param collapsed_dirs                table<string, boolean>
---@param foldempty                     boolean
local function render_section_tree(entries, stage_type, lines, highlights, line_map, collapsed_dirs, foldempty)
  if #entries == 0 then
    return
  end

  -- Convert entries to file items
  local items = {} ---@type era.view.filetree.IFileItem[]
  for _, entry in ipairs(entries) do
    items[#items + 1] = {
      filepath = entry.filepath,
      data = entry,
    }
  end

  local result = view_filetree.render(items, {
    foldempty = foldempty,
    start_lnum = #lines,
    render_directory = create_directory_renderer(stage_type, line_map, collapsed_dirs),
    render_file = create_file_renderer(stage_type, line_map),
    is_collapsed = function(node)
      return collapsed_dirs[node.filepath] == true
    end,
  })

  vim.list_extend(lines, result.lines)
  vim.list_extend(highlights, result.highlights)
end

---Render a section (staged or unstaged) as flat list
---@param entries                       era.m.diffview.IFileEntry[]
---@param stage_type                    stl.m.diffview.StageTypeEnum
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
local function render_section_list(entries, stage_type, lines, highlights, line_map)
  for _, entry in ipairs(get_sorted_section_entries(entries)) do
    local lnum = #lines ---@type integer
    local col = 0 ---@type integer

    local filepath = entry.filepath ---@type string
    local basename = vim.fn.fnamemodify(filepath, ":t") ---@type string

    local fileicon, fileicon_hln = stl.fileicon.get_file_icon(basename)
    local indent = "  " ---@type string
    local line = indent .. fileicon .. " " .. filepath ---@type string

    -- Highlight indent
    highlights[#highlights + 1] = {
      hlname = "f_utw_indent",
      lnum = lnum,
      coll = col,
      colr = #indent,
    }
    col = #indent

    -- Highlight file icon
    highlights[#highlights + 1] = {
      hlname = fileicon_hln,
      lnum = lnum,
      coll = col,
      colr = col + #fileicon,
    }
    col = col + #fileicon + 1

    -- Highlight filepath
    highlights[#highlights + 1] = {
      hlname = "m_dv_ft_filename",
      lnum = lnum,
      coll = col,
      colr = col + #filepath,
    }

    lines[#lines + 1] = line
    line_map[#line_map + 1] = {
      type = "file",
      entry = entry,
      stage_type = stage_type,
      uuid = filepath,
    }
  end
end

----------------------------------------------------------------------------------------------------
-- Changes panel rendering
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.pane.changes.IRenderOpts
---@field public viewtype               stl.m.diffview.PanelViewTypeEnum|nil
---@field public foldempty              boolean|nil
---@field public collapsed_dirs         table<string, boolean>|nil
---@field public panel_width            integer|nil

---Render changes panel with staged and unstaged files
---@param entries                       era.m.diffview.IFileEntry[]
---@param opts                          era.m.diffview.pane.changes.IRenderOpts|nil
---@return era.m.diffview.IRenderResult
function M.render(entries, opts)
  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local line_map = {} ---@type era.m.diffview.IFiletreeLineMap[]

  -- Get options
  local viewtype = (opts and opts.viewtype) or dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
  local foldempty_opt = opts and opts.foldempty
  local foldempty = foldempty_opt ~= nil and foldempty_opt or dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
  local collapsed_dirs = (opts and opts.collapsed_dirs) or {} ---@type table<string, boolean>
  local panel_width = (opts and opts.panel_width) or config.FILETREE_WIDTH ---@type integer

  -- Separate staged and unstaged
  local staged = {} ---@type era.m.diffview.IFileEntry[]
  local unstaged = {} ---@type era.m.diffview.IFileEntry[]

  for _, entry in ipairs(entries) do
    if entry.stage_type == "staged" then
      staged[#staged + 1] = entry
    else
      unstaged[#unstaged + 1] = entry
    end
  end

  -- Render staged section
  local staged_header = string.format("Staged (%d)", #staged)
  lines[#lines + 1] = staged_header
  highlights[#highlights + 1] = {
    hlname = "m_dv_ft_header",
    lnum = #lines - 1,
    coll = 0,
    colr = #staged_header,
  }
  line_map[#line_map + 1] = { type = "header", entry = nil, stage_type = "staged", uuid = nil }

  if viewtype == "list" then
    render_section_list(staged, "staged", lines, highlights, line_map)
  else
    render_section_tree(staged, "staged", lines, highlights, line_map, collapsed_dirs, foldempty)
  end

  -- Separator
  if #staged > 0 or #unstaged > 0 then
    local sep_width = math.max(0, panel_width) ---@type integer
    local sep_line = string.rep(config.ICONS.SEPARATOR, sep_width)
    lines[#lines + 1] = sep_line
    highlights[#highlights + 1] = {
      hlname = "m_dv_ft_separator",
      lnum = #lines - 1,
      coll = 0,
      colr = #sep_line,
    }
    line_map[#line_map + 1] = { type = "separator", entry = nil, stage_type = nil, uuid = nil }
  end

  -- Render unstaged section
  local unstaged_header = string.format("Unstaged (%d)", #unstaged)
  lines[#lines + 1] = unstaged_header
  highlights[#highlights + 1] = {
    hlname = "m_dv_ft_header",
    lnum = #lines - 1,
    coll = 0,
    colr = #unstaged_header,
  }
  line_map[#line_map + 1] = { type = "header", entry = nil, stage_type = "unstaged", uuid = nil }

  if viewtype == "list" then
    render_section_list(unstaged, "unstaged", lines, highlights, line_map)
  else
    render_section_tree(unstaged, "unstaged", lines, highlights, line_map, collapsed_dirs, foldempty)
  end

  return {
    lines = lines,
    highlights = highlights,
    line_map = line_map,
  }
end

---Apply render result to buffer
---@param bufnr                         integer
---@param result                        era.m.diffview.IRenderResult
function M.apply_to_buffer(bufnr, result)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Set lines
  local was_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)
  vim.api.nvim_set_option_value("modifiable", was_modifiable, { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  for _, hl in ipairs(result.highlights) do
    vim.hl.range(bufnr, NS, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end

  -- Store line_map
  M.set_line_map(bufnr, result.line_map)
end

----------------------------------------------------------------------------------------------------
-- Line map management
----------------------------------------------------------------------------------------------------

---Get line map for changes buffer
---@param bufnr                         integer
---@return era.m.diffview.IFiletreeLineMap[]|nil
function M.get_line_map(bufnr)
  return vim.b[bufnr].diffview_changes_line_map
end

---Set line map for changes buffer
---@param bufnr                         integer
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
function M.set_line_map(bufnr, line_map)
  vim.b[bufnr].diffview_changes_line_map = line_map
end

---Get collapsed dirs map for changes buffer
---@param bufnr                         integer
---@return table<string, boolean>|nil
function M.get_collapsed_dirs(bufnr)
  return vim.b[bufnr].diffview_changes_collapsed_dirs
end

---Set collapsed dirs map for changes buffer
---@param bufnr                         integer
---@param collapsed_dirs                table<string, boolean>
function M.set_collapsed_dirs(bufnr, collapsed_dirs)
  vim.b[bufnr].diffview_changes_collapsed_dirs = collapsed_dirs
end

---Get entry at cursor position
---@param bufnr                         integer
---@param lnum                          integer                         1-indexed line number
---@return era.m.diffview.IFileEntry|nil
function M.get_entry_at_line(bufnr, lnum)
  local line_map = M.get_line_map(bufnr)
  if not line_map or lnum < 1 or lnum > #line_map then
    return nil
  end

  local item = line_map[lnum]
  if item and item.type == "file" and item.entry then
    return item.entry
  end
  return nil
end

---Get line map item at cursor position
---@param bufnr                         integer
---@param lnum                          integer                         1-indexed line number
---@return era.m.diffview.IFiletreeLineMap|nil
function M.get_item_at_line(bufnr, lnum)
  local line_map = M.get_line_map(bufnr)
  if not line_map or lnum < 1 or lnum > #line_map then
    return nil
  end
  return line_map[lnum]
end

---Find line number for entry
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@param entry                         era.m.diffview.IFileEntry
---@return integer|nil                  1-indexed line number
function M.find_entry_line(line_map, entry)
  for i, item in ipairs(line_map) do
    if
      item.type == "file"
      and item.entry
      and item.entry.filepath == entry.filepath
      and item.entry.stage_type == entry.stage_type
    then
      return i
    end
  end
  return nil
end

---Toggle directory collapse state
---@param bufnr                         integer
---@param lnum                          integer                         1-indexed line number
---@return boolean                      True if toggled a directory
function M.toggle_collapse(bufnr, lnum)
  local item = M.get_item_at_line(bufnr, lnum)
  if not item or item.type ~= "directory" then
    return false
  end

  local uuid = item.uuid ---@type string|nil
  if not uuid then
    return false
  end

  local collapsed_dirs = M.get_collapsed_dirs(bufnr) or {}
  collapsed_dirs[uuid] = not collapsed_dirs[uuid]
  M.set_collapsed_dirs(bufnr, collapsed_dirs)
  return true
end

---Check if item at line is a directory
---@param bufnr                         integer
---@param lnum                          integer                         1-indexed line number
---@return boolean
function M.is_directory(bufnr, lnum)
  local item = M.get_item_at_line(bufnr, lnum)
  return item ~= nil and item.type == "directory"
end

return M
