---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.pane.filetree" ---@type string

local tree = require("era.m.diffview.pane.tree")
local config = require("era.m.diffview.config")

---Generic filetree pane for diffview.
---Used for commits expanded files in layout 5 (commits + filetree).
---@class era.m.diffview.pane.filetree
local M = {}

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

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

M.apply_to_buffer = tree.apply
M.get_item_at_line = tree.item
M.get_navigation = tree.navigation
M.resolve_parent_lnum = tree.parent
M.resolve_last_child_or_sibling_lnum = tree.last_child

---@param entries                       era.m.diffview.IFileEntry[]
---@param opts                          ?table
---@return table
function M.render(entries, opts)
  local plan = tree.plan(opts)
  tree.files(plan, entries)
  return plan
end

---@param bufnr                         integer
---@param lnum                          integer
---@return era.m.diffview.IFileEntry|nil
function M.get_entry_at_line(bufnr, lnum)
  local item = tree.item(bufnr, lnum)
  return item and item.entry
end

---@param bufnr                         integer
---@param filepath                      string
---@return integer|nil
function M.find_entry_line(bufnr, filepath)
  local owner = tree.owner(bufnr)
  return owner and owner:retrieve_lnum(tree.key(nil, filepath, false))
end

---A collapsed file is anchored to its nearest visible ancestor in this Frame.
---@param bufnr                         integer
---@param filepath                      string
---@return integer|nil
function M.find_entry_anchor(bufnr, filepath)
  local frame = tree.navigation(bufnr)
  local id = frame and frame:source():id(tree.key(nil, filepath, false))
  while id do
    local row = frame:position(id)
    if row then
      return row
    end
    id = frame:node(id).parent
  end
end

---@param bufnr                         integer
---@param lnum                          ?integer Nil starts at the first/last row.
---@param direction                     1|-1
---@return integer|nil
---@return era.m.diffview.IFileEntry|nil
function M.find_adjacent_entry(bufnr, lnum, direction)
  local frame = tree.navigation(bufnr)
  local row = frame and frame:adjacent_leaf(lnum, direction == 1)
  local item = row and tree.item(bufnr, row)
  return row, item and item.entry
end

---@param bufnr                         integer
---@param lnum                          integer
---@return boolean
function M.toggle_collapse(bufnr, lnum)
  local item, owner = tree.item(bufnr, lnum), tree.owner(bufnr)
  if not owner or not item or item.type ~= "directory" then
    return false
  end
  owner:collapse(owner:retrieve_uuid(lnum), "toggle", false)
  return true
end

---@param bufnr                         integer
---@param lnum                          integer
---@return boolean
function M.is_directory(bufnr, lnum)
  local item = tree.item(bufnr, lnum)
  return item ~= nil and item.type == "directory"
end

---@return nil
function M.goto_parent_node()
  tree.navigate("parent")
end

---@return nil
function M.goto_last_child_or_sibling()
  tree.navigate("last_child_or_sibling")
end

return M
