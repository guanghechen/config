---@class ark.vim.__mods
local __mods = {
  buf = "ark.vim.buf",
  fn = "ark.vim.fn",
  tab = "ark.vim.tab",
  win = "ark.vim.win",
}

---@class ark.vim
---@field public __mods                 ark.vim.__mods
---@field public buf                    ark.vim.buf
---@field public fn                     ark.vim.fn
---@field public tab                    ark.vim.tab
---@field public win                    ark.vim.win
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
