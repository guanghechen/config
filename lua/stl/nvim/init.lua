---@class stl.nvim.__mods
local __mods = {
  buf = "stl.nvim.buf",
  fn = "stl.nvim.fn",
  tab = "stl.nvim.tab",
  win = "stl.nvim.win",
}

---@class stl.nvim
---@field public __mods                 stl.nvim.__mods
---@field public buf                    stl.nvim.buf
---@field public fn                     stl.nvim.fn
---@field public tab                    stl.nvim.tab
---@field public win                    stl.nvim.win
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
