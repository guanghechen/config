---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.commits" ---@type string

local view_filetree = require("era.view.filetree")
local commit_format = require("era.m.diffview.commit_format")
local config = require("era.m.diffview.config")
local util = require("era.m.diffview.util")

---Commits pane for diffview.
---Renders commit topology rows with optional expanded file trees.
---@class era.m.diffview.pane.commits
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local HISTORY_BASE_INDENT = "" ---@type string (align tree roots with the first hash character)
local STANDALONE_BASE_INDENT = "   " ---@type string
local NS = config.NS

---@class era.m.diffview.pane.commits.IRenderState
---@field public line_map               era.m.diffview.ICommitsLineMap[]
---@field public navigation             era.m.diffview.ITreeNavigation

local EMPTY_NAVIGATION = {
  parent_lnums = {},
  last_child_lnums = {},
  root_last_lnum = 0,
} ---@type era.m.diffview.ITreeNavigation

-- Keep layout-sized render state in Lua. Reading nested arrays from vim.b copies them on every access.
local RENDER_STATE_BY_BUFNR = {} ---@type table<integer, era.m.diffview.pane.commits.IRenderState>
local RENDER_STATE_CLEANUP_REGISTERED = {} ---@type table<integer, true>

---@param bufnr                         integer
---@return nil
local function ensure_render_state_cleanup(bufnr)
  if RENDER_STATE_CLEANUP_REGISTERED[bufnr] then
    return
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    desc = "diffview: release commits render state",
    callback = function()
      RENDER_STATE_BY_BUFNR[bufnr] = nil
      RENDER_STATE_CLEANUP_REGISTERED[bufnr] = nil
    end,
  })
  RENDER_STATE_CLEANUP_REGISTERED[bufnr] = true
end

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
---@param collapsed_dirs                table<string, boolean>
---@return era.view.filetree.IDirectoryRenderer
local function create_directory_renderer(commit, line_map, collapsed_dirs)
  ---@param node                        era.view.filetree.ITreeNode
  ---@param lnum                        integer
  ---@param indent                      string
  ---@return string, stl.t.IHighlight[]
  return function(node, lnum, indent)
    local icon = collapsed_dirs[node.filepath] and stl.icon.filetype.Folder or stl.icon.filetype.FolderOpen ---@type string
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

    line_map[#line_map + 1] = {
      type = "directory",
      commit = commit,
      entry = nil,
      filepath = node.filepath,
      uuid = node.filepath,
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
---@param navigation                   era.m.diffview.ITreeNavigation
---@param base_indent                   string
local function render_files_list(commit, files, lines, highlights, line_map, navigation, base_indent)
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
    local parts = { base_indent, fileicon, " ", filepath } ---@type string[]

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
    local row = #lines ---@type integer
    navigation.parent_lnums[row] = 0
    navigation.last_child_lnums[row] = 0
    navigation.root_last_lnum = row

    -- Highlight indent
    highlights[#highlights + 1] = {
      hlname = "m_dv_winsep",
      lnum = lnum,
      coll = col,
      colr = #base_indent,
    }
    col = #base_indent

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
---@param navigation                    era.m.diffview.ITreeNavigation
---@param commit_lnum                   integer
---@param base_indent                   string
---@param collapsed_dirs                table<string, boolean>
local function render_files_tree(
  commit,
  files,
  lines,
  highlights,
  line_map,
  foldempty,
  navigation,
  commit_lnum,
  base_indent,
  collapsed_dirs
)
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
    base_indent = base_indent,
    start_lnum = #lines,
    render_directory = create_directory_renderer(commit, line_map, collapsed_dirs),
    render_file = create_file_renderer(commit, line_map),
    is_collapsed = function(node)
      return collapsed_dirs[node.filepath] == true
    end,
  })

  local offset = #lines ---@type integer
  for row = 1, result.layout:len() do
    local global_lnum = offset + row ---@type integer
    local local_parent_lnum = result.layout:parent_lnum(row) ---@type integer|nil
    local parent_lnum = local_parent_lnum ~= nil and (offset + local_parent_lnum) or commit_lnum ---@type integer
    local local_last_child_lnum = result.layout:last_child_lnum(row) ---@type integer|nil
    navigation.parent_lnums[global_lnum] = parent_lnum
    navigation.last_child_lnums[global_lnum] = local_last_child_lnum ~= nil and (offset + local_last_child_lnum) or 0
    if local_parent_lnum == nil then
      navigation.last_child_lnums[commit_lnum] = global_lnum
    end
  end

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
---@field public collapsed_dirs         table<string, table<string, boolean>>|nil Per-commit directory state

---Render commits panel with optional expanded file trees.
---@param commits                       era.m.diffview.ICommit[]
---@param expanded                      table<string, boolean>
---@param opts                          era.m.diffview.pane.commits.IRenderOpts|nil
---@return era.m.diffview.IRenderResult
function M.render(commits, expanded, opts)
  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local line_map = {} ---@type era.m.diffview.ICommitsLineMap[]
  local overlays = {} ---@type era.m.diffview.IOverlay[]
  local navigation = {
    parent_lnums = {},
    last_child_lnums = {},
    root_last_lnum = 0,
  } ---@type era.m.diffview.ITreeNavigation

  -- Get view flags from opts or context
  local viewtype = (opts and opts.viewtype) or dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
  local foldempty_opt = opts and opts.foldempty
  local foldempty = foldempty_opt ~= nil and foldempty_opt or dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
  local layout = (opts and opts.layout) or 1 ---@type integer
  local is_workspace_history = opts and opts.tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE ---@type boolean|nil
  local show_expand_icon = not is_workspace_history ---@type boolean
  local base_indent = is_workspace_history and HISTORY_BASE_INDENT or STANDALONE_BASE_INDENT ---@type string
  local collapsed_dirs = (opts and opts.collapsed_dirs) or {} ---@type table<string, table<string, boolean>>

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
      line, line_highlights, overlay =
        M.__render_commit_vertical__(commit, #lines, expanded[commit.hash], show_expand_icon)
    end
    lines[#lines + 1] = line
    local commit_lnum = #lines ---@type integer
    navigation.parent_lnums[commit_lnum] = 0
    navigation.last_child_lnums[commit_lnum] = 0
    navigation.root_last_lnum = commit_lnum
    vim.list_extend(highlights, line_highlights)
    if overlay then
      overlays[#overlays + 1] = overlay
    end
    line_map[#line_map + 1] = { type = "commit", commit = commit, entry = nil }

    -- Render expanded files (for both log and file_history view)
    if expanded[commit.hash] and commit.files then
      if viewtype == "list" then
        render_files_list(commit, commit.files, lines, highlights, line_map, navigation, base_indent)
      else
        render_files_tree(
          commit,
          commit.files,
          lines,
          highlights,
          line_map,
          foldempty,
          navigation,
          commit_lnum,
          base_indent,
          collapsed_dirs[commit.hash] or {}
        )
      end
    end
  end

  return {
    lines = lines,
    highlights = highlights,
    line_map = line_map,
    overlays = overlays,
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

  -- Register cleanup before mutating the buffer. Once lines change, their semantic state must publish too.
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

  -- Apply overlays (right-aligned virtual text)
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

---Get line map for commits buffer
---@param bufnr                         integer
---@return era.m.diffview.ICommitsLineMap[]|nil
function M.get_line_map(bufnr)
  local state = RENDER_STATE_BY_BUFNR[bufnr] ---@type era.m.diffview.pane.commits.IRenderState|nil
  return state ~= nil and state.line_map or nil
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

---Get navigation index for commits buffer.
---@param bufnr                         integer
---@return era.m.diffview.ITreeNavigation|nil
function M.get_navigation(bufnr)
  local state = RENDER_STATE_BY_BUFNR[bufnr] ---@type era.m.diffview.pane.commits.IRenderState|nil
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
---@return nil
local function goto_lnum(target_lnum)
  if target_lnum == nil then
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local line = vim.api.nvim_buf_get_lines(bufnr, target_lnum - 1, target_lnum, false)[1] or "" ---@type string
  local content_start = line:find("[^ │├╰─]") or 1 ---@type integer
  vim.api.nvim_win_set_cursor(winnr, { target_lnum, content_start - 1 })
end

---@return nil
function M.goto_parent_node()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
  goto_lnum(M.resolve_parent_lnum(M.get_navigation(bufnr), lnum))
end

---@return nil
function M.goto_last_child_or_sibling()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
  goto_lnum(M.resolve_last_child_or_sibling_lnum(M.get_navigation(bufnr), lnum))
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

---@param parts                          string[]
---@param highlights                     stl.t.IHighlight[]
---@param commit                         era.m.diffview.ICommit
---@param lnum                           integer
---@param col                            integer
---@return integer
local function append_short_author(parts, highlights, commit, lnum, col)
  local author = commit_format.short_author(commit.author) ---@type string
  parts[#parts + 1] = author
  if author ~= "" then
    highlights[#highlights + 1] = {
      hlname = "m_dv_cm_author",
      lnum = lnum,
      coll = col,
      colr = col + #author,
    }
  end
  col = col + #author

  local padding = string.rep(" ", math.max(0, 2 - vim.fn.strdisplaywidth(author))) ---@type string
  parts[#parts + 1] = padding
  return col + #padding
end

---@param parts                          string[]
---@param highlights                     stl.t.IHighlight[]
---@param graph                          string|nil
---@param lnum                           integer
---@param col                            integer
---@return integer
local function append_graph(parts, highlights, graph, lnum, col)
  if not graph or graph == "" then
    return col
  end
  parts[#parts + 1] = graph
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_graph",
    lnum = lnum,
    coll = col,
    colr = col + #graph,
  }
  parts[#parts + 1] = " "
  return col + #graph + 1
end

---Render a single commit line for horizontal layout (layout 1,4 - wider panel)
---Format: [<expand icon> ]<files> +<ins> -<del> | <hash> <author> [<graph> ]<message>
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

  if not commit.graph then
    local icon = is_expanded and stl.icon.ui.ArrowOpen or stl.icon.ui.ArrowClosed
    parts[#parts + 1] = icon
    parts[#parts + 1] = " "
    col = col + #icon + 1
  end

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

  col = append_short_author(parts, highlights, commit, lnum, col)
  parts[#parts + 1] = " "
  col = col + 1
  col = append_graph(parts, highlights, commit.graph, lnum, col)

  -- Message (full, no truncation)
  local message = commit_format.render_gitmoji(commit.message) ---@type string
  parts[#parts + 1] = message
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_message",
    lnum = lnum,
    coll = col,
    colr = col + #message,
  }

  -- Overlay: time ago (right-aligned virtual text, padded)
  local date = util.format_relative_time(commit.date)
  local date_padded = string.format("%-" .. max_date_width .. "s", date)
  ---@type era.m.diffview.IOverlay
  local overlay = {
    lnum = lnum,
    virt_text = {
      { date_padded, "m_dv_cm_date" },
    },
  }

  return table.concat(parts), highlights, overlay
end

---Render a single commit line for vertical layout (layout 2,5 - narrower panel)
---Format: [<expand icon> | ]<hash> <author> [<graph> ]<message> {time ago}
---@param commit                        era.m.diffview.ICommit
---@param lnum                          integer                         0-indexed line number
---@param is_expanded                   boolean|nil
---@param show_expand_icon              boolean
---@return string, stl.t.IHighlight[], era.m.diffview.IOverlay|nil
function M.__render_commit_vertical__(commit, lnum, is_expanded, show_expand_icon)
  local parts = {} ---@type string[]
  local col = 0 ---@type integer
  local highlights = {} ---@type stl.t.IHighlight[]

  if show_expand_icon and not commit.graph then
    local icon = is_expanded and stl.icon.ui.ArrowOpen or stl.icon.ui.ArrowClosed
    parts[#parts + 1] = icon
    col = col + #icon

    local sep = " | "
    parts[#parts + 1] = sep
    highlights[#highlights + 1] = {
      hlname = "m_dv_cm_sep",
      lnum = lnum,
      coll = col,
      colr = col + #sep,
    }
    col = col + #sep
  end

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

  col = append_short_author(parts, highlights, commit, lnum, col)
  parts[#parts + 1] = " "
  col = col + 1
  col = append_graph(parts, highlights, commit.graph, lnum, col)

  -- Message (full, no truncation)
  local message = commit_format.render_gitmoji(commit.message) ---@type string
  parts[#parts + 1] = message
  highlights[#highlights + 1] = {
    hlname = "m_dv_cm_message",
    lnum = lnum,
    coll = col,
    colr = col + #message,
  }
  col = col + #message

  parts[#parts + 1] = " "
  col = col + 1

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
