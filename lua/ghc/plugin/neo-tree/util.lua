-- See https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#emulating-vims-fold-commands

local fs_scan = require("neo-tree.sources.filesystem.lib.fs_scan")
local commands = require("neo-tree.sources.common.commands")
local renderer = require("neo-tree.ui.renderer")

---Expands or collapses the current node.
local function expand_directory(state, node)
  if not node or node.type ~= "directory" then
    return
  end

  state.explicitly_opened_directories = state.explicitly_opened_directories or {}
  if node.loaded == false then
    local id = node:get_id()
    state.explicitly_opened_directories[id] = true
    renderer.position.set(state, nil)
    fs_scan.get_items(state, id, nil, nil, false, false)
  elseif node:has_children() then
    if not node:is_expanded() then
      node:expand()
      state.explicitly_opened_directories[node:get_id()] = true
    end
  elseif require("neo-tree").config.filesystem.scan_mode == "deep" then
    node.empty_expanded = not node.empty_expanded
    renderer.redraw(state)
  end
end

-- Expand a node and all its children, optionally stopping at max_depth.
local function recursive_open(state, node, depth, max_depth)
  if max_depth ~= nil and depth >= max_depth then
    return
  end

  if not node then
    local tree = state.tree
    node = tree.get_node()
  end

  expand_directory(state, node)

  if node and node:has_children() then
    local children = state.tree:get_nodes(node:get_id())
    for _, child in ipairs(children) do
      recursive_open(state, child, depth + 1, max_depth)
    end
  end
end

--- Close the node and its children, optionally stopping at max_depth.
local function recursive_close(state, node, depth, max_depth)
  if max_depth ~= nil and depth >= max_depth then
    return
  end

  if node and node:has_children() then
    local children = state.tree:get_nodes(node:get_id())
    for _, child in ipairs(children) do
      recursive_close(state, child, depth + 1, max_depth)
    end
  end

  if node and node.type == "directory" then
    node:collapse()
  end
end

--- Open the fold under the cursor, recursing if count is given.
local function neotree_zo(state, toggle_directory, open_all)
  local node = state.tree:get_node()

  if node and node.type == "file" then
    commands.open(state, toggle_directory)
  end

  if open_all then
    recursive_open(state, node, 0, nil)
  else
    recursive_open(state, node, 0, vim.v.count1 or 1)
  end

  renderer.redraw(state)
end

--- Close a folder, or a number of folders equal to count.
local function neotree_zc(state, close_all)
  local node = state.tree:get_node()

  if close_all then
    recursive_close(state, node, 0, nil)
  else
    recursive_close(state, node, 0, vim.v.count1 or 1)
  end

  renderer.redraw(state)
end

--- Open a closed folder or close an open one, with an optional count.
local function neotree_za(state, toggle_directory, toggle_all)
  local node = state.tree:get_node()
  if not node then
    return
  end

  if node.type == "directory" then
    if node:is_expanded() then
      neotree_zc(state, toggle_all)
    else
      neotree_zo(state, toggle_directory, toggle_all)
    end
  else
    commands.open(state, toggle_directory)
  end
end

return {
  neotree_recursive_open = neotree_zo,
  neotree_recursive_toggle = neotree_za,
}
