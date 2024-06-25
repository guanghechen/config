local util_json = require("fml.core.json")

---@class fml.core.debug
local M = {}

---@param value any|nil
local function better_stringify(value)
  if value == nil then
    return "nil"
  end

  if type(value) == "string" then
    return value
  end

  return util_json.stringify_prettier(value)
end

function M.log(...)
  local elements = { ... } ---@type any[]
  if #elements <= 0 then
    return
  end

  local text = "" ---@type string

  if #elements == 1 then
    text = better_stringify(elements[1])
  else 
    local texts = {} ---@type string[]
    for _, element in ipairs(elements) do
      table.insert(texts, better_stringify(element))
    end
    text = table.concat(texts, " ")
  end

  vim.notify(text, vim.log.levels.INFO)
end

return M