---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.commits" ---@type string

local tree = require("era.m.diffview.pane.tree")
local files = require("era.m.diffview.pane.filetree")
local commit_format = require("era.m.diffview.commit_format")
local config = require("era.m.diffview.config")
local util = require("era.m.diffview.util")
local M = {}
M.apply_to_buffer = tree.apply
M.get_line_map = tree.line_map
M.get_item_at_line = tree.item
M.get_navigation = tree.navigation
M.resolve_parent_lnum = tree.parent
M.resolve_last_child_or_sibling_lnum = tree.last_child
M.goto_parent_node = files.goto_parent_node
M.goto_last_child_or_sibling = files.goto_last_child_or_sibling

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
function M.__render_commit_horizontal__(
  commit,
  lnum,
  max_files_width,
  max_ins_width,
  max_del_width,
  max_date_width,
  is_expanded
)
  local parts = {} ---@type string[]
  local col = 0 ---@type integer
  local highlights = {} ---@type stl.t.IHighlight[]

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

---@param commits                       era.m.diffview.ICommit[]
---@param opts                          ?table
---@return table
function M.render(commits, opts)
  opts = opts or {}
  local plan = tree.plan(opts)
  plan.inline = true
  local horizontal = opts.layout == nil or opts.layout == 1 or opts.layout == 4
  local widths = { 1, 1, 1, 1 }
  for _, commit in ipairs(commits) do
    widths[1] = math.max(widths[1], #tostring(commit.total_files_changed or 0))
    widths[2] = math.max(widths[2], #tostring(commit.file_insertions or commit.total_insertions or 0))
    widths[3] = math.max(widths[3], #tostring(commit.file_deletions or commit.total_deletions or 0))
    widths[4] = math.max(widths[4], #util.format_relative_time(commit.date))
  end
  for _, commit in ipairs(commits) do
    local include_files = opts.include_files and opts.include_files[commit.hash] and commit.files ~= nil
    local metadata = commit
    if not include_files then
      metadata = {}
      for key, value in pairs(commit) do
        if key ~= "files" then
          metadata[key] = value
        end
      end
    end
    local label, highlights, overlay
    if horizontal then
      label, highlights, overlay = M.__render_commit_horizontal__(commit, 0, widths[1], widths[2], widths[3], widths[4])
    else
      label, highlights, overlay = M.__render_commit_vertical__(commit, 0, false, false)
    end
    local key = "commit:" .. commit.hash
    plan.source:insert(tree.root, key, {
      presentation = {
        label = label,
        highlight = "m_dv_cm_message",
        fields = { highlights = highlights, overlay = overlay and overlay.virt_text or nil },
      },
      item = { type = "commit", commit = metadata },
      files_loaded = include_files == true,
    })
    plan.entries[key] = { nodetype = "container", foldable = false }
    plan.default_closed[#plan.default_closed + 1] = key
    if include_files then
      plan.source:get(key).file_nodes = tree.files(plan, commit.files, key, commit)
    end
  end
  return plan
end

return M
