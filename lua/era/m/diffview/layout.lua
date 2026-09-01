---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.layout" ---@type string

---Tree-based window layout utility for diffview.
---@class era.m.diffview.layout
local M = {}

---@type table<"down"|"up", string>
local MOUSE_SCROLL_KEYS = {
  down = "\5", -- <C-e>
  up = "\25", -- <C-y>
}

----------------------------------------------------------------------------------------------------
-- Types
----------------------------------------------------------------------------------------------------

---@alias era.m.diffview.layout.Direction "horizontal"|"vertical"

---@class era.m.diffview.layout.ILeafNode
---@field public id                     string                          unique pane identifier
---@field public size                   number|nil                      relative size (0-1) or nil for remaining

---@class era.m.diffview.layout.ISplitNode
---@field public dir                    era.m.diffview.layout.Direction
---@field public children               era.m.diffview.layout.INode[]
---@field public size                   number|nil                      relative size (0-1) or nil for remaining

---@alias era.m.diffview.layout.INode era.m.diffview.layout.ILeafNode|era.m.diffview.layout.ISplitNode

---@class era.m.diffview.layout.ICreateResult
---@field public winnrs                 table<string, integer>          map from pane id to winnr
---@field public all_winnrs             integer[]                       all winnrs in creation order

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

---Check if node is a leaf node
---@param node                          era.m.diffview.layout.INode
---@return boolean
local function is_leaf(node)
  return node.id ~= nil
end

---Calculate window size based on relative size and total available
---@param size                          number|nil
---@param total                         integer
---@return integer|nil
local function calc_size(size, total)
  if not size then
    return nil
  end
  return math.floor(total * size)
end

----------------------------------------------------------------------------------------------------
-- Core layout creation
----------------------------------------------------------------------------------------------------

---Create windows from a layout tree node recursively.
---@param node                          era.m.diffview.layout.INode
---@param winnr                         integer                         current window to split from
---@param result                        era.m.diffview.layout.ICreateResult
---@param is_first                      boolean                         whether this is the first child
---@param dir                           era.m.diffview.layout.Direction|nil parent direction
---@param total_size                    integer                         total available size for this node
---@diagnostic disable-next-line: unused-local
local function create_node(node, winnr, result, is_first, dir, total_size)
  if is_leaf(node) then
    ---@cast node era.m.diffview.layout.ILeafNode
    result.winnrs[node.id] = winnr
    table.insert(result.all_winnrs, winnr)
    return
  end

  ---@cast node era.m.diffview.layout.ISplitNode
  local children = node.children
  if #children == 0 then
    return
  end

  local split_dir = node.dir
  local is_horizontal = split_dir == "horizontal"

  -- Get available size for children
  local avail_size = is_horizontal and vim.api.nvim_win_get_width(winnr) or vim.api.nvim_win_get_height(winnr)

  -- First child uses current window
  local current_winnr = winnr
  for i, child in ipairs(children) do
    if i == 1 then
      -- First child uses current window
      local child_size = calc_size(child.size, avail_size)
      create_node(child, current_winnr, result, true, split_dir, child_size or avail_size)
    else
      -- Subsequent children need to split
      local child_size = calc_size(child.size, avail_size)
      local split_cmd = is_horizontal and "rightbelow vsplit" or "rightbelow split"

      vim.api.nvim_win_call(current_winnr, function()
        vim.cmd(split_cmd)
        current_winnr = vim.api.nvim_get_current_win()
        if child_size then
          if is_horizontal then
            vim.api.nvim_win_set_width(current_winnr, child_size)
          else
            vim.api.nvim_win_set_height(current_winnr, child_size)
          end
        end
      end)

      create_node(child, current_winnr, result, false, split_dir, child_size or avail_size)
    end
  end
end

---Create windows from a layout tree.
---@param tree                          era.m.diffview.layout.INode     layout tree description
---@param pivot_winnr                   integer                         starting window (will be reused)
---@return era.m.diffview.layout.ICreateResult
function M.create(tree, pivot_winnr)
  local result = {
    winnrs = {},
    all_winnrs = {},
  } ---@type era.m.diffview.layout.ICreateResult

  local total_width = vim.api.nvim_win_get_width(pivot_winnr)
  create_node(tree, pivot_winnr, result, true, nil, total_width)

  return result
end

----------------------------------------------------------------------------------------------------
-- Predefined layouts
----------------------------------------------------------------------------------------------------

---Create a horizontal split layout: [left | right]
---@param left_id                       string
---@param right_id                      string
---@param left_size                     number|nil                      0-1 relative size for left pane
---@return era.m.diffview.layout.ISplitNode
function M.horizontal(left_id, right_id, left_size)
  return {
    dir = "horizontal",
    children = {
      { id = left_id, size = left_size },
      { id = right_id },
    },
  }
end

---Create a vertical split layout: [top] / [bottom]
---@param top_id                        string
---@param bottom_id                     string
---@param top_size                      number|nil                      0-1 relative size for top pane
---@return era.m.diffview.layout.ISplitNode
function M.vertical(top_id, bottom_id, top_size)
  return {
    dir = "vertical",
    children = {
      { id = top_id, size = top_size },
      { id = bottom_id },
    },
  }
end

---Create a side-by-side diff layout: [left | right] for diff
---@param left_id                       string
---@param right_id                      string
---@return era.m.diffview.layout.ISplitNode
function M.sbs(left_id, right_id)
  return {
    dir = "horizontal",
    children = {
      { id = left_id, size = 0.5 },
      { id = right_id },
    },
  }
end

---Create workspace layout: [changes | sbs_left | sbs_right]
---@param changes_width                 number                          0-1 relative width for changes pane
---@return era.m.diffview.layout.ISplitNode
function M.workspace_full(changes_width)
  return {
    dir = "horizontal",
    children = {
      { id = "changes", size = changes_width },
      {
        dir = "horizontal",
        children = {
          { id = "sbs_left", size = 0.5 },
          { id = "sbs_right" },
        },
      },
    },
  }
end

---Create commits layout with panel on top: [commits] / [sbs_left | sbs_right]
---@param commits_height                number                          0-1 relative height for commits pane
---@return era.m.diffview.layout.ISplitNode
function M.commits_top(commits_height)
  return {
    dir = "vertical",
    children = {
      { id = "commits", size = commits_height },
      {
        dir = "horizontal",
        children = {
          { id = "sbs_left", size = 0.5 },
          { id = "sbs_right" },
        },
      },
    },
  }
end

---Create commits layout with panel on left: [commits | sbs_left | sbs_right]
---@param commits_width                 number                          0-1 relative width for commits pane
---@return era.m.diffview.layout.ISplitNode
function M.commits_left(commits_width)
  return {
    dir = "horizontal",
    children = {
      { id = "commits", size = commits_width },
      {
        dir = "horizontal",
        children = {
          { id = "sbs_left", size = 0.5 },
          { id = "sbs_right" },
        },
      },
    },
  }
end

---Create commits + filetree layout: [commits | filetree]
---@return era.m.diffview.layout.ISplitNode
function M.commits_with_filetree()
  return {
    dir = "horizontal",
    children = {
      { id = "commits", size = 0.5 },
      { id = "filetree" },
    },
  }
end

----------------------------------------------------------------------------------------------------
-- Window utilities
----------------------------------------------------------------------------------------------------

---Check if window is valid
---@param winnr                         integer|nil
---@return boolean
function M.is_valid_win(winnr)
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
end

---Close window safely
---@param winnr                         integer|nil
function M.close_win(winnr)
  if M.is_valid_win(winnr) then
    pcall(vim.api.nvim_win_close, winnr, true)
  end
end

---Focus window
---@param winnr                         integer
function M.focus_win(winnr)
  if M.is_valid_win(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

---Get buffer in window
---@param winnr                         integer
---@return integer|nil
function M.get_win_buf(winnr)
  if not M.is_valid_win(winnr) then
    return nil
  end
  return vim.api.nvim_win_get_buf(winnr)
end

---Set buffer in window
---@param winnr                         integer
---@param bufnr                         integer
function M.set_win_buf(winnr, bufnr)
  if M.is_valid_win(winnr) and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
end

---Turn off diff mode for all windows in current tab
function M.diff_off_all()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr)

  for _, winnr in ipairs(winnrs) do
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_option_value("diff", false, { win = winnr, scope = "local" })
    end
  end
end

---Sync scroll for two windows
---@param left_winnr                    integer
---@param right_winnr                   integer
function M.sync_scroll(left_winnr, right_winnr)
  if not M.is_valid_win(left_winnr) or not M.is_valid_win(right_winnr) then
    return
  end

  -- Trigger scrollbind sync
  vim.api.nvim_win_call(left_winnr, function()
    vim.cmd("normal! \14\25") -- <C-e><C-y>
  end)
end

---Scroll the window under the mouse while preserving the currently focused window.
---@param direction                     "down"|"up"
function M.scroll_mouse(direction)
  local key = MOUSE_SCROLL_KEYS[direction]
  if not key then
    return
  end

  local winnr = vim.fn.getmousepos().winid ---@type integer
  if winnr == 0 or not M.is_valid_win(winnr) then
    return
  end

  local mousescroll = vim.api.nvim_get_option_value("mousescroll", { scope = "global" }) ---@type string
  local lines = tonumber(mousescroll:match("ver:(%d+)")) or 3 ---@type integer
  if lines <= 0 then
    return
  end

  vim.api.nvim_win_call(winnr, function()
    vim.cmd(("normal! %d%s"):format(lines, key))
  end)
end

return M
