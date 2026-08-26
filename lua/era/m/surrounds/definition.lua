---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.surrounds.definition" ---@type string

local CANCEL_INPUT = "__era_surrounds_cancel__" ---@type string

---@class era.m.surrounds.definition
local M = {}

---@param prompt                        string
---@param default                       ?string
---@return string|nil
local function user_input(prompt, default)
  local ok, result = pcall(vim.fn.input, {
    prompt = string.format("(surrounds) %s: ", prompt),
    default = default or "",
    cancelreturn = CANCEL_INPUT,
  })
  vim.cmd("redraw")
  if not ok or result == CANCEL_INPUT then
    return nil
  end
  return result
end

---@type table<string, { input: table|fun(): table|nil, output: era.m.surrounds.IOutputDefinition|fun(): era.m.surrounds.IOutputDefinition|nil }>
local BUILTIN = {
  -- Opening brackets include inner edge whitespace; closing brackets do not.
  ["("] = { input = { "%b()", "^.%s*().-()%s*.$" }, output = { left = "( ", right = " )" } },
  [")"] = { input = { "%b()", "^.().*().$" }, output = { left = "(", right = ")" } },
  ["["] = { input = { "%b[]", "^.%s*().-()%s*.$" }, output = { left = "[ ", right = " ]" } },
  ["]"] = { input = { "%b[]", "^.().*().$" }, output = { left = "[", right = "]" } },
  ["{"] = { input = { "%b{}", "^.%s*().-()%s*.$" }, output = { left = "{ ", right = " }" } },
  ["}"] = { input = { "%b{}", "^.().*().$" }, output = { left = "{", right = "}" } },
  ["<"] = { input = { "%b<>", "^.%s*().-()%s*.$" }, output = { left = "< ", right = " >" } },
  [">"] = { input = { "%b<>", "^.().*().$" }, output = { left = "<", right = ">" } },
  ["?"] = {
    input = function()
      local left = user_input("Left surrounding")
      if left == nil or left == "" then
        return nil
      end
      local right = user_input("Right surrounding")
      if right == nil or right == "" then
        return nil
      end
      return { vim.pesc(left) .. "().-()" .. vim.pesc(right) }
    end,
    output = function()
      local left = user_input("Left surrounding")
      if left == nil then
        return nil
      end
      local right = user_input("Right surrounding")
      if right == nil then
        return nil
      end
      return { left = left, right = right }
    end,
  },
  b = {
    input = { { "%b()", "%b[]", "%b{}" }, "^.().*().$" },
    output = { left = "(", right = ")" },
  },
  f = {
    input = { "%f[%w_%.][%w_%.]+%b()", "^.-%(().*()%)$" },
    output = function()
      local name = user_input("Function name")
      if name == nil then
        return nil
      end
      return { left = string.format("%s(", name), right = ")" }
    end,
  },
  t = {
    input = { "<(%w-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
    output = function()
      local tag = user_input("Tag")
      if tag == nil then
        return nil
      end
      local name = tag:match("^%S*") or "" ---@type string
      return { left = "<" .. tag .. ">", right = "</" .. name .. ">" }
    end,
  },
  q = {
    input = { { "'.-'", '".-"', "`.-`" }, "^.().*().$" },
    output = { left = '"', right = '"' },
  },
}

---@return string|nil
function M.read_id()
  local ok, id = pcall(vim.fn.getcharstr)
  if not ok or id == "" or id == "\3" or id == "\27" then
    return nil
  end
  return id
end

---@param id                            string
---@return era.m.surrounds.IInputDefinition|nil
function M.resolve_input(id)
  local value = BUILTIN[id] and BUILTIN[id].input or nil ---@type table|fun(): table|nil
  if value == nil then
    value = { vim.pesc(id) .. "().-()" .. vim.pesc(id) }
  elseif type(value) == "function" then
    value = value()
  end
  if value == nil then
    return nil
  end
  return { id = id, patterns = vim.deepcopy(value) }
end

---@param id                            string
---@return era.m.surrounds.IOutputDefinition|nil
function M.resolve_output(id)
  local value = BUILTIN[id] and BUILTIN[id].output or nil ---@type era.m.surrounds.IOutputDefinition|fun(): era.m.surrounds.IOutputDefinition|nil
  if value == nil then
    value = { left = id, right = id }
  elseif type(value) == "function" then
    value = value()
  end
  return value and vim.deepcopy(value) or nil
end

return M
