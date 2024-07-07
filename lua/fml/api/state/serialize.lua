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
  for winnr, win in pairs(M.wins) do
    ---@type fml.api.state.IWinItemData
    local item = {
      winnr = winnr,
      tabnr = win.tabnr,
      buf_history = win.buf_history:serialize(),
    }
    table.insert(data.wins, item)
  end

  fs.write_json(filepath, data)
end

---@param filepath                      string
---@return nil
function M.load(filepath)
  local data = fs.read_json({
    filepath = filepath,
    silent_on_bad_path = true,
    silent_on_bad_json = true
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

  if type(data.bufs) == "table" then
    local bufs = {} ---@type table<integer, fml.api.state.IBufItem>
    for _, item in ipairs(data.bufs) do
      if type(item.bufnr) == "number" and type(item.buf) == "table" then
        ---@type fml.api.state.IBufItem
        local buf = {
          filename = item.filename,
          filepath = item.filepath,
          pinned = item.pinned,
        }
        bufs[item.bufnr] = buf
      end
    end
    M.bufs = bufs
  end
  if type(data.tabs) == "table" then
    local tabs = {} ---@type table<integer, fml.api.state.ITabItem>
    for _, item in ipairs(data.tabs) do
      if type(item.tabnr) == "number" and type(item.tab) == "table" then
        ---@type fml.api.state.ITabItem
        local tab = {
          name = item.name,
          bufnrs = item.bufnrs,
        }
        tabs[item.tabnr] = tab
      end
    end
    M.tabs = tabs
  end
  if type(data.wins) == "table" then
    local wins = {}
    for _, item in ipairs(data.wins) do
      if type(item.winnr) == "number" and type(item.win) == "table" then
        ---@type fml.api.state.IWinItem
        local win = {
          tabnr = item.win.tabnr,
          buf_history = History.deserialize({
            data = item.win.buf_history,
            name = "win#bufs",
            capacity = constant.WIN_BUF_HISTORY_CAPACITY,
            validate = M.create_win_buf_history_validate(item.winnr),
          }),
        }
        wins[item.winnr] = win
      end
    end
    M.wins = wins
  end

  if type(data.tab_history) == "table" then
    M.tab_history:clear()
    M.tab_history = History.deserialize({
      data = data.tab_history,
      name = M.tab_history.name,
      capacity = constant.TAB_HISTORY_CAPACITY,
      validate = M.validate_tab,
    })
  end

  if type(data.win_history) == "table" then
    M.win_history:clear()
    M.win_history = History.deserialize({
      data = data.win_history,
      name = M.win_history.name,
      capacity = constant.WIN_HISTORY_CAPACITY,
      validate = M.validate_win,
    })
  end
end
