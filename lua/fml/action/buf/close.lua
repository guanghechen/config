local __module_name__ = "fml.action.buf" ---@type string

---@param tabnr                         integer
---@param bufnrs                        integer[]
---@return nil
local function close(tabnr, bufnrs)
  if #bufnrs < 1 then
    return
  end

  eve.state.tab.on_bufs_close(tabnr, bufnrs)

  local unrefereced_bufnrs = eve.state.tab.get_unrefereced_bufnrs() ---@type integer[]
  for _, bufnr in ipairs(unrefereced_bufnrs) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@class fml.action.buf
local M = {}

---@return nil
function M.close()
  local winnr = eve.state.editor.get_winnr_sourcefile() ---@type integer|nil
  if winnr == nil then
    return
  end

  local meta = eve.win.resolve(winnr) ---@type eve.builtin.win.IMetaData|nil
  if meta == nil then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer|nil
  local history = meta.history ---@type eve.std.collection.IHistory|nil
  if history == nil then
    return
  end

  local bufnr_target = nil ---@type integer|nil
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

  if bufnr_target ~= nil then
    vim.api.nvim_win_set_buf(winnr, bufnr_target)
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  close(tabnr, { bufnr })
end

---@return nil
function M.close_to_leftest()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "close_to_leftest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufid_sourcefile = meta_tab:get_bufid_sourcefile() ---@type integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta_tab.bufs ---@type eve.state.tab.buf.state[]
  local bufnrs_visible = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  local bufnrs_to_remove = {} ---@type integer[]

  for i = bufid_sourcefile - 1, 1, -1 do
    local buf = bufs[i] ---@type eve.state.tab.buf.state
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(tabnr, bufnrs_to_remove)
end

---@return nil
function M.close_to_rightest()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "close_to_rightest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufid_sourcefile = meta_tab:get_bufid_sourcefile() ---@type integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta_tab.bufs ---@type eve.state.tab.buf.state[]
  local bufnrs_visible = eve.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  local bufnrs_to_remove = {} ---@type integer[]

  for i = bufid_sourcefile + 1, #bufs, 1 do
    local buf = bufs[i] ---@type eve.state.tab.buf.state
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(tabnr, bufnrs_to_remove)
end

---@return nil
function M.close_others()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
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

  for _, buf in ipairs(meta_tab.bufs) do
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(tabnr, bufnrs_to_remove)
end

return M
