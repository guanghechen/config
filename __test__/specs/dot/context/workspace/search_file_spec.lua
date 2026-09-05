--- Run with: nvim -l __test__/run.lua __test__/specs/dot/context/workspace/search_file_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("dot.context.workspace.search_file")

local Observable = {}
Observable.__index = Observable

function Observable.from_value(value)
  return setmetatable({ value = value }, Observable)
end

function Observable:snapshot()
  return self.value
end

function Observable:next(value)
  self.value = value
end

t:test("match limit state is persisted and invalid limits fall back to defaults", function()
  local history = {
    data = { present = 0, stack = {} },
    dump = function(self)
      return self.data
    end,
    load = function(self, data)
      self.data = data
    end,
  }
  t:patch_global("stl", {
    c = {
      Observable = Observable,
      History = {
        deserialize = function()
          return history
        end,
      },
    },
  })

  local SearchFile = assert(loadfile("lua/dot/context/workspace/search_file.lua"))()
  t.assert_true(SearchFile.flag_limit_matches:snapshot(), "limit should be enabled by default")
  t.assert_eq(500, SearchFile.max_matches:snapshot(), "default limit")

  SearchFile.flag_limit_matches:next(false)
  SearchFile.max_matches:next(1200)
  local dumped = SearchFile.dump()
  SearchFile.flag_limit_matches:next(true)
  SearchFile.max_matches:next(5)
  SearchFile.load(dumped)

  t.assert_false(SearchFile.flag_limit_matches:snapshot(), "persisted switch")
  t.assert_eq(1200, SearchFile.max_matches:snapshot(), "persisted positive limit")

  local normalized = SearchFile.normalize({ flag_limit_matches = false, max_matches = 0 })
  t.assert_false(normalized.flag_limit_matches, "valid switch should be retained")
  t.assert_eq(500, normalized.max_matches, "zero limit should fall back to the safe default")

  normalized = SearchFile.normalize({ max_matches = 1.5 })
  t.assert_eq(500, normalized.max_matches, "fractional limit should fall back to the safe default")
end)

t:run()
