local Frecency = require("eve.collection.frecency")
local History = require("eve.collection.history")
local AdvanceHistory = require("eve.collection.history_advance")
local Observable = require("eve.collection.observable")
local std_array = require("eve.std.array")
local constants = require("eve.std.constants")
local md5 = require("eve.std.md5")
local std_nvim = require("eve.std.nvim")
local path = require("eve.std.path")
local std_tab = require("eve.std.tab")
local std_util = require("eve.std.util")

---@param bufs                          t.eve.context.data.buf.IItem[]
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

---@param tabs                          t.eve.context.data.tab.IItem[]
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

---@class eve.context.workspace : t.eve.context.workspace
local M = {}

---@return t.eve.context.workspace.data
function M.defaults()
  local bufs = {} ---@type t.eve.context.data.buf.IItem[]
  local tabs = {} ---@type t.eve.context.data.tab.IItem[]
  local wins = {} ---@type t.eve.context.data.win.IItem[]

  ---@type t.eve.context.data.frecency
  local frecency = {
    files = { items = {} },
  }

  ---@type t.eve.context.data.input_history
  local input_history = {
    find_files = { present = 0, stack = {} },
    search_in_files = { present = 0, stack = {} },
  }

  ---@type t.eve.collection.history.ISerializedData
  local tab_history = { present = 0, stack = {} }

  ---@type t.eve.context.workspace.data
  local data = {
    bufs = bufs,
    tabs = tabs,
    wins = wins,
    frecency = frecency,
    input_history = input_history,
    tab_history = tab_history,
  }
  return data
end

---@return t.eve.context.workspace.data
function M.dump()
  if M.state == nil then
    error("[eve.context.workspace] the state is not initialized.")
    return M.defaults()
  end

  local state = M.state ---@type t.eve.context.workspace.state

  local bufs = {} ---@type t.eve.context.data.buf.IItem[]
  for bufnr, buf in pairs(state.bufs) do
    ---@type t.eve.context.data.buf.IItem
    local item = {
      bufnr = bufnr,
      filename = buf.filename,
      filepath = buf.filepath,
      pinned = buf.pinned,
    }
    table.insert(bufs, item)
  end

  local tabs = {} ---@type t.eve.context.data.tab.IItem[]
  for tabnr, tab in pairs(state.tabs) do
    ---@type t.eve.context.data.tab.IItem
    local item = {
      tabnr = tabnr,
      name = tab.name,
      bufnrs = tab.bufnrs,
    }
    table.insert(tabs, item)
  end

  ---@type t.eve.context.data.frecency
  local frecency = {
    files = state.frecency.files:dump(),
  }

  ---@type t.eve.context.data.input_history
  local input_history = {
    find_files = state.input_history.find_files:dump(),
    search_in_files = state.input_history.search_in_files:dump(),
  }

  local tab_history = state.tab_history:dump() ---@type t.eve.collection.history.ISerializedData

  ---@type t.eve.context.workspace.data
  local data = {
    bufs = bufs,
    tabs = tabs,
    wins = {},
    frecency = frecency,
    input_history = input_history,
    tab_history = tab_history,
  }
  return data
end

---@param data                          t.eve.context.workspace.data
---@return nil
function M.load(data)
  if M.state == nil then
    local bufnr_2_real_bufnr = gen_real_bufnr_map(data.bufs) ---@type table<integer, integer>
    local tabnr_2_real_tabnr = gen_real_tabnr_map(data.tabs) ---@type table<integer, integer>
    local bufs = {} ---@type table<integer, t.eve.context.state.buf.IItem>

    local cwd = path.cwd() ---@type string
    for _, item in ipairs(data.bufs) do
      local real_bufnr = type(item.bufnr) == "number" and bufnr_2_real_bufnr[item.bufnr] or nil
      if real_bufnr ~= nil and vim.api.nvim_buf_is_valid(real_bufnr) then
        local filename = item.filename ---@type string
        local filetype = vim.bo[real_bufnr].filetype ---@type string
        local fileicon, fileicon_hl = std_nvim.calc_fileicon(filename) ---@type string, string

        ---@type t.eve.context.state.buf.IItem
        local buf = {
          fileicon_hl = fileicon_hl,
          fileicon = fileicon,
          filename = item.filename,
          filepath = item.filepath,
          filetype = filetype,
          relpath = path.split_prettier(cwd, item.filepath),
          pinned = item.pinned,
        }
        bufs[real_bufnr] = buf
      end
    end

    local tabs = {} ---@type table<integer, t.eve.context.state.tab.IItem>
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
        ---@type t.eve.context.state.tab.IItem
        local tab = {
          name = item.name,
          bufnrs = bufnrs,
          bufnr_set = std_array.to_set(bufnrs),
          winnr_cur = Observable.from_value(winnr_cur),
        }
        tabs[real_tabnr] = tab
      end
    end

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

    ---@type t.eve.context.state.status
    local status = {
      lsp_msg = Observable.from_value(""),
      tmux_zen_mode = Observable.from_value(false),
    }

    ---@type t.eve.context.state.frecency
    local frecency = {
      files = Frecency.new({
        items = {},
        normalize = function(key)
          return md5.sumhexa(key)
        end,
      }),
    }
    frecency.files:load(data.frecency.files)

    ---@type t.eve.context.state.input_history
    local input_history = {
      find_files = History.new({ name = "find_files", capacity = 100 }),
      search_in_files = History.new({ name = "search_in_files", capacity = 300 }),
    }
    input_history.find_files:load(data.input_history.find_files)
    input_history.search_in_files:load(data.input_history.search_in_files)

    ---@type t.eve.collection.IAdvanceHistory
    local tab_history = AdvanceHistory.new({
      name = "tabs",
      capacity = constants.TAB_HISTORY_CAPACITY,
      validate = std_tab.is_valid,
    })
    tab_history:load({ present = present, stack = stack })

    ---@type t.eve.collection.IObservable
    local winline_dirty_nr = Observable.from_value(0, std_util.falsy)

    ---@type t.eve.context.workspace.state
    local state = {
      bufs = bufs,
      tabs = tabs,
      wins = {},
      status = status,
      frecency = frecency,
      input_history = input_history,
      tab_history = tab_history,
      winline_dirty_nr = winline_dirty_nr,
    }
    M.state = state
  end
end

---@param data                          any
---@return t.eve.context.workspace.data
function M.normalize(data)
  local resolved = M.defaults() ---@type t.eve.context.workspace.data

  if type(data) ~= "table" then
    return resolved
  end
  ---@cast data t.eve.context.workspace.data

  if type(data.bufs) == "table" then
    resolved.bufs = data.bufs
  end

  if type(data.tabs) == "table" then
    resolved.tabs = data.tabs
  end

  if type(data.wins) == "table" then
    resolved.wins = data.wins
  end

  if type(data.frecency) == "table" then
    for key, frecency in pairs(data.frecency) do
      if data.frecency[key] and type(frecency) == "table" then
        if type(frecency.items) == "table" then
          data.frecency[key].items = frecency.items
        end
      end
    end
  end

  if type(data.input_history) == "table" then
    for key, history in pairs(data.input_history) do
      if data.input_history[key] and type(history) == "table" then
        if type(history.present) == "number" then
          resolved.input_history[key].present = history.present
        end
        if type(history.stack) == "table" then
          resolved.input_history[key].stack = history.stack
        end
      end
    end
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
