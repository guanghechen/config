--- Run with: nvim -l __test__/run.lua __test__/specs/dot/buf_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("dot.buf")

---@param located_bufnr                 integer|nil
---@param exists                        boolean
---@return dot.buf
---@return table
local function setup(located_bufnr, exists)
  local trace = {
    bufadd = {},
    bufload = {},
    conversions = {},
    exists = {},
    locate = {},
  }

  t:patch_global("stl", {
    nvim = {
      buf = {
        locate_bufnr = function(filepath)
          trace.locate[#trace.locate + 1] = filepath
          return located_bufnr
        end,
      },
    },
    reporter = { error = function() end },
  })
  t:patch_global("yoz", {
    canonical_path = {
      to_os_path = function(filepath)
        trace.conversions[#trace.conversions + 1] = filepath
        return "OS<" .. filepath .. ">"
      end,
    },
    path = {
      is_exist_file = function(filepath)
        trace.exists[#trace.exists + 1] = filepath
        return exists
      end,
    },
  })
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function() end)
  t:patch_table(vim.fn, "bufadd", function(filepath)
    trace.bufadd[#trace.bufadd + 1] = filepath
    return 23
  end)
  t:patch_table(vim.fn, "bufload", function(bufnr)
    trace.bufload[#trace.bufload + 1] = bufnr
  end)

  return assert(loadfile("lua/dot/buf.lua"))(), trace
end

t:test("loadfile keeps canonical identity lookup before the OS boundary", function()
  local buf, trace = setup(17, true)

  local bufnr = buf.loadfile("C:/repo/file.lua")

  t.assert_eq(17, bufnr, "located buffer")
  t.assert_eq("C:/repo/file.lua", trace.locate[1], "canonical lookup")
  t.assert_eq(0, #trace.conversions, "boundary conversion count")
  t.assert_eq(0, #trace.exists, "filesystem lookup count")
  t.assert_eq(0, #trace.bufadd, "buffer creation count")
end)

t:test("loadfile converts once at filesystem and buffer creation boundaries", function()
  local buf, trace = setup(nil, true)

  local bufnr = buf.loadfile("C:/repo/file.lua")

  t.assert_eq(23, bufnr, "loaded buffer")
  t.assert_eq("C:/repo/file.lua", trace.locate[1], "canonical lookup")
  t.assert_eq("C:/repo/file.lua", trace.conversions[1], "conversion input")
  t.assert_eq(1, #trace.conversions, "boundary conversion count")
  t.assert_eq("OS<C:/repo/file.lua>", trace.exists[1], "filesystem OS path")
  t.assert_eq("OS<C:/repo/file.lua>", trace.bufadd[1], "buffer OS path")
  t.assert_eq(23, trace.bufload[1], "loaded buffer number")
end)

t:test("loadfile does not create a buffer when the OS path is missing", function()
  local buf, trace = setup(nil, false)

  local bufnr = buf.loadfile("C:/repo/missing.lua")

  t.assert_nil(bufnr, "missing buffer")
  t.assert_eq("C:/repo/missing.lua", trace.conversions[1], "conversion input")
  t.assert_eq("OS<C:/repo/missing.lua>", trace.exists[1], "filesystem OS path")
  t.assert_eq(0, #trace.bufadd, "buffer creation count")
end)

t:run()
