---@class dot.ux.fn.__mods
local __mods = {
  select_copy_filepath = "dot.ux.fn.select_copy_filepath",
  select_encoding = "dot.ux.fn.select_encoding",
}

---@class dot.ux.fn
---@field public __mods                 dot.ux.fn.__mods
---
---@field public select_copy_filepath   fun(params: dot.ux.fn.select_copy_filepath.IParams): integer
---@field public select_encoding        fun(params: dot.ux.fn.select_encoding.IParams): dot.ux.picker.ListComposer
local M = setmetatable({ __mods = __mods }, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
