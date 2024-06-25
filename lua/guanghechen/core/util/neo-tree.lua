-- https://github.com/nvim-neo-tree/neo-tree.nvim/wiki/Recipes#emulating-vims-fold-commands
-- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/25bfdbe802eb913276bb83874b043be57bd70347/lua/neo-tree/sources/filesystem/init.lua#L389

local fs = require("neo-tree.sources.filesystem")
local commands = require("neo-tree.sources.common.commands")
local renderer = require("neo-tree.ui.renderer")

-- Expand a node and load filesystem info if needed.
local function open_dir(state, dir_node)
  fs.toggle_directory(state, dir_node, nil, true, false)
end

-- Expand a node and all its children, optionally stopping at max_depth.
local function recursive_open(state, node, depth, max_depth)
  if max_depth ~= nil and depth >= max_depth then
    return
  end

  if node.type == "directory" and not node:is_expanded() then
    open_dir(state, node)
  end

  local children = state.tree:get_nodes(node:get_id())
  for _, child in ipairs(children) do
    recursive_open(state, child, depth + 1, max_depth)
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
  if not node then
    return
  end

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
  if not node then
    return
  end

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
