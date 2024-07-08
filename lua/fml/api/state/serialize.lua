---@class fml.api.state.IBufItem
---@field public filename               string
---@field public filepath               string
---@field public pinned                 boolean

---@class fml.api.state.IBufItemData
---@field public bufnr                  integer
---@field public filename               string
---@field public filepath               string
---@field public pinned                 boolean

---@class fml.api.state.ITabItem
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public bufnr_set              table<integer, boolean>

---@class fml.api.state.ITabItemData
---@field public tabnr                  integer
---@field public name                   string
---@field public bufnrs                 integer[]

---@class fml.api.state.IWinItem
---@field public tabnr                  integer
---@field public buf_history            fml.types.collection.IHistory

---@class fml.api.state.IWinItemData : fml.api.state.IWinItem
---@field public winnr                  integer
---@field public tabnr                  integer
---@field public buf_history            fml.types.collection.history.ISerializedData

---@class fml.api.state.ISerializedData
---@field public bufs                   fml.api.state.IBufItemData[]
---@field public tabs                   fml.api.state.IWinItemData[]
---@field public wins                   fml.api.state.ITabItemData[]
---@field public tab_history            fml.types.collection.history.ISerializedData
---@field public win_history            fml.types.collection.history.ISerializedData

local constant = require("fml.constant")
local History = require("fml.collection.history")
local fs = require("fml.std.fs")
local reporter = require("fml.std.reporter")
local std_set = require("fml.std.set")

---@param data                          fml.api.state.ISerializedData
---@return table<integer, integer>
local function gen_real_bufnr_map(data)
  if type(data.bufs) ~= "table" then
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

  for _, item in ipairs(data.bufs) do
    if type(item.bufnr) == "number" and type(item.filepath) == "string" then
      local real_bufnr = filepath_2_real_bufnr_map[item.filepath]
      bufnr_2_real_bufnr[item.bufnr] = real_bufnr
    end
  end

  return bufnr_2_real_bufnr
end

---@param data                          fml.api.state.ISerializedData
---@return table<integer, integer>
local function gen_real_tabnr_map(data)
  if type(data.tabs) ~= "table" then
    return {}
  end

  local tabnr_2_real_tabnr = {} ---@type table<integer, integer>
  local real_tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]

  local tabnrs = {} ---@type integer[]
  for _, item in ipairs(data.tabs) do
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

---@class fml.api.state
local M = require("fml.api.state.mod")

---@param filepath                      string
---@return nil
function M.save(filepath)
  ---@type fml.api.state.ISerializedData
  local data = {
    bufs = {},
    tabs = {},
    wins = {},
    tab_history = M.tab_history:serialize(),
    win_history = M.win_history:serialize(),
  }

  for bufnr, buf in pairs(M.bufs) do
    ---@type fml.api.state.IBufItemData
    local item = {
      bufnr = bufnr,
      filename = buf.filename,
      filepath = buf.filepath,
      pinned = buf.pinned,
    }
    table.insert(data.bufs, item)
  end
  for tabnr, tab in pairs(M.tabs) do
    ---@type fml.api.state.ITabItemData
    local item = {
      tabnr = tabnr,
      name = tab.name,
      bufnrs = tab.bufnrs,
    }
    table.insert(data.tabs, item)
  end
  -- for winnr, win in pairs(M.wins) do
  --   ---@type fml.api.state.IWinItemData
  --   local item = {
  --     winnr = winnr,
  --     tabnr = win.tabnr,
  --     buf_history = win.buf_history:serialize(),
  --   }
  --   table.insert(data.wins, item)
  -- end

  fs.write_json(filepath, data)
end

---@param filepath                      string
---@return nil
function M.load(filepath)
  local data = fs.read_json({
    filepath = filepath,
    silent_on_bad_path = true,
    silent_on_bad_json = true,
  })

  if data == nil then
    reporter.warn({
      from = "fml.api.state.serialize",
      subject = "load",
      message = "Failed to load json data",
      details = { filepath = filepath, data = data },
    })
    return
  end

  local bufnr_2_real_bufnr = gen_real_bufnr_map(data) ---@type table<integer, integer>
  local tabnr_2_real_tabnr = gen_real_tabnr_map(data) ---@type table<integer, integer>

  if type(data.bufs) == "table" then
    local bufs = {} ---@type table<integer, fml.api.state.IBufItem>
    for _, item in ipairs(data.bufs) do
      local real_bufnr = type(item.bufnr) == "number" and bufnr_2_real_bufnr[item.bufnr] or nil
      if real_bufnr ~= nil then
        ---@type fml.api.state.IBufItem
        local buf = {
          filename = item.filename,
          filepath = item.filepath,
          pinned = item.pinned,
        }
        bufs[real_bufnr] = buf
      end
    end
    M.bufs = bufs
  end

  if type(data.tabs) == "table" then
    local tabs = {} ---@type table<integer, fml.api.state.ITabItem>
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

        ---@type fml.api.state.ITabItem
        local tab = { name = item.name, bufnrs = bufnrs, bufnr_set = std_set.from_integer_array(bufnrs) }
        tabs[real_tabnr] = tab
      end
    end
    M.tabs = tabs
  end

  if type(data.tab_history) == "table" and type(data.tab_history.stack) == "table" then
    local stack = {} ---@type integer[]
    local present_index = data.tab_history.present_index ---@type integer
    for i, tabnr in ipairs(data.tab_history.stack) do
      local real_tabnr = tabnr_2_real_tabnr[tabnr]
      if real_tabnr ~= nil then
        table.insert(stack, real_tabnr)
      elseif present_index > i then
        present_index = present_index - 1
      end
      if present_index == i then
        present_index = #stack
      end
    end

    M.tab_history:clear()
    M.tab_history = History.deserialize({
      data = { stack = stack, present_index = present_index },
      name = M.tab_history.name,
      capacity = constant.TAB_HISTORY_CAPACITY,
      validate = M.validate_tab,
    })
  end
end
