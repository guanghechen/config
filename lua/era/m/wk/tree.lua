local S = era.m.wk

---@class era.m.wk.tree
local M = {}

---Create a new tree
---@return table<string, era.m.wk.INode>
function M.new()
  return {}
end

---Add mapping to tree
---@param tree_tbl                      table<string, era.m.wk.INode>
---@param mapping                       era.m.wk.IMapping
function M.add(tree_tbl, mapping)
  local lhs = mapping[1]
  if not lhs or lhs == "" then
    return
  end

  local rhs = mapping[2]
  local parts = S.util.parse_keys(lhs)
  local current = tree_tbl

  for i, key in ipairs(parts) do
    if not current[key] then
      current[key] = {
        key = key,
        lhs = table.concat(parts, "", 1, i),
        desc = "",
        icon = nil,
        is_group = false,
        rhs = nil,
        action = nil,
        nowait = nil,
        proxy = nil,
        expand = nil,
        children = {},
      }
    end

    local node = current[key]

    if i == #parts then
      if mapping.group then
        node.is_group = true
        node.desc = mapping.group
      else
        -- Distinguish between action (function from wk spec) and rhs (string for feedkeys)
        if type(rhs) == "function" then
          node.action = rhs
          node.desc = mapping.desc or ""
        elseif type(rhs) == "string" then
          node.rhs = rhs
          node.desc = mapping.desc or rhs
        else
          node.desc = mapping.desc or ""
        end
      end
      node.icon = mapping.icon or node.icon
      node.nowait = mapping.nowait or node.nowait
      node.proxy = mapping.proxy or node.proxy
      node.expand = mapping.expand or node.expand
    else
      if not node.is_group and not node.rhs and not node.action then
        node.is_group = true
        node.desc = node.desc ~= "" and node.desc or key
      end
    end

    current = node.children
  end
end

---Find node by key sequence
---@param tree_tbl                      table<string, era.m.wk.INode>
---@param keys                          string
---@return era.m.wk.INode|nil
function M.find(tree_tbl, keys)
  if not keys or keys == "" then
    return nil
  end

  local parts = S.util.parse_keys(keys)
  local current = tree_tbl

  for i, key in ipairs(parts) do
    if not current[key] then
      return nil
    end
    if i == #parts then
      return current[key]
    end
    current = current[key].children
  end

  return nil
end

---Get children of a node, including proxy mappings
---@param tree_tbl                      table<string, era.m.wk.INode>
---@param keys                          string
---@param mode                          era.m.wk.Mode
---@return table<string, era.m.wk.INode>
function M.get_children(tree_tbl, keys, mode)
  local result = M.__children__(tree_tbl, keys)

  local node = M.find(tree_tbl, keys)
  if node and node.proxy then
    local global_maps = vim.api.nvim_get_keymap(mode)
    local buf_maps = vim.api.nvim_buf_get_keymap(0, mode)
    local all_maps = vim.list_extend(global_maps, buf_maps)

    for _, km in ipairs(all_maps) do
      if vim.startswith(km.lhs, node.proxy) then
        local rel = km.lhs:sub(#node.proxy + 1)
        if rel ~= "" and not result[rel] then
          result[rel] = {
            key = rel,
            lhs = keys .. rel,
            desc = km.desc or (type(km.rhs) == "string" and km.rhs) or km.lhs or "",
            icon = nil,
            is_group = false,
            rhs = nil, -- don't save callback, use feedkeys
            action = nil,
            proxy = nil,
            expand = nil,
            children = {},
          }
        end
      end
    end
  end

  return result
end

----------------------------------------------------------------------------------------------------
-- Protected
----------------------------------------------------------------------------------------------------

---Get direct children of a node
---@param tree_tbl                      table<string, era.m.wk.INode>
---@param keys                          string
---@return table<string, era.m.wk.INode>
function M.__children__(tree_tbl, keys)
  if not keys or keys == "" then
    return tree_tbl
  end

  local parts = S.util.parse_keys(keys)
  local current = tree_tbl

  for _, key in ipairs(parts) do
    if not current[key] then
      return {}
    end
    current = current[key].children
  end

  return current
end

return M
