---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.filetree" ---@type string

local view_filetree = require("era.view.filetree")
local config = require("era.m.diffview.config")
local util = require("era.m.diffview.util")

---Generic filetree pane for diffview.
---Used for commits expanded files in layout 5 (commits + filetree).
---@class era.m.diffview.pane.filetree
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local NS = config.NS

----------------------------------------------------------------------------------------------------
-- Buffer creation
----------------------------------------------------------------------------------------------------

---Create a filetree panel buffer
---@return integer                      bufnr
function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  for opt, val in pairs(config.BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", config.FT.FILETREE, { buf = bufnr })

  return bufnr
end

----------------------------------------------------------------------------------------------------
-- Window options
----------------------------------------------------------------------------------------------------

---Generate winhighlight string for filetree panel
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
-- Filetree renderers
----------------------------------------------------------------------------------------------------

---Create directory renderer
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@param collapsed_dirs                table<string, boolean>
---@return era.view.filetree.IDirectoryRenderer
local function create_directory_renderer(line_map, collapsed_dirs)
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
      hlname = "m_dv_winsep",
      lnum = lnum,
      coll = col,
      colr = #indent,
    }
    col = #indent

    -- Highlight icon
    highlights[#highlights + 1] = {
      hlname = "m_dv_ft_dirname",
      lnum = lnum,
      coll = col,
      colr = col + #icon,
    }
    col = col + #icon + 1

    -- Highlight name
    highlights[#highlights + 1] = {
      hlname = "m_dv_ft_dirname",
      lnum = lnum,
      coll = col,
      colr = #line,
    }

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "directory",
      entry = nil,
      stage_type = nil,
      uuid = node.filepath,
    }

    return line, highlights
  end
end

---Create file renderer
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@return era.view.filetree.IFileRenderer
local function create_file_renderer(line_map)
  ---@param node                        era.view.filetree.ITreeNode
  ---@param lnum                        integer
  ---@param indent                      string
  ---@return string, stl.t.IHighlight[]
  return function(node, lnum, indent)
    local entry = node.data ---@type era.m.diffview.IFileEntry|nil
    local fileicon, fileicon_hln = stl.fileicon.get_file_icon(node.name)
    local status_icon = entry and util.get_status_icon(entry.status) or "" ---@type string
    local status_hl = entry and util.get_status_hlgroup(entry.status) or "m_dv_ft_filename" ---@type string

    local col = 0 ---@type integer
    local highlights = {} ---@type stl.t.IHighlight[]

    -- Build line
    local parts = { indent, status_icon, " ", fileicon, " ", node.name } ---@type string[]

    -- Add stats if available
    if entry and (entry.insertions or entry.deletions) then
      parts[#parts + 1] = " "
      if entry.insertions and entry.insertions > 0 then
        parts[#parts + 1] = string.format("+%d", entry.insertions)
        if entry.deletions and entry.deletions > 0 then
          parts[#parts + 1] = " "
        end
      end
      if entry.deletions and entry.deletions > 0 then
        parts[#parts + 1] = string.format("-%d", entry.deletions)
      end
    end

    local line = table.concat(parts) ---@type string

    -- Highlight indent
    highlights[#highlights + 1] = {
      hlname = "m_dv_winsep",
      lnum = lnum,
      coll = col,
      colr = #indent,
    }
    col = #indent

    -- Highlight status icon
    highlights[#highlights + 1] = {
      hlname = status_hl,
      lnum = lnum,
      coll = col,
      colr = col + #status_icon,
    }
    col = col + #status_icon + 1

    -- Highlight file icon
    highlights[#highlights + 1] = {
      hlname = fileicon_hln,
      lnum = lnum,
      coll = col,
      colr = col + #fileicon,
    }
    col = col + #fileicon + 1

    -- Highlight filename
    local name_end = col + #node.name ---@type integer
    highlights[#highlights + 1] = {
      hlname = "m_dv_ft_filename",
      lnum = lnum,
      coll = col,
      colr = name_end,
    }
    col = name_end

    -- Highlight stats
    if entry and (entry.insertions or entry.deletions) then
      col = col + 1 -- space
      if entry.insertions and entry.insertions > 0 then
        local ins_str = string.format("+%d", entry.insertions)
        highlights[#highlights + 1] = {
          hlname = "m_dv_ft_insertions",
          lnum = lnum,
          coll = col,
          colr = col + #ins_str,
        }
        col = col + #ins_str
        if entry.deletions and entry.deletions > 0 then
          col = col + 1 -- space
        end
      end
      if entry.deletions and entry.deletions > 0 then
        local del_str = string.format("-%d", entry.deletions)
        highlights[#highlights + 1] = {
          hlname = "m_dv_ft_deletions",
          lnum = lnum,
          coll = col,
          colr = col + #del_str,
        }
      end
    end

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "file",
      entry = entry,
      stage_type = nil,
      uuid = node.filepath,
    }

    return line, highlights
  end
end

----------------------------------------------------------------------------------------------------
-- Filetree rendering
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.pane.filetree.IRenderOpts
---@field public viewtype               stl.m.diffview.PanelViewTypeEnum|nil
---@field public foldempty              boolean|nil
---@field public collapsed_dirs         table<string, boolean>|nil

---Render filetree for a list of file entries
---@param entries                       era.m.diffview.IFileEntry[]
---@param opts                          era.m.diffview.pane.filetree.IRenderOpts|nil
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

  if #entries == 0 then
    return {
      lines = lines,
      highlights = highlights,
      line_map = line_map,
    }
  end

  if viewtype == "list" then
    -- Render as flat list
    M.__render_list__(entries, lines, highlights, line_map)
  else
    -- Render as tree
    M.__render_tree__(entries, lines, highlights, line_map, collapsed_dirs, foldempty)
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

---Get line map for filetree buffer
---@param bufnr                         integer
---@return era.m.diffview.IFiletreeLineMap[]|nil
function M.get_line_map(bufnr)
  return vim.b[bufnr].diffview_filetree_line_map
end

---Set line map for filetree buffer
---@param bufnr                         integer
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
function M.set_line_map(bufnr, line_map)
  vim.b[bufnr].diffview_filetree_line_map = line_map
end

---Get collapsed dirs map for filetree buffer
---@param bufnr                         integer
---@return table<string, boolean>|nil
function M.get_collapsed_dirs(bufnr)
  return vim.b[bufnr].diffview_filetree_collapsed_dirs
end

---Set collapsed dirs map for filetree buffer
---@param bufnr                         integer
---@param collapsed_dirs                table<string, boolean>
function M.set_collapsed_dirs(bufnr, collapsed_dirs)
  vim.b[bufnr].diffview_filetree_collapsed_dirs = collapsed_dirs
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
---@param filepath                      string
---@return integer|nil                  1-indexed line number
function M.find_entry_line(line_map, filepath)
  for i, item in ipairs(line_map) do
    if item.type == "file" and item.entry and item.entry.filepath == filepath then
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

----------------------------------------------------------------------------------------------------

---Render entries as flat list
---@param entries                       era.m.diffview.IFileEntry[]
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
function M.__render_list__(entries, lines, highlights, line_map)
  -- Sort by filepath
  local sorted = {} ---@type era.m.diffview.IFileEntry[]
  for _, entry in ipairs(entries) do
    sorted[#sorted + 1] = entry
  end
  table.sort(sorted, function(a, b)
    return a.filepath < b.filepath
  end)

  for _, entry in ipairs(sorted) do
    local lnum = #lines ---@type integer
    local col = 0 ---@type integer

    local filepath = entry.filepath ---@type string
    local basename = vim.fn.fnamemodify(filepath, ":t") ---@type string
    local fileicon, fileicon_hln = stl.fileicon.get_file_icon(basename)
    local status_icon = util.get_status_icon(entry.status) ---@type string
    local status_hl = util.get_status_hlgroup(entry.status) ---@type string

    local indent = "  " ---@type string

    -- Build line: "  + icon filepath +N -M"
    local parts = { indent, status_icon, " ", fileicon, " ", filepath } ---@type string[]

    -- Add stats if available
    if entry.insertions or entry.deletions then
      parts[#parts + 1] = " "
      if entry.insertions and entry.insertions > 0 then
        parts[#parts + 1] = string.format("+%d", entry.insertions)
        if entry.deletions and entry.deletions > 0 then
          parts[#parts + 1] = " "
        end
      end
      if entry.deletions and entry.deletions > 0 then
        parts[#parts + 1] = string.format("-%d", entry.deletions)
      end
    end

    local line = table.concat(parts) ---@type string
    lines[#lines + 1] = line

    -- Highlight indent
    highlights[#highlights + 1] = {
      hlname = "m_dv_winsep",
      lnum = lnum,
      coll = col,
      colr = #indent,
    }
    col = #indent

    -- Highlight status icon
    highlights[#highlights + 1] = {
      hlname = status_hl,
      lnum = lnum,
      coll = col,
      colr = col + #status_icon,
    }
    col = col + #status_icon + 1

    -- Highlight file icon
    highlights[#highlights + 1] = {
      hlname = fileicon_hln,
      lnum = lnum,
      coll = col,
      colr = col + #fileicon,
    }
    col = col + #fileicon + 1

    -- Highlight filepath
    local filepath_end = col + #filepath ---@type integer
    highlights[#highlights + 1] = {
      hlname = "m_dv_ft_filename",
      lnum = lnum,
      coll = col,
      colr = filepath_end,
    }
    col = filepath_end

    -- Highlight stats
    if entry.insertions or entry.deletions then
      col = col + 1 -- space
      if entry.insertions and entry.insertions > 0 then
        local ins_str = string.format("+%d", entry.insertions)
        highlights[#highlights + 1] = {
          hlname = "m_dv_ft_insertions",
          lnum = lnum,
          coll = col,
          colr = col + #ins_str,
        }
        col = col + #ins_str
        if entry.deletions and entry.deletions > 0 then
          col = col + 1 -- space
        end
      end
      if entry.deletions and entry.deletions > 0 then
        local del_str = string.format("-%d", entry.deletions)
        highlights[#highlights + 1] = {
          hlname = "m_dv_ft_deletions",
          lnum = lnum,
          coll = col,
          colr = col + #del_str,
        }
      end
    end

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "file",
      entry = entry,
      stage_type = nil,
      uuid = filepath,
    }
  end
end

---Render entries as tree
---@param entries                       era.m.diffview.IFileEntry[]
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@param line_map                      era.m.diffview.IFiletreeLineMap[]
---@param collapsed_dirs                table<string, boolean>
---@param foldempty                     boolean
function M.__render_tree__(entries, lines, highlights, line_map, collapsed_dirs, foldempty)
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
    render_directory = create_directory_renderer(line_map, collapsed_dirs),
    render_file = create_file_renderer(line_map),
    is_collapsed = function(node)
      return collapsed_dirs[node.filepath] == true
    end,
  })

  vim.list_extend(lines, result.lines)
  vim.list_extend(highlights, result.highlights)
end

return M
