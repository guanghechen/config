---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.textobject" ---@type string

local initialized = false ---@type boolean

---@class era.keystroke.textobject.__mods
local __mods = {
  find = "era.keystroke.textobject.find",
  select = "era.keystroke.textobject.action",
  move = "era.keystroke.textobject.action",
  move_edge = "era.keystroke.textobject.action",
  swap_parameter = "era.keystroke.textobject.action",
  swap_operator = "era.keystroke.textobject.action",
}

---@class era.keystroke.textobject
---@field public __mods                 era.keystroke.textobject.__mods
---@field public find                   fun(kind: era.keystroke.textobject.Kind, id: string, opts?: era.keystroke.textobject.IOptions): era.keystroke.textobject.Range|nil, string|nil
---@field public select                 fun(kind: era.keystroke.textobject.Kind, id: string, opts?: era.keystroke.textobject.IOptions): nil
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
  require("era.keystroke.textobject.keymap").bindkeys()
end

return M
