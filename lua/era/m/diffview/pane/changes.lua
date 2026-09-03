---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.changes" ---@type string

local view_filetree = require("era.view.filetree")
local config = require("era.m.diffview.config")
local util = require("era.m.diffview.util")

---Changes pane for workspace view.
---Renders one staged or unstaged file tree; the workspace composes both sibling panes.
---@class era.m.diffview.pane.changes
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local NS = config.NS

---@class era.m.diffview.pane.changes.IRenderState
---@field public line_map               era.m.diffview.IFiletreeLineMap[]
---@field public navigation             era.m.diffview.ITreeNavigation

local EMPTY_NAVIGATION = {
  parent_lnums = {},
  last_child_lnums = {},
  root_last_lnum = 0,
} ---@type era.m.diffview.ITreeNavigation

-- Keep layout-sized render state in Lua. Reading nested arrays from vim.b copies them on every access.
local RENDER_STATE_BY_BUFNR = {} ---@type table<integer, era.m.diffview.pane.changes.IRenderState>
local RENDER_STATE_CLEANUP_REGISTERED = {} ---@type table<integer, true>

---@param bufnr                         integer
local function ensure_render_state_cleanup(bufnr)
  if RENDER_STATE_CLEANUP_REGISTERED[bufnr] then
    return
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    desc = "diffview: release changes render state",
    callback = function()
      RENDER_STATE_BY_BUFNR[bufnr] = nil
      RENDER_STATE_CLEANUP_REGISTERED[bufnr] = nil
    end,
  })
  RENDER_STATE_CLEANUP_REGISTERED[bufnr] = true
end

---@class era.m.diffview.pane.changes.IOverlayEntry
---@field public lnum                   integer
---@field public entry                  era.m.diffview.IFileEntry

---@param value                         integer|nil
---@param prefix                        string
---@return string
local function format_stat(value, prefix)
  if value == nil or value <= 0 then
    return ""
  end
  return prefix .. tostring(value)
end

---@param text                          string
---@param width                         integer
---@return string
local function pad_left(text, width)
  return string.rep(" ", math.max(0, width - #text)) .. text
end

---Keep Git paths semantic in line_map/actions while making buffer text single-line and printable.
---@param path                          string
---@return string
local function format_display_path(path)
  return vim.fn.strtrans(path)
end

---@class era.m.diffview.pane.changes.IMetadataWidths
---@field public insertion              integer
---@field public deletion               integer

---Measure fixed INS / DEL columns shared by the sibling Changes panes.
---@param entries                       era.m.diffview.IFileEntry[]
---@return era.m.diffview.pane.changes.IMetadataWidths
function M.measure_metadata(entries)
  local widths = { insertion = 0, deletion = 0 } ---@type era.m.diffview.pane.changes.IMetadataWidths
  for _, entry in ipairs(entries) do
    widths.insertion = math.max(widths.insertion, #format_stat(entry.insertions, "+"))
    widths.deletion = math.max(widths.deletion, #format_stat(entry.deletions, "-"))
  end
  return widths
end

---Build right-aligned metadata using Changes-wide fixed INS / DEL / S columns.
---@param items                         era.m.diffview.pane.changes.IOverlayEntry[]
---@param panel_width                   integer
---@param widths                        era.m.diffview.pane.changes.IMetadataWidths
---@return era.m.diffview.IOverlay[]
local function build_overlays(items, panel_width, widths)
  local insertion_width = widths.insertion
  local deletion_width = widths.deletion
  local overlays = {} ---@type era.m.diffview.IOverlay[]
  for _, item in ipairs(items) do
    local entry = item.entry
    local insertion = format_stat(entry.insertions, "+") ---@type string
    local deletion = format_stat(entry.deletions, "-") ---@type string
    local status = entry.status ~= "" and entry.status or "?" ---@type string
    local virt_text = { { " ", "m_dv_ft_filename" } } ---@type [string, string][]

    if insertion_width > 0 then
      virt_text[#virt_text + 1] = {
        pad_left(insertion, insertion_width),
        insertion ~= "" and "m_dv_ft_insertions" or "m_dv_ft_filename",
      }
    end
    if insertion_width > 0 and deletion_width > 0 then
      virt_text[#virt_text + 1] = { " ", "m_dv_ft_filename" }
    end
    if deletion_width > 0 then
      virt_text[#virt_text + 1] = {
        pad_left(deletion, deletion_width),
        deletion ~= "" and "m_dv_ft_deletions" or "m_dv_ft_filename",
      }
    end
    if insertion_width > 0 or deletion_width > 0 then
      virt_text[#virt_text + 1] = { " ", "m_dv_ft_filename" }
    end
    virt_text[#virt_text + 1] = { status, util.get_status_hlgroup(status) }

    local metadata_width = 0 ---@type integer
    for _, segment in ipairs(virt_text) do
      metadata_width = metadata_width + #segment[1]
    end
    if metadata_width > panel_width then
      virt_text = {
        { panel_width > 1 and " " or "", "m_dv_ft_filename" },
        { status, util.get_status_hlgroup(status) },
      }
    end

    overlays[#overlays + 1] = {
      lnum = item.lnum,
      virt_text = virt_text,
    }
  end

  return overlays
end

----------------------------------------------------------------------------------------------------
-- Buffer creation
----------------------------------------------------------------------------------------------------

---Create a changes panel buffer.
---@param stage_type                    stl.m.diffview.StageTypeEnum
---@return integer                      bufnr
function M.create_buffer(stage_type)
  local bufnr = vim.api.nvim_create_buf(false, true)

  for opt, val in pairs(config.BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", config.FT.CHANGES, { buf = bufnr })
  vim.b[bufnr].diffview_changes_stage_type = stage_type

  return bufnr
end

---Get the stage rendered by a Changes buffer.
---@param bufnr                         integer
---@return stl.m.diffview.StageTypeEnum|nil
function M.get_stage_type(bufnr)
  return vim.b[bufnr].diffview_changes_stage_type
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
  vim.api.nvim_set_option_value("winfixwidth", true, { win = winnr, scope = "local" })
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
    local display_name = format_display_path(node.name) ---@type string
    local line = indent .. icon .. " " .. display_name ---@type string

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
---@param overlay_entries               era.m.diffview.pane.changes.IOverlayEntry[]
---@return era.view.filetree.IFileRenderer
local function create_file_renderer(stage_type, line_map, overlay_entries)
  ---@param node                        era.view.filetree.ITreeNode
  ---@param lnum                        integer
  ---@param indent                      string
  ---@return string, stl.t.IHighlight[]
  return function(node, lnum, indent)
    local entry = node.data ---@type era.m.diffview.IFileEntry|nil
    local fileicon, fileicon_hln = stl.fileicon.get_file_icon(node.name)
    local display_name = format_display_path(node.name) ---@type string
    local line = indent .. fileicon .. " " .. display_name ---@type string
    local status_hl = entry and util.get_status_hlgroup(entry.status) or "m_dv_ft_filename" ---@type string

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
      hlname = status_hl,
      lnum = lnum,
      coll = col,
      colr = col + #display_name,
    }

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "file",
      entry = entry,
      stage_type = stage_type,
      uuid = node.filepath,
    }
    if entry then
      overlay_entries[#overlay_entries + 1] = { lnum = lnum, entry = entry }
    end

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

---Get entries in the same order used across the staged and unstaged panes.
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
---@param overlay_entries               era.m.diffview.pane.changes.IOverlayEntry[]
local function render_section_tree(
  entries,
  stage_type,
  lines,
  highlights,
  line_map,
  collapsed_dirs,
  foldempty,
  overlay_entries,
  navigation
)
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
    render_file = create_file_renderer(stage_type, line_map, overlay_entries),
    is_collapsed = function(node)
      return collapsed_dirs[node.filepath] == true
    end,
  })

  local offset = #lines ---@type integer
  for row = 1, result.layout:len() do
    local lnum = offset + row ---@type integer
    local parent_lnum = result.layout:parent_lnum(row) ---@type integer|nil
    local last_child_lnum = result.layout:last_child_lnum(row) ---@type integer|nil
    navigation.parent_lnums[lnum] = parent_lnum ~= nil and (offset + parent_lnum) or 0
    navigation.last_child_lnums[lnum] = last_child_lnum ~= nil and (offset + last_child_lnum) or 0
    if parent_lnum == nil then
      navigation.root_last_lnum = lnum
    end
  end

  vim.list_extend(lines, result.lines)
  vim.list_extend(highlights, result.highlights)
end

---Render a section (staged or unstaged) as flat list
---@param entries                       era.m.diffview.IFileEntry[]
---@param stage_type                    stl.m.diffview.StageTypeEnum
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@param overlay_entries               era.m.diffview.pane.changes.IOverlayEntry[]
local function render_section_list(entries, stage_type, lines, highlights, line_map, overlay_entries, navigation)
  for _, entry in ipairs(get_sorted_section_entries(entries)) do
    local lnum = #lines ---@type integer
    local col = 0 ---@type integer

    local filepath = entry.filepath ---@type string
    local basename = vim.fn.fnamemodify(filepath, ":t") ---@type string
    local display_filepath = format_display_path(filepath) ---@type string

    local fileicon, fileicon_hln = stl.fileicon.get_file_icon(basename)
    local status_hl = util.get_status_hlgroup(entry.status) ---@type string
    local indent = "  " ---@type string
    local line = indent .. fileicon .. " " .. display_filepath ---@type string

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
      hlname = status_hl,
      lnum = lnum,
      coll = col,
      colr = col + #display_filepath,
    }

    lines[#lines + 1] = line
    local row = #lines ---@type integer
    navigation.parent_lnums[row] = 0
    navigation.last_child_lnums[row] = 0
    navigation.root_last_lnum = row
    line_map[#line_map + 1] = {
      type = "file",
      entry = entry,
      stage_type = stage_type,
      uuid = filepath,
    }
    overlay_entries[#overlay_entries + 1] = { lnum = lnum, entry = entry }
  end
end

----------------------------------------------------------------------------------------------------
-- Changes panel rendering
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.pane.changes.IRenderOpts
---@field public stage_type             stl.m.diffview.StageTypeEnum
---@field public viewtype               stl.m.diffview.PanelViewTypeEnum|nil
---@field public foldempty              boolean|nil
---@field public collapsed_dirs         table<string, boolean>|nil
---@field public panel_width            integer|nil
---@field public metadata_widths        era.m.diffview.pane.changes.IMetadataWidths|nil

---Render one staged or unstaged Changes pane.
---@param entries                       era.m.diffview.IFileEntry[]
---@param opts                          era.m.diffview.pane.changes.IRenderOpts
---@return era.m.diffview.IRenderResult
function M.render(entries, opts)
  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local line_map = {} ---@type era.m.diffview.IFiletreeLineMap[]
  local overlay_entries = {} ---@type era.m.diffview.pane.changes.IOverlayEntry[]
  local navigation = {
    parent_lnums = {},
    last_child_lnums = {},
    root_last_lnum = 0,
  } ---@type era.m.diffview.ITreeNavigation

  -- Get options
  local stage_type = opts.stage_type
  local viewtype = opts.viewtype or dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
  local foldempty_opt = opts.foldempty
  local foldempty = foldempty_opt ---@type boolean|nil
  if foldempty == nil then
    foldempty = dot.context.diffview.flag_foldempty:snapshot()
  end
  local collapsed_dirs = opts.collapsed_dirs or {} ---@type table<string, boolean>
  local panel_width = opts.panel_width or config.FILETREE_WIDTH ---@type integer
  local section_entries = {} ---@type era.m.diffview.IFileEntry[]

  for _, entry in ipairs(entries) do
    if entry.stage_type == stage_type then
      section_entries[#section_entries + 1] = entry
    end
  end

  if viewtype == "list" then
    render_section_list(section_entries, stage_type, lines, highlights, line_map, overlay_entries, navigation)
  else
    render_section_tree(
      section_entries,
      stage_type,
      lines,
      highlights,
      line_map,
      collapsed_dirs,
      foldempty,
      overlay_entries,
      navigation
    )
  end

  return {
    lines = lines,
    highlights = highlights,
    line_map = line_map,
    overlays = build_overlays(overlay_entries, panel_width, opts.metadata_widths or M.measure_metadata(entries)),
    navigation = navigation,
  }
end

---Apply render result to buffer
---@param bufnr                         integer
---@param result                        era.m.diffview.IRenderResult
function M.apply_to_buffer(bufnr, result)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  ensure_render_state_cleanup(bufnr)

  -- Set lines
  local was_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)

  -- Publish line identity and navigation together before fallible decoration work.
  RENDER_STATE_BY_BUFNR[bufnr] = {
    line_map = result.line_map,
    navigation = result.navigation or EMPTY_NAVIGATION,
  }

  vim.api.nvim_set_option_value("modifiable", was_modifiable, { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  for _, hl in ipairs(result.highlights) do
    vim.hl.range(bufnr, NS, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end

  -- Apply right-aligned INS / DEL / S columns.
  if result.overlays then
    for _, overlay in ipairs(result.overlays) do
      vim.api.nvim_buf_set_extmark(bufnr, NS, overlay.lnum, 0, {
        virt_text = overlay.virt_text,
        virt_text_pos = "right_align",
      })
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Line map management
----------------------------------------------------------------------------------------------------

---Get line map for changes buffer
---@param bufnr                         integer
---@return era.m.diffview.IFiletreeLineMap[]|nil
function M.get_line_map(bufnr)
  local state = RENDER_STATE_BY_BUFNR[bufnr] ---@type era.m.diffview.pane.changes.IRenderState|nil
  return state ~= nil and state.line_map or nil
end

---Get tree navigation for changes buffer.
---@param bufnr                         integer
---@return era.m.diffview.ITreeNavigation|nil
function M.get_navigation(bufnr)
  local state = RENDER_STATE_BY_BUFNR[bufnr] ---@type era.m.diffview.pane.changes.IRenderState|nil
  return state ~= nil and state.navigation or nil
end

---@param navigation                    era.m.diffview.ITreeNavigation|nil
---@param lnum                          integer
---@return integer|nil
function M.resolve_parent_lnum(navigation, lnum)
  local parent_lnum = navigation ~= nil and navigation.parent_lnums[lnum] or 0 ---@type integer
  return parent_lnum ~= nil and parent_lnum > 0 and parent_lnum or nil
end

---@param navigation                    era.m.diffview.ITreeNavigation|nil
---@param lnum                          integer
---@return integer|nil
function M.resolve_last_child_or_sibling_lnum(navigation, lnum)
  if navigation == nil or navigation.parent_lnums[lnum] == nil then
    return nil
  end

  local target_lnum = navigation.last_child_lnums[lnum] or 0 ---@type integer
  if target_lnum <= 0 then
    local parent_lnum = navigation.parent_lnums[lnum] or 0 ---@type integer
    if parent_lnum > 0 then
      target_lnum = navigation.last_child_lnums[parent_lnum] or 0
    else
      target_lnum = navigation.root_last_lnum
    end
  end

  return target_lnum > 0 and target_lnum ~= lnum and target_lnum or nil
end

---@param target_lnum                   integer|nil
local function goto_lnum(target_lnum)
  if target_lnum == nil then
    return
  end
  vim.api.nvim_win_set_cursor(0, { target_lnum, 0 })
end

---Move to the visible parent, matching explorer tree navigation.
function M.goto_parent_node()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lnum = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
  local item = M.get_item_at_line(bufnr, lnum)
  if item == nil or item.type == "header" then
    return
  end
  goto_lnum(M.resolve_parent_lnum(M.get_navigation(bufnr), lnum))
end

---Move to the last child, or the last sibling for a leaf, matching explorer tree navigation.
function M.goto_last_child_or_sibling()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lnum = vim.api.nvim_win_get_cursor(0)[1] ---@type integer
  local item = M.get_item_at_line(bufnr, lnum)
  if item == nil or item.type == "header" then
    return
  end
  goto_lnum(M.resolve_last_child_or_sibling_lnum(M.get_navigation(bufnr), lnum))
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
