local path = require("fml.std.path")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")
local schedule_fn = require("fml.fn.schedule_fn")
local History = require("fml.collection.history")

---@class fml.api.state
local M = require("fml.api.state.mod")

M.schedule_refresh = schedule_fn("fml.api.state.refresh", function()
  M.refresh()
end)

M.schedule_refresh_bufs = schedule_fn("fml.api.state.refresh_bufs", function()
  M.refresh_bufs()
end)

M.schedule_refresh_tabs = schedule_fn("fml.api.state.refresh_tabs", function()
  M.refresh_tabs()
end)

---@param bufnr                         integer
---@return nil
function M.schedule_refresh_buf(bufnr)
  vim.schedule(function()
    M.refresh_buf(bufnr)
  end)
end

---@param tabnr                         integer
---@return nil
function M.schedule_refresh_tab(tabnr)
  vim.schedule(function()
    M.refresh_tab(tabnr)
  end)
end

---@return nil
function M.refresh()
  ---! Refresh bufs
  local bufnr_valid_set = M.refresh_bufs() ---@type table<integer, boolean>

  ---! Refresh tabs
  M.refresh_tabs()

  for bufnr in pairs(bufnr_valid_set) do
    local copies = M.count_buf_copies(bufnr) ---@type integer
    if copies < 1 then
      M.bufs[bufnr] = nil
      vim.api.nvim_buf_delete(bufnr, { force = false })
    end
  end
  M.rearrange_tab_history()
end

---@param bufnr                         integer
---@return nil
function M.refresh_buf(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.fn.buflisted(bufnr) ~= 1 then
    M.bufs[bufnr] = nil
    return
  end

  local buf = M.bufs[bufnr]
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if buf == nil then
    local filename = path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and "Untitled" or filename
    M.bufs[bufnr] = {
      filepath = filepath,
      filename = filename,
      pinned = false,
    }
    return
  end

  if buf.filepath ~= filepath then
    local filename = path.basename(filepath) ---@type string
    filename = (not filename or filename == "") and "Untitled" or filename
    buf.filepath = filepath
    buf.filename = filename
    return
  end
end

---@return table<integer, boolean>
function M.refresh_bufs()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local bufnr_valid_set = {} ---@type table<integer, boolean>
  for _, bufnr in ipairs(bufnrs) do
    if vim.fn.buflisted(bufnr) == 1 then
      bufnr_valid_set[bufnr] = true
      M.refresh_buf(bufnr)
    end
  end
  std_object.filter_inline(M.bufs, function(bufnr)
    return not not bufnr_valid_set[bufnr]
  end)
  return bufnr_valid_set
end

---@param tabnr                         integer
---@return nil
function M.refresh_tab(tabnr)
  if not vim.api.nvim_tabpage_is_valid(tabnr) then
    M.tabs[tabnr] = nil
    return
  end

  local tab = M.tabs[tabnr] ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    ---@type fml.api.state.ITabItem
    tab = {
      name = "unnamed",
      bufnrs = {},
      wins = {},
    }
    M.tabs[tabnr] = tab
  end

  local next_wins = {} ---@type table<integer, fml.api.state.ITabWinItem>
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    if M.tab_history:empty() then
      M.tab_history:push(bufnr)
    end

    local win = tab.wins[winnr] ---@type fml.api.state.ITabWinItem|nil
    if win == nil then
      win = {
        buf_history = History.new({
          name = "win$bufs",
          max_count = 1000,
          validate = function (bufnr) 
            local t = M.tabs[tabnr]
            return M.validate_buf(bufnr) and t and std_array.contains(t.bufnrs, bufnr)
          end
        }),
      }
      win.buf_history:push(bufnr)
    else
      M.rearrange_buf_history({ buf_history = win.buf_history, bufnrs = {} })
    end
    next_wins[winnr] = win
  end
  tab.wins = next_wins
end

---@return nil
function M.refresh_tabs()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local tabnr_set = {} ---@type table<integer, boolean>
  for _, tabnr in ipairs(tabnrs) do
    tabnr_set[tabnr] = true
    M.refresh_tab(tabnr)
  end
  std_object.filter_inline(M.tabs, function(tabnr)
    return not not tabnr_set[tabnr]
  end)
end
