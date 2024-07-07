local constant = require("fml.constant")
local History = require("fml.collection.history")
local std_array = require("fml.std.array")
local fs = require("fml.std.fs")
local reporter = require("fml.std.reporter")


---@class fml.api.state
local M = require("fml.api.state.mod")

---@param filepath                      string
---@return nil
function M.save(filepath)
  local data = {
    tabs = M.tabs,
    wins = {},
    bufs = M.bufs,
    win_history = M.win_history:serialize(),
  }

  for winnr, win in pairs(M.wins) do
    data.wins[winnr] = {
      tabnr = win.tabnr,
      buf_history = win.buf_history:serialize(),
    }
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
    M.bufs = data.bufs
  end

  if type(data.tabs) == "table" then
    M.tabs = data.tabs
  end

  if type(data.win_history) == "table" then
    M.win_history:clear()
    M.win_history = History.deserialize({
      data = data.win_history,
      name = M.win_history.name,
      capacity = constant.WIN_HISTORY_CAPACITY,
      validate = M.validate_win,
    })
    data.win_history:deserialize(data.win_history)
  end

  if type(data.wins) == "table" then
    local next_wins = {}
    for winnr, win in pairs(data.wins) do
      if type(win) == "table" then
        next_wins[winnr] = {
          tabnr = win.tabnr,
          buf_history = History.deserialize({
            data = win.buf_history,
            name = "win#bufs",
            capacity = constant.WIN_BUF_HISTORY_CAPACITY,
            validate = M.create_win_buf_history_validate(winnr),
          }),
        }
      end
    end
    M.wins = next_wins
  end
end
