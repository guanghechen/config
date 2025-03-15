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

---@param bufnr                         integer|nil
---@return nil
function M.close(bufnr)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  if bufnr ~= nil then
    if eve.editor.is_buf_valid(bufnr) then
      close(tabnr, { bufnr })
    end
    return
  end

  bufnr = eve.state.tab.get_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr == nil then
    return
  end

  local winnr = eve.state.editor.get_winnr_sourcefile() ---@type integer|nil
  local win_meta = eve.state.win.resolve(winnr) ---@type eve.state.win.meta.state|nil

  ---! Set the buf to the last buf in the history before closing the current buf to avoid unexpected behaviors.
  if winnr ~= nil and win_meta ~= nil then
    local last_filepath = win_meta.filepath_history:backward() ---@type string|nil
    local bufnr_last = eve.state.buf.locate_by_filepath(last_filepath) ---@type integer|nil
    if bufnr_last ~= nil and vim.api.nvim_buf_is_valid(bufnr_last) then
      vim.api.nvim_win_set_buf(winnr, bufnr_last)
    end
  end

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

  local bufid_sourcefile = meta_tab.bufid_sourcefile:snapshot() ---@type integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta_tab.bufs ---@type eve.state.tab.buf.state[]
  local bufnrs_visible = eve.editor.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>
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

  local bufid_sourcefile = meta_tab.bufid_sourcefile:snapshot() ---@type integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta_tab.bufs ---@type eve.state.tab.buf.state[]
  local bufnrs_visible = eve.editor.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>
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
  local bufnrs_visible = eve.editor.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>

  for _, buf in ipairs(meta_tab.bufs) do
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(tabnr, bufnrs_to_remove)
end

return M
