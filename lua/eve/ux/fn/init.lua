---@class eve.ux.fn.__mods
local __mods = {
  select = "eve.ux.fn.select",
  select_copy_filepath = "eve.ux.fn.select_copy_filepath",
  select_files = "eve.ux.fn.select_files",
  select_encoding = "eve.ux.fn.select_encoding",
}

---@class eve.ux.fn
---@field public __mods                 eve.ux.fn.__mods
---
---@field public select                 fun(params: eve.ux.fn.select.IParams): eve.ux.ISelect
---@field public select_copy_filepath   fun(params: eve.ux.fn.select_copy_filepath.IParams): nil
---@field public select_files           fun(params: eve.ux.fn.select_files.IParams): eve.ux.IFileSelect
---@field public select_encoding        fun(params: eve.ux.fn.select_encoding.IParams): eve.ux.ISelect
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
