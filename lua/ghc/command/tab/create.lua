local checks = require("eve.builtin.checks")
local Observable = require("eve.lib.collection.observable")
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
  state.state.tab_history:push(tabnr)

  local winnr = vim.api.nvim_get_current_win() ---@type integer

  ---@type eve.t.state.state.tab.IMeta
  local meta = {
    name = constant.TAB_UNNAMED,
    bufnrs = {},
    winnr_cur = Observable.from_value(winnr),
  }

  if bufnr ~= nil and checks.is_buf_valid(bufnr) then
    meta.bufnrs = { bufnr }
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  eve.tab.set_meta(tabnr, meta)
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
