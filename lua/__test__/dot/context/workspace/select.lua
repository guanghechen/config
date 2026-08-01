---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/dot/context/workspace/select.lua

local harness = require("__test__.harness")

local t = harness.new("dot.context.workspace.select")

local Observable = {}
Observable.__index = Observable

---@param value                          any
---@return table
function Observable.from_value(value)
  return setmetatable({ value = value }, Observable)
end

---@return any
function Observable:snapshot()
  return self.value
end

---@param value                          any
---@return nil
function Observable:next(value)
  self.value = value
end

t:test("scope defaults and serialization remain independent", function()
  t:patch_global("stl", { c = { Observable = Observable } })
  t:patch_table(package.loaded, "dot.context.workspace.select_item", {
    defaults = function()
      return {}
    end,
    dump = function()
      return {}
    end,
    load = function(state)
      return state or {}
    end,
    normalize = function()
      return {}
    end,
  })

  local Select = assert(loadfile("lua/dot/context/workspace/select.lua"))()
  local initial_buffer_scope = Select.find_buffer_scope:snapshot()
  local initial_file_scope = Select.find_file_scope:snapshot()

  Select.find_buffer_scope:next("T")
  Select.find_file_scope:next("D")
  Select.search_file_scope:next("B")
  local dumped = Select.dump()

  Select.find_buffer_scope:next("A")
  Select.find_file_scope:next("C")
  Select.search_file_scope:next("C")
  Select.load(dumped)

  t.assert_eq("A", initial_buffer_scope, "initial buffer scope")
  t.assert_eq("C", initial_file_scope, "initial file scope")
  t.assert_eq("T", Select.find_buffer_scope:snapshot(), "restored buffer scope")
  t.assert_eq("D", Select.find_file_scope:snapshot(), "restored file scope")
  t.assert_eq("B", Select.search_file_scope:snapshot(), "restored search scope")
end)

t:run()
