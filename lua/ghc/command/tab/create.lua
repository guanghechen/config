local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

---@param bufnr                         ?integer
---@return integer
local function create(bufnr)
  vim.cmd("$tabnew")

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.context.state.tab_history:push(tabnr)

  if bufnr ~= nil then
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  vim.schedule(function()
    fml.api.tab.refresh(tabnr)

    local tab = eve.context.state.tabs[tabnr] ---@type t.eve.context.state.tab.IItem
    if bufnr ~= nil and tab ~= nil and #tab.bufnrs > 1 then
      tab.bufnrs = { bufnr }
      tab.bufnr_set = { [bufnr] = true }
    end
  end)

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
