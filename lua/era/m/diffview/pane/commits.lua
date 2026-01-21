---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.commits" ---@type string

local view_filetree = require("era.view.filetree")
local config = require("era.m.diffview.config")
local util = require("era.m.diffview.util")

---Commits pane for diffview.
---Renders commit list with optional expanded file trees.
---@class era.m.diffview.pane.commits
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local BASE_INDENT = "   " ---@type string (3 spaces for commit child indent)
local NS = config.NS

----------------------------------------------------------------------------------------------------
-- Buffer creation
----------------------------------------------------------------------------------------------------

---Create a commits panel buffer
---@return integer                      bufnr
function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  for opt, val in pairs(config.BUFOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { buf = bufnr })
  end
  vim.api.nvim_set_option_value("filetype", config.FT.COMMITS, { buf = bufnr })

  -- Disable mini plugins
  vim.b[bufnr].miniindentscope_disable = true

  return bufnr
end

----------------------------------------------------------------------------------------------------
-- Window options
----------------------------------------------------------------------------------------------------

---Generate winhighlight string for commits panel
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
  vim.api.nvim_set_option_value("signcolumn", "yes:1", { win = winnr, scope = "local" })
end

----------------------------------------------------------------------------------------------------
-- File tree renderers for commit files
----------------------------------------------------------------------------------------------------

---Create directory renderer for commit files
---@param commit                        era.m.diffview.ICommit
---@param line_map                      era.m.diffview.ICommitsLineMap[]
---@return era.view.filetree.IDirectoryRenderer
local function create_directory_renderer(commit, line_map)
  ---@param node                        era.view.filetree.ITreeNode
  ---@param lnum                        integer
  ---@param indent                      string
  ---@return string, stl.t.IHighlight[]
  return function(node, lnum, indent)
    local icon = stl.icon.filetype.FolderOpen ---@type string
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

    -- Add to line_map (directories are treated as "file" type in commits view)
    line_map[#line_map + 1] = {
      type = "file",
      commit = commit,
      entry = nil,
    }

    return line, highlights
  end
end

---Create file renderer for commit files
---@param commit                        era.m.diffview.ICommit
---@param line_map                      era.m.diffview.ICommitsLineMap[]
---@return era.view.filetree.IFileRenderer
local function create_file_renderer(commit, line_map)
  ---@param node                        era.view.filetree.ITreeNode
  ---@param lnum                        integer
  ---@param indent                      string
  ---@return string, stl.t.IHighlight[]
  return function(node, lnum, indent)
    local entry = node.data ---@type era.m.diffview.IFileEntry|nil
    local fileicon, fileicon_hln = stl.fileicon.get_file_icon(node.name)
    local status = entry and entry.status or "" ---@type string
    local status_hl = entry and util.get_status_hlgroup(status) or "m_dv_ft_filename" ---@type string

    local col = 0 ---@type integer
    local highlights = {} ---@type stl.t.IHighlight[]

    -- Build line: "indent icon filename +N -M [status]"
    local parts = { indent, fileicon, " ", node.name } ---@type string[]

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

    -- Add status at the end
    if status ~= "" then
      parts[#parts + 1] = " "
      parts[#parts + 1] = status
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
        col = col + #del_str
      end
    end

    -- Highlight status at the end
    if status ~= "" then
      col = col + 1 -- space
      highlights[#highlights + 1] = {
        hlname = status_hl,
        lnum = lnum,
        coll = col,
        colr = col + #status,
      }
    end

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "file",
      commit = commit,
      entry = entry,
    }

    return line, highlights
  end
end

---Render expanded files as a flat list
---@param commit                        era.m.diffview.ICommit
---@param files                         era.m.diffview.IFileEntry[]
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@param line_map                      era.m.diffview.ICommitsLineMap[]
local function render_files_list(commit, files, lines, highlights, line_map)
  -- Sort files by filepath
  local sorted = {} ---@type era.m.diffview.IFileEntry[]
  for _, entry in ipairs(files) do
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
    local status = entry.status or "" ---@type string -- Raw git status character
    local status_hl = util.get_status_hlgroup(status) ---@type string

    -- Build line: "    icon filepath +N -M [status]"
    local parts = { BASE_INDENT, fileicon, " ", filepath } ---@type string[]

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

    -- Add status at the end
    if status ~= "" then
      parts[#parts + 1] = " "
      parts[#parts + 1] = status
    end

    local line = table.concat(parts) ---@type string
    lines[#lines + 1] = line

    -- Highlight indent
    highlights[#highlights + 1] = {
      hlname = "m_dv_winsep",
      lnum = lnum,
      coll = col,
      colr = #BASE_INDENT,
    }
    col = #BASE_INDENT

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
        col = col + #del_str
      end
    end

    -- Highlight status at the end
    if status ~= "" then
      col = col + 1 -- space
      highlights[#highlights + 1] = {
        hlname = status_hl,
        lnum = lnum,
        coll = col,
        colr = col + #status,
      }
    end

    -- Add to line_map
    line_map[#line_map + 1] = {
      type = "file",
      commit = commit,
      entry = entry,
    }
  end
end

---Render expanded files as a tree using era.view.filetree
---@param commit                        era.m.diffview.ICommit
---@param files                         era.m.diffview.IFileEntry[]
---@param lines                         string[]
---@param highlights                    stl.t.IHighlight[]
---@param line_map                      era.m.diffview.ICommitsLineMap[]
---@param foldempty                     boolean
local function render_files_tree(commit, files, lines, highlights, line_map, foldempty)
  -- Convert file entries to file items
  local items = {} ---@type era.view.filetree.IFileItem[]
  for _, entry in ipairs(files) do
    items[#items + 1] = {
      filepath = entry.filepath,
      data = entry,
    }
  end

  local result = view_filetree.render(items, {
    foldempty = foldempty,
    base_indent = BASE_INDENT,
    start_lnum = #lines,
    render_directory = create_directory_renderer(commit, line_map),
    render_file = create_file_renderer(commit, line_map),
  })

  vim.list_extend(lines, result.lines)
  vim.list_extend(highlights, result.highlights)
end

----------------------------------------------------------------------------------------------------
-- Commits panel rendering
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.pane.commits.IRenderOpts
---@field public tabtype                stl.e.TabTypeEnum|nil
---@field public target_file            string|nil
---@field public viewtype               stl.m.diffview.PanelViewTypeEnum|nil
---@field public foldempty              boolean|nil
---@field public layout                 integer|nil                     Layout type (1-5)

---Render commits panel with optional expanded file lists
---@param commits                       era.m.diffview.ICommit[]
---@param expanded                      table<string, boolean>
---@param opts                          era.m.diffview.pane.commits.IRenderOpts|nil
---@return era.m.diffview.IRenderResult
function M.render(commits, expanded, opts)
  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local line_map = {} ---@type era.m.diffview.ICommitsLineMap[]
  local overlays = {} ---@type era.m.diffview.IOverlay[]

  -- Get view flags from opts or context
  local viewtype = (opts and opts.viewtype) or dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
  local foldempty_opt = opts and opts.foldempty
  local foldempty = foldempty_opt ~= nil and foldempty_opt or dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
  local layout = (opts and opts.layout) or 1 ---@type integer

  -- Determine if layout is horizontal (wider) or vertical (narrower)
  -- Layout 1,4: horizontal (commits pane is wide) - use detailed format
  -- Layout 2,5: vertical (commits pane is narrow) - use compact format
  local is_horizontal = (layout == 1 or layout == 4) ---@type boolean

  -- Calculate max widths for alignment (only for horizontal layout)
  local max_files_width = 1 ---@type integer
  local max_ins_width = 1 ---@type integer
  local max_del_width = 1 ---@type integer
  local max_date_width = 1 ---@type integer
  if is_horizontal then
    for _, commit in ipairs(commits) do
      local files = commit.total_files_changed or 0
      local ins = commit.file_insertions or commit.total_insertions or 0
      local del = commit.file_deletions or commit.total_deletions or 0
      local date_str = util.format_relative_time(commit.date)
      max_files_width = math.max(max_files_width, #tostring(files))
      max_ins_width = math.max(max_ins_width, #tostring(ins))
      max_del_width = math.max(max_del_width, #tostring(del))
      max_date_width = math.max(max_date_width, #date_str)
    end
  end

  for _, commit in ipairs(commits) do
    local line, line_highlights, overlay ---@type string, stl.t.IHighlight[], era.m.diffview.IOverlay|nil
    if is_horizontal then
      line, line_highlights, overlay = M.__render_commit_horizontal__(commit, #lines, max_files_width, max_ins_width, max_del_width, max_date_width, expanded[commit.hash])
    else
      line, line_highlights, overlay = M.__render_commit_vertical__(commit, #lines, expanded[commit.hash])
    end
    lines[#lines + 1] = line
    vim.list_extend(highlights, line_highlights)
    if overlay then
      overlays[#overlays + 1] = overlay
    end
    line_map[#line_map + 1] = { type = "commit", commit = commit, entry = nil }

    -- Render expanded files (for both log and file_history view)
    if expanded[commit.hash] and commit.files then
      if viewtype == "list" then
        render_files_list(commit, commit.files, lines, highlights, line_map)
      else
        render_files_tree(commit, commit.files, lines, highlights, line_map, foldempty)
      end
    end
  end

  return {
    lines = lines,
    highlights = highlights,
    line_map = line_map,
    overlays = overlays,
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

  -- Apply overlays (right-aligned virtual text)
  if result.overlays then
    for _, overlay in ipairs(result.overlays) do
      vim.api.nvim_buf_set_extmark(bufnr, NS, overlay.lnum, 0, {
        virt_text = overlay.virt_text,
        virt_text_pos = "right_align",
      })
    end
  end

  -- Store line_map
  M.set_line_map(bufnr, result.line_map)
end

----------------------------------------------------------------------------------------------------
-- Line map management
----------------------------------------------------------------------------------------------------

---Get line map for commits buffer
---@param bufnr                         integer
---@return era.m.diffview.ICommitsLineMap[]|nil
function M.get_line_map(bufnr)
  return vim.b[bufnr].diffview_commits_line_map
end

----------------------------------------------------------------------------------------------------
-- Sign management
----------------------------------------------------------------------------------------------------

---Update present sign (currently displayed commit)
---@param bufnr                         integer
---@param lnum_present                  integer                         1-indexed line number
function M.update_sign_present(bufnr, lnum_present)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local group = dot.var.sign.GROUP_DIFFVIEW_COMMITS ---@type string

  -- Clear all signs first
  vim.fn.sign_unplace(group, { buffer = bufnr })

  -- Place present sign
  if lnum_present > 0 then
    vim.fn.sign_place(0, group, dot.var.sign.DIFFVIEW_COMMITS_PRESENT, bufnr, { lnum = lnum_present, priority = 30 })
  end
end

---Clear all signs from commits buffer
---@param bufnr                         integer
function M.clear_signs(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.fn.sign_unplace(dot.var.sign.GROUP_DIFFVIEW_COMMITS, { buffer = bufnr })
end

---Set line map for commits buffer
---@param bufnr                         integer
---@param line_map                      era.m.diffview.ICommitsLineMap[]
function M.set_line_map(bufnr, line_map)
  vim.b[bufnr].diffview_commits_line_map = line_map
end

---Get item at cursor position
---@param bufnr                         integer
---@param lnum                          integer                         1-indexed line number
---@return era.m.diffview.ICommitsLineMap|nil
function M.get_item_at_line(bufnr, lnum)
  local line_map = M.get_line_map(bufnr)
  if not line_map or lnum < 1 or lnum > #line_map then
    return nil
  end
  return line_map[lnum]
end

---Find line number for commit
---@param line_map                      era.m.diffview.ICommitsLineMap[]
---@param hash                          string
---@return integer|nil                  1-indexed line number
function M.find_commit_line(line_map, hash)
  for i, item in ipairs(line_map) do
    if item.type == "commit" and item.commit and item.commit.hash == hash then
      return i
    end
  end
  return nil
end

---Find line number for file entry
---@param line_map                      era.m.diffview.ICommitsLineMap[]
---@param commit_hash                   string
---@param filepath                      string
---@return integer|nil                  1-indexed line number
function M.find_file_line(line_map, commit_hash, filepath)
  for i, item in ipairs(line_map) do
    if
      item.type == "file"
      and item.commit
      and item.commit.hash == commit_hash
      and item.entry
      and item.entry.filepath == filepath
    then
      return i
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------

---Render a single commit line for horizontal layout (layout 1,4 - wider panel)
---Format: <expand icon> <files> +<ins> -<del> | <hash> <message> | {author} {time ago} (overlay)
---@param commit                        era.m.diffview.ICommit
---@param lnum                          integer                         0-indexed line number
---@param max_files_width               integer
---@param max_ins_width                 integer
---@param max_del_width                 integer
---@param max_date_width                integer
---@param is_expanded                   boolean|nil
---@return string, stl.t.IHighlight[], era.m.diffview.IOverlay|nil
function M.__render_commit_horizontal__(commit, lnum, max_files_width, max_ins_width, max_del_width, max_date_width, is_expanded)
  local parts = {} ---@type string[]
  local col = 0 ---@type integer
  local highlights = {} ---@type stl.t.IHighlight[]

  -- Expand/collapse icon
  local icon = is_expanded and stl.icon.ui.ArrowOpen or stl.icon.ui.ArrowClosed
  parts[#parts + 1] = icon
  col = col + #icon

  -- Space
  parts[#parts + 1] = " "
  col = col + 1

  -- File count (right-aligned)
  local files = commit.total_files_changed or 0
  local files_str = string.format("%" .. max_files_width .. "d", files)
  parts[#parts + 1] = files_str
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_files",
    lnum = lnum,
    coll = col,
    colr = col + #files_str,
  }
  col = col + #files_str

  -- Space
  parts[#parts + 1] = " "
  col = col + 1

  -- Insertions (left-aligned, padding on right)
  local ins = commit.file_insertions or commit.total_insertions or 0
  local ins_str = string.format("%-" .. max_ins_width .. "d", ins)
  local ins_prefix = "+"
  parts[#parts + 1] = ins_prefix
  highlights[#highlights + 1] = {
    hlname = "m_dv_ft_insertions",
    lnum = lnum,
    coll = col,
    colr = col + #ins_prefix,
  }
  col = col + #ins_prefix

  parts[#parts + 1] = ins_str
  highlights[#highlights + 1] = {
    hlname = "m_dv_ft_insertions",
    lnum = lnum,
    coll = col,
    colr = col + #ins_str,
  }
  col = col + #ins_str

  -- Space
  parts[#parts + 1] = " "
  col = col + 1

  -- Deletions (left-aligned, padding on right)
  local del = commit.file_deletions or commit.total_deletions or 0
  local del_str = string.format("%-" .. max_del_width .. "d", del)
  local del_prefix = "-"
  parts[#parts + 1] = del_prefix
  highlights[#highlights + 1] = {
    hlname = "m_dv_ft_deletions",
    lnum = lnum,
    coll = col,
    colr = col + #del_prefix,
  }
  col = col + #del_prefix

  parts[#parts + 1] = del_str
  highlights[#highlights + 1] = {
    hlname = "m_dv_ft_deletions",
    lnum = lnum,
    coll = col,
    colr = col + #del_str,
  }
  col = col + #del_str

  -- Separator " | "
  local sep = " | "
  parts[#parts + 1] = sep
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_sep",
    lnum = lnum,
    coll = col,
    colr = col + #sep,
  }
  col = col + #sep

  -- Hash
  local hash = commit.abbrev_hash
  parts[#parts + 1] = hash
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_hash",
    lnum = lnum,
    coll = col,
    colr = col + #hash,
  }
  col = col + #hash

  -- Space
  parts[#parts + 1] = " "
  col = col + 1

  -- Message (full, no truncation)
  local message = commit.message
  parts[#parts + 1] = message
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_message",
    lnum = lnum,
    coll = col,
    colr = col + #message,
  }

  -- Overlay: author, time ago (right-aligned virtual text, padded)
  local author = commit.author
  local date = util.format_relative_time(commit.date)
  local date_padded = string.format("%-" .. max_date_width .. "s", date)
  ---@type era.m.diffview.IOverlay
  local overlay = {
    lnum = lnum,
    virt_text = {
      { author, "m_dv_cm_author" },
      { " ", "m_dv_cm_date" },
      { date_padded, "m_dv_cm_date" },
    },
  }

  return table.concat(parts), highlights, overlay
end

---Render a single commit line for vertical layout (layout 2,5 - narrower panel)
---Format: <expand icon> | <hash> <message> {author} {time ago}
---@param commit                        era.m.diffview.ICommit
---@param lnum                          integer                         0-indexed line number
---@param is_expanded                   boolean|nil
---@return string, stl.t.IHighlight[], era.m.diffview.IOverlay|nil
function M.__render_commit_vertical__(commit, lnum, is_expanded)
  local parts = {} ---@type string[]
  local col = 0 ---@type integer
  local highlights = {} ---@type stl.t.IHighlight[]

  -- Expand/collapse icon
  local icon = is_expanded and stl.icon.ui.ArrowOpen or stl.icon.ui.ArrowClosed
  parts[#parts + 1] = icon
  col = col + #icon

  -- Separator " | "
  local sep = " | "
  parts[#parts + 1] = sep
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_sep",
    lnum = lnum,
    coll = col,
    colr = col + #sep,
  }
  col = col + #sep

  -- Hash
  local hash = commit.abbrev_hash
  parts[#parts + 1] = hash
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_hash",
    lnum = lnum,
    coll = col,
    colr = col + #hash,
  }
  col = col + #hash

  -- Space
  parts[#parts + 1] = " "
  col = col + 1

  -- Message (full, no truncation)
  local message = commit.message
  parts[#parts + 1] = message
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_message",
    lnum = lnum,
    coll = col,
    colr = col + #message,
  }
  col = col + #message

  -- Space
  parts[#parts + 1] = " "
  col = col + 1

  -- Author
  local author = commit.author
  parts[#parts + 1] = author
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_author",
    lnum = lnum,
    coll = col,
    colr = col + #author,
  }
  col = col + #author

  -- ", "
  parts[#parts + 1] = ", "
  col = col + 2

  -- Date
  local date = util.format_relative_time(commit.date)
  parts[#parts + 1] = date
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_date",
    lnum = lnum,
    coll = col,
    colr = col + #date,
  }

  return table.concat(parts), highlights, nil
end

return M
