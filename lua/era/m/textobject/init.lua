---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject" ---@type string

local initialized = false ---@type boolean

---@class era.m.textobject.__mods
local __mods = {
  find = "era.m.textobject.find",
  select = "era.m.textobject.action",
  move = "era.m.textobject.action",
  move_edge = "era.m.textobject.action",
  swap_parameter = "era.m.textobject.action",
  swap_operator = "era.m.textobject.action",
}

---@class era.m.textobject
---@field public __mods                 era.m.textobject.__mods
---@field public find                   fun(kind: era.m.textobject.Kind, id: string, opts?: era.m.textobject.IOptions): era.m.textobject.Range|nil, string|nil
---@field public select                 fun(kind: era.m.textobject.Kind, id: string, opts?: era.m.textobject.IOptions): nil
---@field public move                   fun(captures: string[], group: string, direction: integer, use_end: boolean, count: integer): nil
---@field public move_edge              fun(side: "left"|"right", id: string, count: integer, prompt: string[]|nil): nil
---@field public swap_parameter         fun(direction: integer): nil
---@field public swap_operator          fun(_: string): nil
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)[k]
  end,
})

---@return nil
function M.setup()
  if initialized then
    return
  end
  initialized = true
  require("era.m.textobject.keymap").bindkeys()
end

return M
