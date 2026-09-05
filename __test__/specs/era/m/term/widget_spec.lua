--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/term/widget_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.term.widget process failure handling

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.term.widget")
local reports = {} ---@type table[]

local Observable = {}

function Observable.from_value(initial)
  local value = initial ---@type any
  return {
    next = function(_, next_value)
      value = next_value
    end,
    snapshot = function()
      return value
    end,
  }
end

bootstrap.with_runtime(t, {
  dot = {
    state = {
      status = {
        dirtier_termline = {
          mark_dirty = function() end,
          subscribe = function() end,
        },
      },
    },
  },
  era = { m = { term = {} } },
  stl = {
    c = {
      Observable = Observable,
      Subscriber = {
        new = function(spec)
          return spec
        end,
      },
    },
    fn = {
      noop = function() end,
      observe = function() end,
    },
    nvim = {
      buf = { close = function() end },
    },
    reporter = {
      error = function(report)
        reports[#reports + 1] = report
      end,
    },
    table = {
      truncate_inline = function(values, size)
        for i = #values, size + 1, -1 do
          values[i] = nil
        end
      end,
    },
  },
})

local nvimbar = {
  component = {
    term = {
      add_button = function()
        return {}
      end,
      items = function()
        return {}
      end,
    },
  },
  Nvimbar = {
    new = function()
      local bar = {}
      function bar:place()
        return self
      end
      return bar
    end,
  },
}
t:patch_table(package.loaded, "era.m.nvimbar", nvimbar)

local state = require("era.m.term.state")
era.m.term.state = state
era.m.term.event = require("era.m.term.event")
local widget = require("era.m.term.widget")

---@param uuid                          string
---@param permanent                     boolean
---@param bufnr                         integer
---@param on_closed                     fun()
---@return era.m.term.IMeta
local function create_term(uuid, permanent, bufnr, on_closed)
  local termmeta = state.create({
    uuid = uuid,
    name = uuid,
    type = "test",
    cmd = { "missing" },
    cwd = "/repo",
    permanent = permanent,
    on_closed = on_closed,
  })
  termmeta.bufnr = bufnr
  return termmeta
end

---@return fun()[]
local function capture_schedules()
  local callbacks = {} ---@type fun()[]
  t:patch_table(vim, "schedule", function(callback)
    callbacks[#callbacks + 1] = callback
  end)
  return callbacks
end

t:test("spawn failure cleans a non-permanent terminal on the next tick", function()
  reports = {}
  local callbacks = capture_schedules()
  local closed = 0
  local termmeta = create_term("failure-ephemeral", false, 101, function()
    closed = closed + 1
  end)
  t:patch_table(vim.fn, "jobstart", function()
    error("spawn failed")
  end)

  ---@diagnostic disable-next-line: invisible
  widget:__start_job__(termmeta)

  t.assert_eq(1, #callbacks, "scheduled cleanup count")
  t.assert_true(state.get(termmeta.uuid) == termmeta, "state before cleanup")
  callbacks[1]()
  t.assert_nil(state.get(termmeta.uuid), "state after cleanup")
  t.assert_eq(-1, state.indexof(termmeta.uuid), "list index")
  t.assert_eq(1, closed, "close callback count")
  t.assert_eq(1, #reports, "error count")
end)

t:test("spawn failure keeps only the registry entry for a permanent terminal", function()
  reports = {}
  local callbacks = capture_schedules()
  local closed = 0
  local termmeta = create_term("failure-permanent", true, 102, function()
    closed = closed + 1
  end)
  t:patch_table(vim.fn, "jobstart", function()
    error("spawn failed")
  end)

  ---@diagnostic disable-next-line: invisible
  widget:__start_job__(termmeta)
  callbacks[1]()

  t.assert_true(state.get(termmeta.uuid) == termmeta, "registry entry")
  t.assert_eq(-1, state.indexof(termmeta.uuid), "list index")
  t.assert_eq(0, termmeta.bufnr, "buffer number")
  t.assert_eq(1, closed, "close callback count")
end)

t:test("a successful retry supersedes scheduled failure cleanup", function()
  reports = {}
  local callbacks = capture_schedules()
  local attempts = 0
  local closed = 0
  local termmeta = create_term("failure-retry", false, 103, function()
    closed = closed + 1
  end)
  t:patch_table(vim.fn, "jobstart", function()
    attempts = attempts + 1
    if attempts == 1 then
      error("spawn failed")
    end
    return 73
  end)

  ---@diagnostic disable-next-line: invisible
  widget:__start_job__(termmeta)
  ---@diagnostic disable-next-line: invisible
  widget:__start_job__(termmeta)
  callbacks[1]()

  t.assert_eq(73, termmeta.jobid, "retry job id")
  t.assert_true(state.get(termmeta.uuid) == termmeta, "registry entry")
  t.assert_true(state.indexof(termmeta.uuid) >= 1, "list membership")
  t.assert_eq(0, closed, "close callback count")
end)

t:run()
