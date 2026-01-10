---@class era.view.filetree
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local INDENT_BRANCH = "├─" ---@type string
local INDENT_LAST = "╰─" ---@type string
local INDENT_PIPE = "│ " ---@type string
local INDENT_SPACE = "  " ---@type string

----------------------------------------------------------------------------------------------------
-- Types
----------------------------------------------------------------------------------------------------

---@class era.view.filetree.ITreeNode
---@field public name                   string
---@field public filepath               string
---@field public nodetype               "directory" | "file"
---@field public children               era.view.filetree.ITreeNode[]
---@field public data                   unknown|nil

---@class era.view.filetree.IFileItem
---@field public filepath               string
---@field public data                   unknown|nil

---@class era.view.filetree.ILineMapItem
---@field public nodetype               "directory" | "file"
---@field public filepath               string
---@field public data                   unknown|nil

---@alias era.view.filetree.IDirectoryRenderer fun(node: era.view.filetree.ITreeNode, lnum: integer, indent: string): string, stl.t.IHighlight[]

---@alias era.view.filetree.IFileRenderer fun(node: era.view.filetree.ITreeNode, lnum: integer, indent: string): string, stl.t.IHighlight[]

---@alias era.view.filetree.IIsCollapsed fun(node: era.view.filetree.ITreeNode): boolean

---@class era.view.filetree.IRenderOpts
---@field public foldempty              boolean|nil
---@field public base_indent            string|nil
---@field public start_lnum             integer|nil
---@field public render_directory       era.view.filetree.IDirectoryRenderer|nil
---@field public render_file            era.view.filetree.IFileRenderer|nil
---@field public is_collapsed           era.view.filetree.IIsCollapsed|nil

---@class era.view.filetree.IRenderResult
---@field public lines                  string[]
---@field public highlights             stl.t.IHighlight[]
---@field public line_map               era.view.filetree.ILineMapItem[]

----------------------------------------------------------------------------------------------------
-- Tree building
----------------------------------------------------------------------------------------------------

---Build a tree structure from file items
---@param items                         era.view.filetree.IFileItem[]
---@return era.view.filetree.ITreeNode
function M.build_tree(items)
  ---@type era.view.filetree.ITreeNode
  local root = {
    name = "",
    filepath = "",
    nodetype = "directory",
    children = {},
    data = nil,
  }

  for _, item in ipairs(items) do
    local filepath = item.filepath ---@type string
    local parts = vim.split(filepath, "/", { plain = true }) ---@type string[]
    local current = root ---@type era.view.filetree.ITreeNode

    for i = 1, #parts - 1 do
      local part = parts[i] ---@type string
      local dir_path = table.concat(parts, "/", 1, i) ---@type string
      local found = false ---@type boolean

      for _, child in ipairs(current.children) do
        if child.nodetype == "directory" and child.name == part then
          current = child
          found = true
          break
        end
      end

      if not found then
        ---@type era.view.filetree.ITreeNode
        local dir_node = {
          name = part,
          filepath = dir_path,
          nodetype = "directory",
          children = {},
          data = nil,
        }
        current.children[#current.children + 1] = dir_node
        current = dir_node
      end
    end

    ---@type era.view.filetree.ITreeNode
    local file_node = {
      name = parts[#parts],
      filepath = filepath,
      nodetype = "file",
      children = {},
      data = item.data,
    }
    current.children[#current.children + 1] = file_node
  end

  return root
end

---Sort tree children (directories first, then alphabetically)
---@param node                          era.view.filetree.ITreeNode
function M.sort_tree(node)
  if #node.children == 0 then
    return
  end

  table.sort(node.children, function(a, b)
    if a.nodetype ~= b.nodetype then
      return a.nodetype == "directory"
    end
    return a.name < b.name
  end)

  for _, child in ipairs(node.children) do
    if child.nodetype == "directory" then
      M.sort_tree(child)
    end
  end
end

---Fold empty directories (single child directory becomes "dir1/dir2")
---@param node                          era.view.filetree.ITreeNode
---@return era.view.filetree.ITreeNode
---@return string
function M.fold_empty_dirs(node)
  local path_parts = { node.name } ---@type string[]
  local current = node ---@type era.view.filetree.ITreeNode

  while true do
    if #current.children ~= 1 then
      break
    end

    local child = current.children[1] ---@type era.view.filetree.ITreeNode
    if child.nodetype ~= "directory" then
      break
    end

    path_parts[#path_parts + 1] = child.name
    current = child
  end

  if #path_parts == 1 then
    return node, node.name
  end

  return current, table.concat(path_parts, "/")
end

----------------------------------------------------------------------------------------------------
-- Default renderers
----------------------------------------------------------------------------------------------------

---Default directory renderer
---@param node                          era.view.filetree.ITreeNode
---@param lnum                          integer
---@param indent                        string
---@return string, stl.t.IHighlight[]
local function default_render_directory(node, lnum, indent)
  local icon = stl.icon.filetype.FolderOpen ---@type string
  local line = indent .. icon .. " " .. node.name ---@type string

  local col = #indent ---@type integer
  local highlights = {} ---@type stl.t.IHighlight[]

  -- Highlight indent
  highlights[#highlights + 1] = {
    hlname = "f_utw_indent",
    lnum = lnum,
    coll = 0,
    colr = col,
  }

  -- Highlight icon
  highlights[#highlights + 1] = {
    hlname = "Directory",
    lnum = lnum,
    coll = col,
    colr = col + #icon,
  }
  col = col + #icon + 1

  -- Highlight name
  highlights[#highlights + 1] = {
    hlname = "Directory",
    lnum = lnum,
    coll = col,
    colr = #line,
  }

  return line, highlights
end

---Default file renderer
---@param node                          era.view.filetree.ITreeNode
---@param lnum                          integer
---@param indent                        string
---@return string, stl.t.IHighlight[]
local function default_render_file(node, lnum, indent)
  local fileicon, fileicon_hln = stl.fileicon.get_file_icon(node.name)
  local line = indent .. fileicon .. " " .. node.name ---@type string

  local col = #indent ---@type integer
  local highlights = {} ---@type stl.t.IHighlight[]

  -- Highlight indent
  highlights[#highlights + 1] = {
    hlname = "f_utw_indent",
    lnum = lnum,
    coll = 0,
    colr = col,
  }

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
    hlname = "Normal",
    lnum = lnum,
    coll = col,
    colr = #line,
  }

  return line, highlights
end

----------------------------------------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------------------------------------

---@class era.view.filetree.IRenderContext
---@field public lines                  string[]
---@field public highlights             stl.t.IHighlight[]
---@field public line_map               era.view.filetree.ILineMapItem[]
---@field public base_indent            string
---@field public start_lnum             integer
---@field public foldempty              boolean
---@field public render_directory       era.view.filetree.IDirectoryRenderer
---@field public render_file            era.view.filetree.IFileRenderer
---@field public is_collapsed           era.view.filetree.IIsCollapsed|nil

---Render tree nodes recursively
---@param ctx                           era.view.filetree.IRenderContext
---@param node                          era.view.filetree.ITreeNode
---@param prefix                        string
---@param is_last                       boolean
---@param display_name                  string|nil
local function render_tree_node(ctx, node, prefix, is_last, display_name)
  local lnum = ctx.start_lnum + #ctx.lines ---@type integer

  local indent ---@type string
  if prefix == "" then
    indent = ctx.base_indent .. (is_last and INDENT_LAST or INDENT_BRANCH)
  else
    indent = ctx.base_indent .. prefix .. (is_last and INDENT_LAST or INDENT_BRANCH)
  end

  -- Create a temporary node with display_name if provided
  local render_node = node ---@type era.view.filetree.ITreeNode
  if display_name then
    render_node = {
      name = display_name,
      filepath = node.filepath,
      nodetype = node.nodetype,
      children = node.children,
      data = node.data,
    }
  end

  if node.nodetype == "directory" then
    local line, highlights = ctx.render_directory(render_node, lnum, indent)
    ctx.lines[#ctx.lines + 1] = line
    vim.list_extend(ctx.highlights, highlights)
    ctx.line_map[#ctx.line_map + 1] = {
      nodetype = "directory",
      filepath = node.filepath,
      data = node.data,
    }

    -- Skip children if collapsed
    if ctx.is_collapsed and ctx.is_collapsed(node) then
      return
    end

    -- Render children
    local child_prefix = prefix .. (is_last and INDENT_SPACE or INDENT_PIPE) ---@type string
    local N = #node.children ---@type integer

    for i, child in ipairs(node.children) do
      local child_display_name = nil ---@type string|nil

      if ctx.foldempty and child.nodetype == "directory" then
        local folded_node, folded_path = M.fold_empty_dirs(child)
        if folded_node ~= child then
          child = folded_node
          child_display_name = folded_path
        end
      end

      render_tree_node(ctx, child, child_prefix, i == N, child_display_name)
    end
  else
    local line, highlights = ctx.render_file(render_node, lnum, indent)
    ctx.lines[#ctx.lines + 1] = line
    vim.list_extend(ctx.highlights, highlights)
    ctx.line_map[#ctx.line_map + 1] = {
      nodetype = "file",
      filepath = node.filepath,
      data = node.data,
    }
  end
end

---Render file items as a tree
---@param items                         era.view.filetree.IFileItem[]
---@param opts                          era.view.filetree.IRenderOpts|nil
---@return era.view.filetree.IRenderResult
function M.render(items, opts)
  opts = opts or {}

  local tree = M.build_tree(items)
  M.sort_tree(tree)

  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local line_map = {} ---@type era.view.filetree.ILineMapItem[]

  ---@type era.view.filetree.IRenderContext
  local ctx = {
    lines = lines,
    highlights = highlights,
    line_map = line_map,
    base_indent = opts.base_indent or "",
    start_lnum = opts.start_lnum or 0,
    foldempty = opts.foldempty ~= false,
    render_directory = opts.render_directory or default_render_directory,
    render_file = opts.render_file or default_render_file,
    is_collapsed = opts.is_collapsed,
  }

  local N = #tree.children ---@type integer
  for i, child in ipairs(tree.children) do
    local child_display_name = nil ---@type string|nil

    if ctx.foldempty and child.nodetype == "directory" then
      local folded_node, folded_path = M.fold_empty_dirs(child)
      if folded_node ~= child then
        child = folded_node
        child_display_name = folded_path
      end
    end

    render_tree_node(ctx, child, "", i == N, child_display_name)
  end

  return {
    lines = lines,
    highlights = highlights,
    line_map = line_map,
  }
end

---Apply render result to buffer
---@param bufnr                         integer
---@param result                        era.view.filetree.IRenderResult
---@param start_line                    integer|nil                       0-indexed line to start writing (default 0)
---@param ns                            integer|nil                       namespace id (default 0)
function M.apply_to_buffer(bufnr, result, start_line, ns)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  start_line = start_line or 0
  ns = ns or 0

  -- Set lines
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, start_line, start_line + #result.lines, false, result.lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Apply highlights
  for _, hl in ipairs(result.highlights) do
    vim.hl.range(bufnr, ns, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end
end

return M
