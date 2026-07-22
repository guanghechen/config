---@diagnostic disable: undefined-global
--- Test for era.m.statusline module
--- Run with: nvim -l lua/__test__/era/m/statusline.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.statusline")

---@class era.m.statusline.test.IRuntime
---@field clean_count                  integer
---@field dirty                        boolean
---@field renders                      boolean[]
---@field fulfill                      fun(result: string)
---@field mark_dirty                   fun()

---@return era.m.statusline.test.IRuntime, era.m.statusline
local function setup()
  local runtime = {
    clean_count = 0,
    dirty = true,
    renders = {},
  } ---@type era.m.statusline.test.IRuntime

  local subscriber = nil ---@type { on_next: fun() }|nil
  local on_fulfilled = nil ---@type fun(result: string)|nil
  local value = "" ---@type string

  local dirtier = {} ---@type table

  function dirtier:is_dirty()
    return runtime.dirty
  end

  function dirtier:mark_clean()
    runtime.clean_count = runtime.clean_count + 1
    runtime.dirty = false
    if subscriber then
      subscriber.on_next()
    end
  end

  function dirtier:subscribe(next_subscriber)
    subscriber = next_subscriber
    subscriber.on_next()
  end

  local nvimbar = {} ---@type table

  function nvimbar:place()
    return self
  end

  function nvimbar:render(immediate)
    runtime.renders[#runtime.renders + 1] = immediate == true
    if immediate then
      value = "initial"
    end
    return value
  end

  function nvimbar:snapshot()
    return value
  end

  runtime.fulfill = function(result)
    value = result
    assert(on_fulfilled)(result)
  end

  runtime.mark_dirty = function()
    runtime.dirty = true
    assert(subscriber).on_next()
  end

  local component = setmetatable({}, {
    __index = function(_, group)
      return setmetatable({}, {
        __index = function(_, name)
          return function()
            return group .. "." .. name
          end
        end,
      })
    end,
  })

  t:patch_global("stl", {
    c = {
      Subscriber = {
        new = function(props)
          return props
        end,
      },
    },
    fn = {
      falsy = function()
        return false
      end,
    },
    nvim = {
      fn = {
        augroup = function()
          return 1
        end,
      },
    },
  })
  t:patch_global("dot", {
    context = {
      flight = {
        devmode = {
          snapshot = function()
            return false
          end,
        },
      },
    },
    state = {
      status = {
        dirtier_statusline = dirtier,
      },
    },
  })
  t:patch_global("era", {
    m = {
      nvimbar = {
        Nvimbar = {
          new = function(props)
            on_fulfilled = props.on_fulfilled
            return nvimbar
          end,
        },
        component = component,
      },
    },
  })
  t:patch_table(vim.api, "nvim_create_autocmd", function()
    return 1
  end)

  local Statusline = assert(loadfile("lua/era/m/statusline.lua"))()
  return runtime, Statusline
end

t:test("dressing renders once immediately and preserves dirty updates", function()
  local runtime, Statusline = setup()

  vim.o.statusline = ""
  Statusline.dressing()

  t.assert_eq("initial", vim.o.statusline, "initial statusline")
  t.assert_eq(1, #runtime.renders, "initial render count")
  t.assert_true(runtime.renders[1], "initial render mode")
  t.assert_eq(1, runtime.clean_count, "initial clean count")

  runtime.mark_dirty()
  t.assert_eq(2, #runtime.renders, "dirty render count")
  t.assert_false(runtime.renders[2], "dirty render mode")

  runtime.fulfill("updated")
  t.assert_eq("updated", vim.o.statusline, "updated statusline")
  t.assert_eq(2, runtime.clean_count, "fulfilled clean count")
end)

t:run()
