local __module_name__ = "fml.action.buf" ---@type string

local reporter = require("eve.lib.reporter")
local state = require("eve.state")

---@param bufnrs                        integer[]
---@return nil
local function close(bufnrs)
  if #bufnrs < 1 then
    return
  end

  state.tab.on_bufs_close(bufnrs)

  local unrefereced_bufnrs = state.tab.get_unrefereced_bufnrs() ---@type integer[]
  for _, bufnr in ipairs(unrefereced_bufnrs) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@class fml.action.buf
local M = {}

---@param context                       eve.lib.command.IContext
---@return nil
function M.close(context)
  local winnr = context.winnr ---@type integer
  local bufnr = context.bufnr ---@type integer
  local win_meta = state.win.resolve(winnr) ---@type eve.t.state.win.meta.state|nil

  ---! Set the buf to the last buf in the history before closing the current buf to avoid unexpected behaviors.
  if win_meta ~= nil then
    local last_filepath = win_meta.filepath_history:backward() ---@type string|nil
    local bufnr_last = state.buf.locate_by_filepath(last_filepath) ---@type integer|nil
    if bufnr_last ~= nil and vim.api.nvim_buf_is_valid(bufnr_last) then
      vim.api.nvim_win_set_buf(winnr, bufnr_last)
    end
  end

  close({ bufnr })
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.close_to_leftest(context)
  local tabnr = context.tabnr ---@type integer
  local tab_meta = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if tab_meta == nil then
    reporter.error({
      from = __module_name__,
      subject = "close_to_leftest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufnr_cur = context.bufnr ---@type integer
  local bufnrs_to_remove = {} ---@type integer[]
  local bufnrs_visible = state.tab.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>

  local _, index = tab_meta:find_buf(bufnr_cur)
  if index ~= nil then
    for i = index - 1, 1, -1 do
      local buf = tab_meta.bufs[i] ---@type eve.t.state.tab.buf.state
      if not buf.pinned and not bufnrs_visible[buf.bufnr] then
        table.insert(bufnrs_to_remove, buf.bufnr)
      end
    end
  end

  close(bufnrs_to_remove)
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.close_to_rightest(context)
  local tabnr = context.tabnr ---@type integer
  local tab_meta = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if tab_meta == nil then
    reporter.error({
      from = __module_name__,
      subject = "close_to_rightest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufnr_cur = context.bufnr ---@type integer
  local bufnrs_to_remove = {} ---@type integer[]
  local bufnrs_visible = state.tab.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>

  local _, index = tab_meta:find_buf(bufnr_cur)
  if index ~= nil then
    for i = index + 1, #tab_meta.bufs, 1 do
      local buf = tab_meta.bufs[i] ---@type eve.t.state.tab.buf.state
      if not buf.pinned and not bufnrs_visible[buf.bufnr] then
        table.insert(bufnrs_to_remove, buf.bufnr)
      end
    end
  end

  close(bufnrs_to_remove)
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.close_others(context)
  local tabnr = context.tabnr ---@type integer
  local tab_meta = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if tab_meta == nil then
    reporter.error({
      from = __module_name__,
      subject = "close_others",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufnrs_to_remove = {} ---@type integer[]
  local bufnrs_visible = state.tab.get_visible_bufnrs(tabnr) ---@type table<integer, boolean>

  for _, buf in ipairs(tab_meta.bufs) do
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  close(bufnrs_to_remove)
end

return M
