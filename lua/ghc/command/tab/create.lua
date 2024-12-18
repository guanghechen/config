local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")
local state = require("eve.state")

local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@param bufnr                         ?integer
---@return integer
local function create(bufnr)
  vim.cmd("$tabnew")
  vim.bo.buflisted = false
  vim.bo.bufhidden = "wipe"

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  state.tab.tab_history:push(tabnr)

  local tabtype = constant.TT_NORMAL ---@type string
  local winnr_listed = 0 ---@type integer
  local bufs = {} ---@type eve.t.state.tab.buf.state[]

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if checks.is_win_valid(winnr) then
    winnr_listed = winnr
  end

  if bufnr ~= nil and checks.is_buf_valid(bufnr) then
    bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.tab.buf.state
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  local meta = state.tab.Meta.new(tabnr, tabtype, winnr_listed, bufs)
  state.tab.set(tabnr, meta)
  return tabnr
end

eve.commander
  .register({
    uuid = uuids.tab_new,
    desc = "tab: new",
    action = function()
      create()
    end,
  })
  .register({
    uuid = uuids.tab_new_with_buf,
    desc = "tab: new (with current buf)",
    action = function()
      local winnr = vim.api.nvim_get_current_win()
      local bufnr = vim.api.nvim_win_get_buf(winnr)
      local cursor = vim.api.nvim_win_get_cursor(winnr)

      create(bufnr)
      vim.api.nvim_win_set_cursor(winnr, cursor)
    end,
  })
