local std_array = require("fc.std.array")
local Observable = require("fml.collection.observable")
local fs = require("fml.std.fs")
local path = require("fml.std.path")
local reporter = require("fc.std.reporter")
local util = require("fml.std.util")

---@param data                          fml.types.api.state.ISerializedData
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

---@param data                          fml.types.api.state.ISerializedData
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
  ---@type fml.types.api.state.ISerializedData
  local data = {
    bufs = {},
    tabs = {},
    wins = {},
    tab_history = M.tab_history:dump(),
    win_history = M.win_history:dump(),
  }

  for bufnr, buf in pairs(M.bufs) do
    ---@type fml.types.api.state.IBufItemData
    local item = {
      bufnr = bufnr,
      filename = buf.filename,
      filepath = buf.filepath,
      pinned = buf.pinned,
    }
    table.insert(data.bufs, item)
  end
  for tabnr, tab in pairs(M.tabs) do
    ---@type fml.types.api.state.ITabItemData
    local item = {
      tabnr = tabnr,
      name = tab.name,
      bufnrs = tab.bufnrs,
    }
    table.insert(data.tabs, item)
  end
  fs.write_json(filepath, data, false)
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
    local bufs = {} ---@type table<integer, fml.types.api.state.IBufItem>
    local CWD_PIECES = path.get_cwd_pieces() ---@type string[]
    for _, item in ipairs(data.bufs) do
      local real_bufnr = type(item.bufnr) == "number" and bufnr_2_real_bufnr[item.bufnr] or nil
      if real_bufnr ~= nil and vim.api.nvim_buf_is_valid(real_bufnr) then
        local filename = item.filename ---@type string
        local filetype = vim.bo[real_bufnr].filetype ---@type string
        local fileicon, fileicon_hl = util.calc_fileicon(filename) ---@type string, string

        ---@type fml.types.api.state.IBufItem
        local buf = {
          fileicon_hl = fileicon_hl,
          fileicon = fileicon,
          filename = item.filename,
          filepath = item.filepath,
          filetype = filetype,
          real_paths = path.split_prettier(CWD_PIECES, item.filepath),
          pinned = item.pinned,
        }
        bufs[real_bufnr] = buf
      end
    end
    M.bufs = bufs
  end

  if type(data.tabs) == "table" then
    local tabs = {} ---@type table<integer, fml.types.api.state.ITabItem>
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
        ---@type fml.types.api.state.ITabItem
        local tab = {
          name = item.name,
          bufnrs = bufnrs,
          bufnr_set = std_array.to_set(bufnrs),
          winnr_cur = Observable.from_value(winnr_cur),
        }
        tabs[real_tabnr] = tab
      end
    end
    M.tabs = tabs
  end

  if type(data.tab_history) == "table" and type(data.tab_history.stack) == "table" then
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
    M.tab_history:load({ present = present, stack = stack })
  end
end
