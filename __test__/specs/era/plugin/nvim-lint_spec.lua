--- Run with: nvim -l __test__/run.lua __test__/specs/era/plugin/nvim-lint_spec.lua
---@diagnostic disable: undefined-global, invisible

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.plugin.nvim-lint")

local buffer_counter = 0

---@param filetype                      string
---@param loaded                       ?boolean
---@return integer
local function create_buffer(filetype, loaded)
  buffer_counter = buffer_counter + 1
  local filepath = vim.fs.joinpath(
    vim.fn.getcwd(),
    string.format(".nvim-lint-test-%d-%d.%s", vim.fn.getpid(), buffer_counter, filetype)
  )

  local bufnr ---@type integer
  if loaded == false then
    bufnr = vim.fn.bufadd(filepath)
  else
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, filepath)
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
  end

  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
end

---@class __test__.specs.era.plugin.nvim_lint.ITimer
---@field public callback               fun(): nil
---@field public delay                  integer
---@field public scheduled              boolean
---@field public schedule_count         integer
---@field public dispose_count          integer
---@field public dispose                fun(self: __test__.specs.era.plugin.nvim_lint.ITimer): nil
---@operator call: nil

---@class __test__.specs.era.plugin.nvim_lint.IContext
---@field public callbacks              table<string, fun(event: { buf: integer }): nil>
---@field public calls                  { bufnr: integer, name: string, names: string[] }[]
---@field public errors                 table[]
---@field public timers                 __test__.specs.era.plugin.nvim_lint.ITimer[]
---@field public subscriptions          { unsubscribe_count: integer, unsubscribe: fun(self: table): nil }[]
---@field public subscription_ignore_initial boolean|nil
---@field public plugin                 era.m.plugin.IPluginSpec
---@field public emit                   fun(bufnr: integer): nil
---@field public flush                  fun(index: integer|nil): nil
---@field public set_visibility         fun(bufnr: integer, kind: "visible"|"autocmd"|nil): nil

---@return __test__.specs.era.plugin.nvim_lint.IContext
local function setup()
  local ctx = {
    callbacks = {},
    calls = {},
    errors = {},
    timers = {},
    subscriptions = {},
    subscription_ignore_initial = nil,
  } ---@type __test__.specs.era.plugin.nvim_lint.IContext

  local lint_schedule_subscriber = nil ---@type stl.c.ISubscriber|nil
  local augroup = 0
  local visible_bufnrs = { [vim.api.nvim_get_current_buf()] = true } ---@type table<integer, true>
  local autocmd_bufnrs = {} ---@type table<integer, true>
  local window_types = {} ---@type table<integer, string>

  local lint = {
    linters_by_ft = {},
    linters = setmetatable({ cspell = { args = {} } }, {
      __index = function(map, name)
        local linter = {}
        rawset(map, name, linter)
        return linter
      end,
    }),
    _resolve_linter_by_ft = function(filetype)
      return { filetype .. "-lint" }
    end,
    try_lint = function(names)
      ctx.calls[#ctx.calls + 1] = {
        bufnr = vim.api.nvim_get_current_buf(),
        name = vim.api.nvim_buf_get_name(0),
        names = vim.list_slice(names),
      }
    end,
  }

  bootstrap.with_stl(t, {
    c = {
      Subscriber = {
        new = function(props)
          return {
            next = function(_, value, value_prev)
              props.on_next(value, value_prev)
            end,
          }
        end,
      },
    },
    filetype = {
      is_not_sourcefile = function()
        return false
      end,
    },
    nvim = {
      fn = {
        augroup = function()
          augroup = augroup + 1
          return augroup
        end,
      },
    },
    reporter = {
      error = function(report)
        ctx.errors[#ctx.errors + 1] = report
      end,
      warn = function() end,
    },
    timer = {
      debounce = function(callback, delay)
        local timer = {
          callback = callback,
          delay = delay,
          scheduled = false,
          schedule_count = 0,
          dispose_count = 0,
        } ---@type __test__.specs.era.plugin.nvim_lint.ITimer

        function timer:dispose()
          self.dispose_count = self.dispose_count + 1
          self.scheduled = false
        end

        setmetatable(timer, {
          __call = function()
            timer.scheduled = true
            timer.schedule_count = timer.schedule_count + 1
          end,
        })
        ctx.timers[#ctx.timers + 1] = timer
        return timer
      end,
    },
  })
  bootstrap.with_dot(t, {
    context = {
      lsp = {
        spellcheck = {
          snapshot = function()
            return true
          end,
        },
      },
    },
    path = {
      relative = function()
        return "relative"
      end,
      workspace = function()
        return vim.fn.getcwd()
      end,
    },
    state = {
      status = {
        lint_schedule_nr = {
          subscribe = function(_, subscriber, ignore_initial)
            lint_schedule_subscriber = subscriber
            ctx.subscription_ignore_initial = ignore_initial
            local subscription = {
              unsubscribe_count = 0,
              unsubscribe = function(self)
                self.unsubscribe_count = self.unsubscribe_count + 1
              end,
            }
            ctx.subscriptions[#ctx.subscriptions + 1] = subscription
            return subscription
          end,
        },
      },
    },
    var = {
      N_BUF_DISABLE_LINT = "__test_disable_lint",
    },
  })
  bootstrap.with_yoz(t, {
    path = {
      is_absolute = function()
        return false
      end,
    },
  })

  t:patch_table(package.loaded, "lint", lint)
  t:patch_table(vim.fn, "win_findbuf", function(bufnr)
    local winnr = bufnr + 10000 ---@type integer
    if visible_bufnrs[bufnr] then
      window_types[winnr] = ""
      return { winnr }
    end
    if autocmd_bufnrs[bufnr] then
      window_types[winnr] = "autocmd"
      return { winnr }
    end
    return {}
  end)
  t:patch_table(vim.fn, "win_gettype", function(winnr)
    return window_types[winnr] or ""
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    events = type(events) == "table" and events or { events }
    for _, event in ipairs(events) do
      ctx.callbacks[event] = opts.callback
    end
    return 1
  end)

  ctx.emit = function(bufnr)
    assert(lint_schedule_subscriber):next(bufnr, nil)
  end
  ctx.flush = function(index)
    local timer = assert(ctx.timers[index or #ctx.timers])
    if timer.scheduled then
      timer.scheduled = false
      timer.callback()
    end
  end
  ctx.set_visibility = function(bufnr, kind)
    visible_bufnrs[bufnr] = kind == "visible" and true or nil
    autocmd_bufnrs[bufnr] = kind == "autocmd" and true or nil
  end

  ctx.plugin = assert(loadfile("lua/era/plugin/nvim-lint.lua"))()
  ctx.plugin.config(ctx.plugin, {})
  return ctx
end

t:test("setup schedules the current buffer once and replaces owned resources", function()
  local bufnr = create_buffer("lua")
  vim.api.nvim_set_current_buf(bufnr)

  local ctx = setup()
  t.assert_eq(true, ctx.subscription_ignore_initial, "ignore initial notification")
  t.assert_eq(1, #ctx.timers, "initial timer")
  t.assert_eq(1, ctx.timers[1].schedule_count, "initial schedule")

  ctx.flush()
  t.assert_eq(1, #ctx.calls, "initial lint")
  t.assert_eq(bufnr, ctx.calls[1].bufnr, "initial buffer")

  ctx.plugin.config(ctx.plugin, {})
  t.assert_eq(1, ctx.timers[1].dispose_count, "old timer disposed")
  t.assert_eq(1, ctx.subscriptions[1].unsubscribe_count, "old subscription removed")
  t.assert_eq(2, #ctx.timers, "replacement timer")
  t.assert_eq(1, ctx.timers[2].schedule_count, "replacement initial schedule")
end)

t:test("passive hidden buffers wait until visible and ignore the autocmd window", function()
  local current = create_buffer("json")
  local markdown = create_buffer("markdown")
  local lua = create_buffer("lua")
  vim.api.nvim_set_current_buf(current)

  local ctx = setup()
  ctx.flush()
  ctx.calls = {}

  ctx.set_visibility(markdown, "autocmd")
  ctx.callbacks.BufReadPost({ buf = markdown })
  ctx.callbacks.BufReadPost({ buf = markdown })
  ctx.callbacks.BufReadPost({ buf = lua })
  ctx.callbacks.BufWinEnter({ buf = markdown })
  ctx.flush()
  t.assert_eq(0, #ctx.calls, "autocmd window passive lint count")

  ctx.set_visibility(markdown, "visible")
  ctx.callbacks.BufWinEnter({ buf = markdown })
  ctx.callbacks.BufWinEnter({ buf = markdown })
  ctx.set_visibility(lua, "visible")
  ctx.callbacks.BufWinEnter({ buf = lua })
  ctx.flush()

  t.assert_eq(2, #ctx.calls, "distinct buffer count")
  local calls = {} ---@type table<integer, { bufnr: integer, name: string, names: string[] }>
  for _, call in ipairs(ctx.calls) do
    calls[call.bufnr] = call
  end
  t.assert_true(calls[markdown] ~= nil, "markdown lint retained")
  t.assert_true(calls[lua] ~= nil, "lua lint retained")
  t.assert_eq("markdown-lint", calls[markdown].names[1], "markdown linter context")
  t.assert_eq("lua-lint", calls[lua].names[1], "lua linter context")
  t.assert_eq(current, vim.api.nvim_get_current_buf(), "current buffer restored")
end)

t:test("explicit write and insert events retain hidden target buffers", function()
  local current = create_buffer("json")
  local markdown = create_buffer("markdown")
  local lua = create_buffer("lua")
  vim.api.nvim_set_current_buf(current)

  local ctx = setup()
  ctx.flush()
  ctx.calls = {}

  ctx.callbacks.BufWritePost({ buf = markdown })
  ctx.callbacks.BufWritePost({ buf = markdown })
  ctx.callbacks.InsertLeave({ buf = lua })
  ctx.flush()

  t.assert_eq(2, #ctx.calls, "explicit buffer count")
  local calls = {} ---@type table<integer, { bufnr: integer, name: string, names: string[] }>
  for _, call in ipairs(ctx.calls) do
    calls[call.bufnr] = call
  end
  t.assert_true(calls[markdown] ~= nil, "hidden write lint retained")
  t.assert_true(calls[lua] ~= nil, "insert lint retained")
end)

t:test("manual refresh preserves the emitted buffer", function()
  local current = create_buffer("json")
  local target = create_buffer("lua")
  vim.api.nvim_set_current_buf(current)

  local ctx = setup()
  ctx.flush()
  ctx.calls = {}

  ctx.emit(target)
  ctx.flush()

  t.assert_eq(1, #ctx.calls, "manual lint count")
  t.assert_eq(target, ctx.calls[1].bufnr, "manual lint buffer")
  t.assert_eq(current, vim.api.nvim_get_current_buf(), "manual current buffer restored")
end)

t:test("invalid and unloaded buffers are skipped before entering buffer context", function()
  local current = create_buffer("json")
  local unloaded = create_buffer("lua", false)
  vim.api.nvim_set_current_buf(current)

  local ctx = setup()
  ctx.flush()
  ctx.calls = {}

  local buf_call_count = 0
  local original_buf_call = vim.api.nvim_buf_call
  t:patch_table(vim.api, "nvim_buf_call", function(...)
    buf_call_count = buf_call_count + 1
    return original_buf_call(...)
  end)

  ctx.callbacks.BufReadPost({ buf = unloaded })
  ctx.callbacks.BufReadPost({ buf = 999999 })
  ctx.flush()

  t.assert_eq(0, buf_call_count, "buffer context calls")
  t.assert_eq(0, #ctx.calls, "lint calls")
end)

t:test("one buffer failure does not suppress another pending buffer", function()
  local current = create_buffer("json")
  local failed = create_buffer("markdown")
  local successful = create_buffer("lua")
  vim.api.nvim_set_current_buf(current)

  local ctx = setup()
  ctx.flush()
  ctx.calls = {}

  local original_buf_call = vim.api.nvim_buf_call
  t:patch_table(vim.api, "nvim_buf_call", function(bufnr, callback)
    if bufnr == failed then
      error("buffer failure")
    end
    return original_buf_call(bufnr, callback)
  end)

  ctx.callbacks.BufWritePost({ buf = failed })
  ctx.callbacks.BufWritePost({ buf = successful })
  ctx.flush()

  t.assert_eq(1, #ctx.errors, "reported buffer failure")
  t.assert_eq(failed, ctx.errors[1].details.bufnr, "failed buffer context")
  t.assert_eq(1, #ctx.calls, "successful buffer still linted")
  t.assert_eq(successful, ctx.calls[1].bufnr, "successful buffer")
end)

t:run()
