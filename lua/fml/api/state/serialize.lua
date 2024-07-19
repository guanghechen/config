local constant = require("fml.constant")
local History = require("fml.collection.history")
local Observable = require("fml.collection.observable")
local fs = require("fml.std.fs")
local path = require("fml.std.path")
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
    tab_history = M.tab_history:dump(),
    win_history = M.win_history:dump(),
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
      from = "fml.api.state.load",
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
    local CWD_PIECES = path.get_cwd_pieces() ---@type string[]
    for _, item in ipairs(data.bufs) do
      local real_bufnr = type(item.bufnr) == "number" and bufnr_2_real_bufnr[item.bufnr] or nil
      if real_bufnr ~= nil then
        ---@type fml.api.state.IBufItem
        local buf = {
          filename = item.filename,
          filepath = item.filepath,
          real_paths = path.split_prettier(CWD_PIECES, item.filepath),
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

        local winnr_cur = vim.api.nvim_tabpage_get_win(real_tabnr) ---@type integer
        ---@type fml.api.state.ITabItem
        local tab = {
          name = item.name,
          bufnrs = bufnrs,
          bufnr_set = std_set.from_integer_array(bufnrs),
          winnr_cur = Observable.from_value(winnr_cur),
        }
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
