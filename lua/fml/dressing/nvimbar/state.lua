---@class fml.dressing.nvimbar.state.IWinline
---@field public bufnr                  integer
---@field public nvimbar                eve.ux.INvimbar

---@class fml.dressing.nvimbar.state
local M = {}

M.winline_map = {} ---@type table<integer, fml.dressing.nvimbar.state.IWinline>

vim.api.nvim_create_autocmd("WinClosed", {
  group = eve.nvim.augroup("dressing_nvimbar_on_WinClosed"),
  callback = function(args)
    local winnr = tonumber(args.file) ---@type integer|nil
    if winnr ~= nil then
      local winline = M.winline_map[winnr] ---@type fml.dressing.nvimbar.state.IWinline|nil
      if winline ~= nil then
        M.winline_map[winnr] = nil
        winline.nvimbar:dispose()
      end
    end
  end,
})

return M
