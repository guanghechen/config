local treeview_layout = require("stl.view.treeview.layout")

---@class era.view.filetree
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

local INDENT_BRANCH = "├─" ---@type string
local INDENT_LAST = "╰─" ---@type string
local INDENT_PIPE = "│ " ---@type string
local INDENT_SPACE = "  " ---@type string
local EMPTY_CHILDREN = {} ---@type era.view.filetree.ITreeNode[]

----------------------------------------------------------------------------------------------------
-- Types
----------------------------------------------------------------------------------------------------

---@class era.view.filetree.ITreeNode
---@field public name                   string
---@field public filepath               string
---@field public nodetype               "directory" | "file"
---@field public children               era.view.filetree.ITreeNode[]
---@field public data                   unknown|nil

---@alias era.view.filetree.INodeMap table<string, era.view.filetree.ITreeNode>

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
---@field public layout                 stl.view.TreeLayout

----------------------------------------------------------------------------------------------------
-- Tree building
----------------------------------------------------------------------------------------------------

---Build a tree structure from file items
---@param items                         era.view.filetree.IFileItem[]
---@return era.view.filetree.ITreeNode
---@return era.view.filetree.INodeMap
function M.build_tree(items)
  ---@type era.view.filetree.ITreeNode
  local root = {
    name = "",
    filepath = "",
    nodetype = "directory",
    children = {},
    data = nil,
  }
  local node_map = { [root.filepath] = root } ---@type era.view.filetree.INodeMap

  for _, item in ipairs(items) do
    local filepath = item.filepath ---@type string
    local parts = vim.split(filepath, "/", { plain = true }) ---@type string[]
    local current = root ---@type era.view.filetree.ITreeNode
    local dir_path = "" ---@type string

    for i = 1, #parts - 1 do
      local part = parts[i] ---@type string
      dir_path = dir_path == "" and part or (dir_path .. "/" .. part)
      local dir_node = node_map[dir_path] ---@type era.view.filetree.ITreeNode|nil
      if dir_node == nil then
        ---@type era.view.filetree.ITreeNode
        dir_node = {
          name = part,
          filepath = dir_path,
          nodetype = "directory",
          children = {},
          data = nil,
        }
        current.children[#current.children + 1] = dir_node
        node_map[dir_path] = dir_node
      elseif dir_node.nodetype ~= "directory" then
        error(string.format("[era.view.filetree] path '%s' is both a file and a directory", dir_path))
      end
      current = dir_node
    end

    local existing = node_map[filepath] ---@type era.view.filetree.ITreeNode|nil
    if existing ~= nil then
      local reason = existing.nodetype == "directory" and "is both a file and a directory" or "appears more than once"
      error(string.format("[era.view.filetree] path '%s' %s", filepath, reason))
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
    node_map[filepath] = file_node
  end

  return root, node_map
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

---Render file items as a tree
---@param items                         era.view.filetree.IFileItem[]
---@param opts                          era.view.filetree.IRenderOpts|nil
---@return era.view.filetree.IRenderResult
function M.render(items, opts)
  opts = opts or {}

  local tree, node_map = M.build_tree(items)
  M.sort_tree(tree)

  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  local line_map = {} ---@type era.view.filetree.ILineMapItem[]

  local is_collapsed = opts.is_collapsed ---@type era.view.filetree.IIsCollapsed|nil
  local can_fold = nil ---@type (fun(parent: era.view.filetree.ITreeNode, child: era.view.filetree.ITreeNode): boolean)|nil
  if opts.foldempty ~= false then
    can_fold = function(_, child)
      return child.nodetype == "directory"
    end
  end

  local layout = treeview_layout.layout({
    roots = tree.children,
    id = function(node)
      return node.filepath
    end,
    children = function(node)
      if node.nodetype == "directory" and is_collapsed ~= nil and is_collapsed(node) then
        return EMPTY_CHILDREN
      end
      return node.children
    end,
    can_fold = can_fold,
  })

  local base_indent = opts.base_indent or "" ---@type string
  local start_lnum = opts.start_lnum or 0 ---@type integer
  local render_directory = opts.render_directory or default_render_directory ---@type era.view.filetree.IDirectoryRenderer
  local render_file = opts.render_file or default_render_file ---@type era.view.filetree.IFileRenderer
  local prefixes = { [0] = "" } ---@type table<integer, string>

  for row = 1, layout:len() do
    local depth = layout:depth(row) ---@type integer
    local prefix = prefixes[depth] ---@type string
    local is_last = layout:is_last(row) ---@type boolean
    local indent = base_indent .. prefix .. (is_last and INDENT_LAST or INDENT_BRANCH) ---@type string
    prefixes[depth + 1] = prefix .. (is_last and INDENT_SPACE or INDENT_PIPE)

    local id = layout:id(row) ---@type string
    local node = node_map[id] ---@type era.view.filetree.ITreeNode
    local render_node = node ---@type era.view.filetree.ITreeNode
    local folded_ids = layout:folded_ids(row) ---@type string[]|nil
    if folded_ids ~= nil then
      local names = {} ---@type string[]
      for index, folded_id in ipairs(folded_ids) do
        names[index] = node_map[folded_id].name
      end
      render_node = {
        name = table.concat(names, "/"),
        filepath = node.filepath,
        nodetype = node.nodetype,
        children = node.children,
        data = node.data,
      }
    end

    local lnum = start_lnum + row - 1 ---@type integer
    local line, line_highlights ---@type string, stl.t.IHighlight[]
    if node.nodetype == "directory" then
      line, line_highlights = render_directory(render_node, lnum, indent)
    else
      line, line_highlights = render_file(render_node, lnum, indent)
    end

    lines[row] = line
    vim.list_extend(highlights, line_highlights)
    line_map[row] = {
      nodetype = node.nodetype,
      filepath = node.filepath,
      data = node.data,
    }
  end

  return {
    lines = lines,
    highlights = highlights,
    line_map = line_map,
    layout = layout,
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

----------------------------------------------------------------------------------------------------
-- File list extraction (in-order traversal)
----------------------------------------------------------------------------------------------------

---Collect files in tree traversal order (directories first, then files, alphabetically)
---@param node                          era.view.filetree.ITreeNode
---@param result                        era.view.filetree.IFileItem[]
local function collect_files_inorder(node, result)
  for _, child in ipairs(node.children) do
    if child.nodetype == "directory" then
      collect_files_inorder(child, result)
    else
      result[#result + 1] = {
        filepath = child.filepath,
        data = child.data,
      }
    end
  end
end

---Get files sorted in tree traversal order (same order as tree view rendering)
---@param items                         era.view.filetree.IFileItem[]
---@return era.view.filetree.IFileItem[]
function M.get_sorted_files(items)
  local tree = M.build_tree(items)
  M.sort_tree(tree)

  local result = {} ---@type era.view.filetree.IFileItem[]
  collect_files_inorder(tree, result)
  return result
end

----------------------------------------------------------------------------------------------------
-- Tree navigation
----------------------------------------------------------------------------------------------------

---Get tree depth level of a line by counting tree structure characters.
---Tree structure patterns (each represents one depth level):
---  "├─" = branch with siblings (3 bytes + 3 bytes = 6 bytes)
---  "╰─" = last child branch (3 bytes + 3 bytes = 6 bytes)
---  "│ " = vertical line continuation (3 bytes + 1 byte space = 4 bytes)
---  "  " = empty indent (2 bytes, used after ╰─ for child continuation)
---@param line                          string
---@param base_indent_len               integer                             bytes of base indent before tree structure
---@return integer                      depth (0 if no tree structure found)
function M.get_tree_depth(line, base_indent_len)
  local depth = 0 ---@type integer
  local i = base_indent_len + 1
  local len = #line

  while i <= len do
    -- Try to match 6-byte patterns first: "├─" or "╰─"
    local c6 = line:sub(i, i + 5)
    if c6 == INDENT_BRANCH or c6 == INDENT_LAST then
      depth = depth + 1
      i = i + 6
    else
      -- Try to match 4-byte pattern: "│ " (vertical line + space)
      local c4 = line:sub(i, i + 3)
      if c4 == INDENT_PIPE then
        depth = depth + 1
        i = i + 4
      elseif line:sub(i, i + 1) == INDENT_SPACE then
        -- Two spaces indicate continuation indent (after ╰─)
        depth = depth + 1
        i = i + 2
      else
        -- Reached non-tree content (actual text starts here)
        break
      end
    end
  end

  return depth
end

---Go to parent node in tree (line with smaller depth).
---@param base_indent_len               integer                             bytes of base indent before tree structure
function M.goto_parent_node(base_indent_len)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local lnum_cur = cursor[1] ---@type integer
  local line_cur = vim.fn.getline(lnum_cur) ---@type string
  local depth_cur = M.get_tree_depth(line_cur, base_indent_len) ---@type integer

  if depth_cur <= 0 then
    return
  end

  -- Search upward for a line with smaller depth
  for lnum = lnum_cur - 1, 1, -1 do
    local line = vim.fn.getline(lnum) ---@type string
    local depth = M.get_tree_depth(line, base_indent_len) ---@type integer
    if depth < depth_cur then
      -- Position cursor at the start of the content (after tree structure)
      local content_start = line:find("[^ │├╰─]") or 1
      vim.api.nvim_win_set_cursor(winnr, { lnum, content_start - 1 })
      return
    end
  end
end

---Go to last direct child node or last sibling if on a leaf node.
---@param base_indent_len               integer                             bytes of base indent before tree structure
function M.goto_last_child_or_sibling(base_indent_len)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local N = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local lnum_cur = cursor[1] ---@type integer
  local line_cur = vim.fn.getline(lnum_cur) ---@type string
  local depth_cur = M.get_tree_depth(line_cur, base_indent_len) ---@type integer

  -- First, check if we have children (next line has greater depth)
  local next_lnum = lnum_cur + 1
  if next_lnum <= N then
    local next_line = vim.fn.getline(next_lnum) ---@type string
    local next_depth = M.get_tree_depth(next_line, base_indent_len) ---@type integer
    if next_depth > depth_cur then
      -- We have children, find the last DIRECT child (depth = depth_cur + 1)
      local child_depth = depth_cur + 1
      local last_child_lnum = next_lnum
      for lnum = next_lnum + 1, N, 1 do
        local line = vim.fn.getline(lnum) ---@type string
        local depth = M.get_tree_depth(line, base_indent_len) ---@type integer
        if depth <= depth_cur then
          -- Reached parent level or end, stop
          break
        elseif depth == child_depth then
          -- Found another direct child at the same level
          last_child_lnum = lnum
        end
        -- depth > child_depth means we're inside a subtree of a child, keep searching
      end
      local last_child_line = vim.fn.getline(last_child_lnum) ---@type string
      local content_start = last_child_line:find("[^ │├╰─]") or 1
      vim.api.nvim_win_set_cursor(winnr, { last_child_lnum, content_start - 1 })
      return
    end
  end

  -- No children (leaf node), find last sibling
  -- Siblings have the same depth and share the same parent
  local last_sibling_lnum = lnum_cur
  for lnum = lnum_cur + 1, N, 1 do
    local line = vim.fn.getline(lnum) ---@type string
    local depth = M.get_tree_depth(line, base_indent_len) ---@type integer
    if depth < depth_cur then
      -- Reached parent level or end, stop
      break
    elseif depth == depth_cur then
      -- Found a sibling
      last_sibling_lnum = lnum
    end
    -- depth > depth_cur means we're inside a subtree of a sibling, keep searching
  end

  if last_sibling_lnum ~= lnum_cur then
    local last_sibling_line = vim.fn.getline(last_sibling_lnum) ---@type string
    local content_start = last_sibling_line:find("[^ │├╰─]") or 1
    vim.api.nvim_win_set_cursor(winnr, { last_sibling_lnum, content_start - 1 })
  end
end

return M
