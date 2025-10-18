---@class eve.state.maximized.IOriginalWindow
---@field public winnr                   integer
---@field public winblend                integer
---@field public wincfg                  vim.api.keyset.win_config

---@class eve.state.maximized.IContext
---@field public original                eve.state.maximized.IOriginalWindow|nil

---@class eve.state.maximized
---@field public context                 eve.state.maximized.IContext
local M = {}

local context = {
  original = nil,
} ---@type eve.state.maximized.IContext

M.context = context

---@param original                      eve.state.maximized.IOriginalWindow
---@return nil
function M.set_original(original)
  context.original = original
end

---@return eve.state.maximized.IOriginalWindow|nil
function M.get_original()
  return context.original
end

---@return nil
function M.clear_original()
  context.original = nil
end

return M
