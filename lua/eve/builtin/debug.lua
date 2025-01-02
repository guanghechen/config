---@class eve.builtin.debug
local M = {}

---@param value any|nil
local function better_stringify(value)
  if value == nil then
    return "nil"
  end

  if type(value) == "string" then
    return value
  end

  return vim.inspect(value)
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
    for _, element in ipairs(elements) do
      text = text .. " " .. better_stringify(element) ---@type string
    end
    text = #text > 0 and text:sub(1) or "" ---@type string
  end

  vim.notify(text, vim.log.levels.INFO, { title = "debug" })
end

return M
