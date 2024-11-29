local constant = require("eve.builtin.constant")
local path = require("eve.builtin.path")
local util = require("eve.builtin.util")
local AdvanceHistory = require("eve.collection.history_advance")
local Observable = require("eve.collection.observable")
local std_array = require("eve.std.array")
local std_nvim = require("eve.std.nvim")
local std_tab = require("eve.std.tab")
local tmux = require("eve.std.tmux")

---@param bufs                          eve.t.context.data.buf.IItem[]
---@return table<integer, integer>
local function gen_real_bufnr_map(bufs)
  if type(bufs) ~= "table" then
    return {}
  end

  local filepath_2_real_bufnr_map = {} ---@type table<string, integer>
  local bufnr_2_real_bufnr = {} ---@type table<integer, integer>
  local real_bufnrs = vim.api.nvim_list_bufs() ---@type integer[]

  for _, real_bufnr in ipairs(real_bufnrs) do
    local real_filepath = vim.api.nvim_buf_get_name(real_bufnr)
    if type(real_filepath) == "string" then
      filepath_2_real_bufnr_map[real_filepath] = real_bufnr
    end
  end

  for _, item in ipairs(bufs) do
    if type(item.bufnr) == "number" and type(item.filepath) == "string" then
      local real_bufnr = filepath_2_real_bufnr_map[item.filepath]
      bufnr_2_real_bufnr[item.bufnr] = real_bufnr
    end
  end

  return bufnr_2_real_bufnr
end

---@param tabs                          eve.t.context.data.tab.IItem[]
---@return table<integer, integer>
local function gen_real_tabnr_map(tabs)
  if type(tabs) ~= "table" then
    return {}
  end

  local tabnr_2_real_tabnr = {} ---@type table<integer, integer>
  local real_tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]

  local tabnrs = {} ---@type integer[]
  for _, item in ipairs(tabs) do
    table.insert(tabnrs, item.tabnr)
  end
  table.sort(tabnrs)

  for i, tabnr in ipairs(tabnrs) do
    if i <= #real_tabnrs then
      tabnr_2_real_tabnr[tabnr] = real_tabnrs[i]
    end
  end

  return tabnr_2_real_tabnr
end

---@class eve.context.session : eve.t.context.session
local M = {}

---@return eve.t.context.session.data
function M.defaults()
  local bufs = {} ---@type eve.t.context.data.buf.IItem[]
  local tabs = {} ---@type eve.t.context.data.tab.IItem[]
  local wins = {} ---@type eve.t.context.data.win.IItem[]

  ---@type eve.t.collection.history.ISerializedData
  local tab_history = { present = 0, stack = {} }

  ---@type eve.t.context.session.data
  local data = {
    bufs = bufs,
    tabs = tabs,
    wins = wins,
    tab_history = tab_history,
  }
  return data
end

---@return eve.t.context.session.data
function M.dump()
  if M.state == nil then
    error("[eve.context.session] the state is not initialized.")
    return M.defaults()
  end

  local state = M.state ---@type eve.t.context.session.state

  local bufs = {} ---@type eve.t.context.data.buf.IItem[]
  for bufnr, buf in pairs(state.bufs) do
    ---@type eve.t.context.data.buf.IItem
    local item = {
      bufnr = bufnr,
      filename = buf.filename,
      filepath = buf.filepath,
      pinned = buf.pinned,
    }
    table.insert(bufs, item)
  end

  local tabs = {} ---@type eve.t.context.data.tab.IItem[]
  for tabnr, tab in pairs(state.tabs) do
    ---@type eve.t.context.data.tab.IItem
    local item = {
      tabnr = tabnr,
      name = tab.name,
      bufnrs = tab.bufnrs,
    }
    table.insert(tabs, item)
  end

  local tab_history = state.tab_history:dump() ---@type eve.t.collection.history.ISerializedData

  ---@type eve.t.context.session.data
  local data = {
    bufs = bufs,
    tabs = tabs,
    wins = {},
    tab_history = tab_history,
  }
  return data
end

---@param data                          eve.t.context.session.data
---@return nil
function M.load(data)
  if M.state == nil then
    ---@type eve.t.context.state.status
    local status = {
      lsp_msg = Observable.from_value(""),
      tmux_zen_mode = Observable.from_value(tmux.is_tmux_pane_zoomed()),
      winline_dirty_nr = Observable.from_value(0, util.falsy),
    }

    ---@type eve.t.collection.IAdvanceHistory
    local tab_history = AdvanceHistory.new({
      name = "tabs",
      capacity = constant.TAB_HISTORY_CAPACITY,
      validate = std_tab.is_valid,
    })

    ---@type eve.t.context.session.state
    local state = {
      bufs = {},
      tabs = {},
      wins = {},
      status = status,
      tab_history = tab_history,
    }
    M.state = state
  end

  local state = M.state ---@type eve.t.context.session.state

  --- bufs
  local bufs = {} ---@type table<integer, eve.t.context.state.buf.IItem>
  local bufnr_2_real_bufnr = gen_real_bufnr_map(data.bufs) ---@type table<integer, integer>
  local tabnr_2_real_tabnr = gen_real_tabnr_map(data.tabs) ---@type table<integer, integer>

  local workspace_pieces = path.split(path.workspace()) ---@type string[]
  local cwd_pieces = path.split(path.cwd()) ---@type string[]
  for _, item in ipairs(data.bufs) do
    local real_bufnr = type(item.bufnr) == "number" and bufnr_2_real_bufnr[item.bufnr] or nil
    if real_bufnr ~= nil and vim.api.nvim_buf_is_valid(real_bufnr) then
      local filename = item.filename ---@type string
      local filetype = vim.bo[real_bufnr].filetype ---@type string
      local fileicon, fileicon_hl = std_nvim.calc_fileicon(filename) ---@type string, string

      ---@type eve.t.context.state.buf.IItem
      local buf = {
        fileicon_hl = fileicon_hl,
        fileicon = fileicon,
        filename = item.filename,
        filepath = item.filepath,
        filetype = filetype,
        relpath = path.split_prettier(workspace_pieces, cwd_pieces, item.filepath),
        pinned = item.pinned,
      }
      bufs[real_bufnr] = buf
    end
  end
  state.bufs = bufs

  ---! tabs
  local tabs = {} ---@type table<integer, eve.t.context.state.tab.IItem>
  for _, item in ipairs(data.tabs) do
    local real_tabnr = type(item.tabnr) == "number" and tabnr_2_real_tabnr[item.tabnr] or nil
    if real_tabnr ~= nil then
      local bufnrs = {} ---@type integer[]
      if type(item.bufnrs) == "table" then
        for _, bufnr in ipairs(item.bufnrs) do
          local real_bufnr = bufnr_2_real_bufnr[bufnr]
          if real_bufnr ~= nil then
            table.insert(bufnrs, real_bufnr)
          end
        end
      end

      local winnr_cur = vim.api.nvim_tabpage_get_win(real_tabnr) ---@type integer
      ---@type eve.t.context.state.tab.IItem
      local tab = {
        name = item.name,
        bufnrs = bufnrs,
        bufnr_set = std_array.to_set(bufnrs),
        winnr_cur = Observable.from_value(winnr_cur),
      }
      tabs[real_tabnr] = tab
    end
  end
  state.tabs = tabs

  ---! wins
  state.wins = {} ---@type table<integer, eve.t.context.state.win.IItem>

  ---! status
  state.status.lsp_msg:next("")
  state.status.tmux_zen_mode:next(tmux.is_tmux_pane_zoomed())
  state.status.winline_dirty_nr:next(0)

  ---! tab_history
  local stack = {} ---@type integer[]
  local present = data.tab_history.present ---@type integer
  for i, tabnr in ipairs(data.tab_history.stack) do
    local real_tabnr = tabnr_2_real_tabnr[tabnr]
    if real_tabnr ~= nil then
      table.insert(stack, real_tabnr)
    elseif present > i then
      present = present - 1
    end
    if present == i then
      present = #stack
    end
  end
  state.tab_history:load({ present = present, stack = stack })
end

---@param data                          any
---@return eve.t.context.session.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.t.context.session.data

  if type(data) ~= "table" then
    return resolved
  end
  ---@cast data eve.t.context.session.data

  if type(data.bufs) == "table" then
    resolved.bufs = data.bufs
  end

  if type(data.tabs) == "table" then
    resolved.tabs = data.tabs
  end

  if type(data.wins) == "table" then
    resolved.wins = data.wins
  end

  if type(data.tab_history) == "table" then
    if type(data.tab_history.present) == "number" then
      resolved.tab_history.present = data.tab_history.present
    end
    if type(data.tab_history.stack) == "table" then
      resolved.tab_history.stack = data.tab_history.stack
    end
  end

  return resolved
end

return M
