---@class ux.fn.__mods
local __mods = {
  select_copy_filepath = "ux.fn.select_copy_filepath",
  select_encoding = "ux.fn.select_encoding",
}

---@class ux.fn
---@field public __mods                 ux.fn.__mods
---
---@field public select_copy_filepath   fun(params: ux.fn.select_copy_filepath.IParams): integer
---@field public select_encoding        fun(params: ux.fn.select_encoding.IParams): ux.picker.ListComposer
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
