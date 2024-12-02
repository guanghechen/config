local path = require("eve.lib.path")
local functional = require("eve.lib.functional")
local AdvanceHistory = require("eve.lib.collection.history_advance")
local Observable = require("eve.lib.collection.observable")
local Diritier = require("eve.lib.collection.dirtier")
local tmux = require("eve.lib.tmux")
local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")
local nvim = require("eve.builtin.nvim")
local _buf = require("eve.builtin.buf")
local _win = require("eve.builtin.win")
local _tab = require("eve.builtin.tab")

---@param bufs                          eve.t.state.data.buf.IMeta[]
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

---@param tabs                          eve.t.state.data.tab.IMeta[]
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

---@class eve.state.session : eve.t.state.session
local M = {}

---@return eve.t.state.session.data
function M.defaults()
  local bufs = {} ---@type eve.t.state.data.buf.IMeta[]
  local tabs = {} ---@type eve.t.state.data.tab.IMeta[]
  local wins = {} ---@type eve.t.state.data.win.IMeta[]

  ---@type eve.lib.collection.history.ISerializedData
  local tab_history = { present = 0, stack = {} }

  ---@type eve.t.state.session.data
  local data = {
    bufs = bufs,
    tabs = tabs,
    wins = wins,
    tab_history = tab_history,
  }
  return data
end

---@return eve.t.state.session.data
function M.dump()
  if M.state == nil then
    error("[eve.state.session] the state is not initialized.")
    return M.defaults()
  end

  local state = M.state ---@type eve.t.state.session.state

  local bufs = {} ---@type eve.t.state.data.buf.IMeta[]
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local meta = _buf.get_meta(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local filename = path.basename(filepath) ---@type string
    local pinned = meta and meta.pinned or false ---@type boolean

    ---@type eve.t.state.data.buf.IMeta
    local meta_data = {
      bufnr = bufnr,
      filename = filename,
      filepath = filepath,
      pinned = pinned,
    }
    table.insert(bufs, meta_data)
  end

  local tabs = {} ---@type eve.t.state.data.tab.IMeta[]
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabnr in ipairs(tabnrs) do
    local meta = _tab.get_meta(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
    local name = meta and meta.name or constant.TAB_UNNAMED ---@type string
    local tab_bufnrs = meta and meta.bufnrs or {} ---@type integer[]

    ---@type eve.t.state.data.tab.IMeta
    local meta_data = {
      tabnr = tabnr,
      name = name,
      bufnrs = tab_bufnrs,
    }
    table.insert(tabs, meta_data)
  end

  local tab_history = state.tab_history:dump() ---@type eve.lib.collection.history.ISerializedData

  ---@type eve.t.state.session.data
  local data = {
    bufs = bufs,
    tabs = tabs,
    wins = {},
    tab_history = tab_history,
  }
  return data
end

---@param data                          eve.t.state.session.data
---@return nil
function M.load(data)
  if M.state == nil then
    ---@type eve.t.state.state.status
    local status = {
      lsp_msg = Observable.from_value(""),
      tmux_zen_mode = Observable.from_value(tmux.is_tmux_pane_zoomed()),
      winline_dirty_nr = Observable.from_value(0, functional.falsy),
      statusline_dirtier = Diritier.new(),
      tabline_dirtier = Diritier.new(),
    }

    ---@type eve.lib.collection.IAdvanceHistory
    local tab_history = AdvanceHistory.new({
      name = "tabs",
      capacity = constant.TAB_HISTORY_CAPACITY,
      validate = checks.is_tab_valid,
    })

    ---@type eve.t.state.session.state
    local state = {
      status = status,
      tab_history = tab_history,
    }
    M.state = state
  end

  local state = M.state ---@type eve.t.state.session.state

  local bufnr_2_real_bufnr = gen_real_bufnr_map(data.bufs) ---@type table<integer, integer>
  local tabnr_2_real_tabnr = gen_real_tabnr_map(data.tabs) ---@type table<integer, integer>

  --- bufs
  local workspace_pieces = path.split(path.workspace()) ---@type string[]
  local cwd_pieces = path.split(path.cwd()) ---@type string[]
  for _, item in ipairs(data.bufs) do
    local real_bufnr = type(item.bufnr) == "number" and bufnr_2_real_bufnr[item.bufnr] or nil
    if real_bufnr ~= nil and vim.api.nvim_buf_is_valid(real_bufnr) then
      local filename = item.filename ---@type string
      local filetype = vim.bo[real_bufnr].filetype ---@type string
      local fileicon, fileicon_hl = nvim.calc_fileicon(filename) ---@type string, string

      ---@type eve.t.state.state.buf.IMeta
      local meta = {
        fileicon_hl = fileicon_hl,
        fileicon = fileicon,
        filename = item.filename,
        filepath = item.filepath,
        filetype = filetype,
        relpath = path.split_prettier(workspace_pieces, cwd_pieces, item.filepath),
        pinned = item.pinned,
      }
      _buf.set_meta(real_bufnr, meta)
    end
  end

  ---! tabs
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

      local winnrs = vim.api.nvim_tabpage_list_wins(real_tabnr) ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        if checks.is_win_valid(winnr) then
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          if not vim.list_contains(bufnrs, bufnr) then
            table.insert(bufnrs, bufnr)
          end
        end
      end

      ---@type eve.t.state.state.tab.IMeta
      local meta = {
        name = item.name or constant.TAB_UNNAMED,
        bufnrs = bufnrs,
      }
      _tab.set_meta(real_tabnr, meta)
    end
  end

  ---! wins

  _buf.refresh_all()
  _win.refresh_all()
  _tab.refresh_all()

  ---! status
  state.status.lsp_msg:next("")
  state.status.tmux_zen_mode:next(tmux.is_tmux_pane_zoomed())
  state.status.winline_dirty_nr:next(0)
  state.status.statusline_dirtier:mark_dirty()
  state.status.tabline_dirtier:mark_dirty()

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
---@return eve.t.state.session.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.t.state.session.data

  if type(data) ~= "table" then
    return resolved
  end
  ---@cast data eve.t.state.session.data

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
