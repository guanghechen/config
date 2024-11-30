---@return nil
local function refresh_state()
  eve.buf.refresh_all()
  eve.win.refresh_all()
  eve.tab.refresh_all()
  eve.tab.remove_unrefereced_bufs(vim.api.nvim_list_bufs())
end

return eve.fn.schedule("fml.fn.refresh_state", refresh_state, 16)
