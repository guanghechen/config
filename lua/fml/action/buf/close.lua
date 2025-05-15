local __module_name__ = "fml.action.buf" ---@type string

---@param tabnr                         integer
---@param bufnrs                        integer[]
---@return nil
local function close(tabnr, bufnrs)
  if #bufnrs < 1 then
    return
  end

  eve.tab.on_bufs_close(tabnr, bufnrs)

  local bufnrs_unreferenced = eve.tab.retrieve_unreferenced_bufnrs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs_unreferenced) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@class fml.action.buf
local M = {}

---@return nil
function M.close()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr == nil then
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    eve.buf.close(bufnr)
    return
  end

  local meta = eve.win.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    eve.buf.close(bufnr)
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer|nil
  local history = meta.history ---@type eve.std.collection.IHistory|nil
  if history == nil then
    eve.buf.close(bufnr)
    return
  end

  local bufnr_target = nil ---@type integer|nil

  local item_present = history:present() ---@type eve.builtin.win.IFilepathHistoryItem|nil
  if
    item_present ~= nil
    and item_present.bufnr ~= nil
    and item_present.bufnr ~= bufnr
    and vim.api.nvim_buf_is_valid(item_present.bufnr)
  then
    bufnr_target = item_present.bufnr ---@type integer
  else
    while true do
      local item, is_bot = history:backward()
      ---@cast item eve.builtin.win.IFilepathHistoryItem|nil
      ---@cast is_bot boolean

      if item == nil then
        break
      end

      if item.bufnr ~= nil and vim.api.nvim_buf_is_valid(item.bufnr) then
        bufnr_target = item.bufnr ---@type integer
        item.filepath = vim.api.nvim_buf_get_name(bufnr_target) ---@type string
        break
      end

      bufnr_target = eve.buf.loadfile(item.filepath) ---@type integer|nil
      if bufnr_target ~= nil then
        item.bufnr = bufnr_target ---@type integer
        break
      end

      if is_bot then
        break
      end
    end
  end

  if bufnr_target ~= nil then
    vim.api.nvim_win_set_buf(winnr, bufnr_target)
  end

  close(tabnr, { bufnr })
end

---@return nil
function M.close_to_leftest()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
  if meta == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "close_to_leftest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = eve.tab.retrieve_buf_sourcefile(tabnr) ---@type eve.builtin.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta.bufs ---@type eve.builtin.tab.IBufItem[]
  local bufnrs_visible = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  local bufnrs_to_remove = {} ---@type integer[]

  for i = bufid_sourcefile - 1, 1, -1 do
    local buf = bufs[i] ---@type eve.builtin.tab.IBufItem
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(tabnr, bufnrs_to_remove)
end

---@return nil
function M.close_to_rightest()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
  if meta == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "close_to_rightest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = eve.tab.retrieve_buf_sourcefile(tabnr) ---@type eve.builtin.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta.bufs ---@type eve.builtin.tab.IBufItem[]
  local bufnrs_visible = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  local bufnrs_to_remove = {} ---@type integer[]

  for i = bufid_sourcefile + 1, #bufs, 1 do
    local buf = bufs[i] ---@type eve.builtin.tab.IBufItem
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(tabnr, bufnrs_to_remove)
end

---@return nil
function M.close_others()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
  if meta == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "close_others",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufnrs_to_remove = {} ---@type integer[]
  local bufnrs_visible = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>

  for _, buf in ipairs(meta.bufs) do
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(tabnr, bufnrs_to_remove)
end

return M
