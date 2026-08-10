---@diagnostic disable: undefined-global
--- Test for era.m.minimap.handler.diagnostic module
--- Run with: nvim -l lua/__test__/era/m/minimap/handler/diagnostic.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.minimap.handler.diagnostic")

---@class __test__.era.m.minimap.handler.diagnostic.Context
---@field public Handler era.m.minimap.handler.diagnostic
---@field public callbacks table<string, fun(args: { buf: integer })>
---@field public cleared table<string, integer>
---@field public debounces { delay: integer, disposed: boolean, dispose_count: integer, pending: any[]|nil }[]
---@field public diagnostics table<integer, vim.Diagnostic[]>
---@field public renders table<integer, { bufnr: integer, marks: era.m.minimap.IMark[] }[]>
---@field public attached table<integer, boolean>
---@field public valid table<integer, boolean>
---@field public winbuf table<integer, integer>
---@field public emit fun(bufnr: integer): nil
---@field public flush fun(): nil

---@return __test__.era.m.minimap.handler.diagnostic.Context
local function setup()
  local diagnostic = vim.diagnostic
  local callbacks = {} ---@type table<string, fun(args: { buf: integer })>
  local cleared = {} ---@type table<string, integer>
  local debounces = {} ---@type { delay: integer, disposed: boolean, dispose_count: integer, callback: fun(...), pending: any[]|nil }[]
  local diagnostics = {} ---@type table<integer, vim.Diagnostic[]>
  local renders = {} ---@type table<integer, { bufnr: integer, marks: era.m.minimap.IMark[] }[]>
  local attached = {} ---@type table<integer, boolean>
  local valid = {} ---@type table<integer, boolean>
  local winbuf = {} ---@type table<integer, integer>
  local group_names = {} ---@type table<integer, string>
  local next_group = 0 ---@type integer

  local function callable(callback, delay)
    local state = {
      delay = delay,
      disposed = false,
      dispose_count = 0,
      callback = callback,
      pending = nil,
    }
    local value = {
      dispose = function()
        if state.disposed then
          return
        end
        state.disposed = true
        state.dispose_count = state.dispose_count + 1
        state.pending = nil
      end,
    }
    debounces[#debounces + 1] = state
    return setmetatable(value, {
      __call = function(_, ...)
        if not state.disposed then
          state.pending = { ... }
        end
      end,
    })
  end

  t:patch_global("stl", {
    async = {
      auto_ipairs = function(items)
        return ipairs(items)
      end,
      run = function(callback)
        callback()
      end,
    },
    timer = {
      debounce = callable,
    },
  })

  t:patch_table(package.loaded, "era.m.minimap.util", {
    row_to_barpos = function(_, row)
      return row
    end,
    winbuf_pred = function(bufnr, winnr)
      return function()
        return valid[winnr] == true and winbuf[winnr] == bufnr
      end
    end,
  })
  t:patch_table(package.loaded, "era.m.minimap.view", {
    is_attached = function(winnr)
      return attached[winnr] == true
    end,
    render_handler = function(winnr, _, _, marks)
      renders[winnr] = renders[winnr] or {}
      renders[winnr][#renders[winnr] + 1] = {
        bufnr = winbuf[winnr],
        marks = marks,
      }
    end,
  })

  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return valid[winnr] == true
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function(winnr)
    return winbuf[winnr]
  end)
  t:patch_table(vim.api, "nvim_create_augroup", function(name)
    next_group = next_group + 1
    group_names[next_group] = name
    return next_group
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    t.assert_eq(2, #events, "diagnostic autocmd event count")
    t.assert_eq("DiagnosticChanged", events[1], "diagnostic change event")
    t.assert_eq("BufWinEnter", events[2], "buffer enter event")
    callbacks[group_names[opts.group]] = opts.callback
    return 1
  end)
  t:patch_table(vim.api, "nvim_clear_autocmds", function(opts)
    local name = group_names[opts.group] or opts.group
    callbacks[name] = nil
    cleared[name] = (cleared[name] or 0) + 1
  end)
  t:patch_table(diagnostic, "get", function(bufnr)
    return diagnostics[bufnr] or {}
  end)

  local Handler = assert(loadfile("lua/era/m/minimap/handler/diagnostic.lua"))()
  Handler.ns = 1
  Handler.config = {}

  return {
    Handler = Handler,
    callbacks = callbacks,
    cleared = cleared,
    debounces = debounces,
    diagnostics = diagnostics,
    renders = renders,
    attached = attached,
    valid = valid,
    winbuf = winbuf,
    emit = function(bufnr)
      local pending = vim.tbl_values(callbacks)
      for _, callback in ipairs(pending) do
        callback({ buf = bufnr })
      end
    end,
    flush = function()
      for _, debounce in ipairs(debounces) do
        local args = debounce.pending
        debounce.pending = nil
        if args and not debounce.disposed then
          debounce.callback(unpack(args))
        end
      end
    end,
  }
end

local function attach(ctx, winnr, bufnr)
  ctx.valid[winnr] = true
  ctx.attached[winnr] = true
  ctx.winbuf[winnr] = bufnr
  ctx.Handler.attach(winnr)
end

t:test("DiagnosticChanged refreshes moved diagnostics with unchanged counts", function()
  local ctx = setup()
  ctx.diagnostics[11] = {
    { lnum = 1, severity = vim.diagnostic.severity.ERROR },
  }
  attach(ctx, 101, 11)

  t.assert_eq(1, ctx.renders[101][1].marks[1].pos, "initial diagnostic position")
  ctx.diagnostics[11] = {
    { lnum = 9, severity = vim.diagnostic.severity.ERROR },
  }
  ctx.emit(11)
  t.assert_eq(1, #ctx.renders[101], "debounced refresh")
  ctx.flush()

  t.assert_eq(2, #ctx.renders[101], "diagnostic refresh")
  t.assert_eq(9, ctx.renders[101][2].marks[1].pos, "moved diagnostic position")
  t.assert_eq(50, ctx.debounces[1].delay, "diagnostic debounce")
end)

t:test("DiagnosticChanged only refreshes windows showing the changed buffer", function()
  local ctx = setup()
  attach(ctx, 101, 11)
  attach(ctx, 102, 12)

  ctx.emit(11)
  ctx.flush()

  t.assert_eq(2, #ctx.renders[101], "matching window refreshed")
  t.assert_eq(1, #ctx.renders[102], "unrelated window unchanged")
end)

t:test("debounced refresh renders the current buffer after a window switch", function()
  local ctx = setup()
  ctx.diagnostics[11] = {
    { lnum = 1, severity = vim.diagnostic.severity.ERROR },
  }
  attach(ctx, 101, 11)
  t.assert_eq(1, #ctx.renders[101][1].marks, "old buffer marker rendered")

  ctx.emit(11)
  ctx.winbuf[101] = 12
  ctx.flush()
  t.assert_eq(2, #ctx.renders[101], "current buffer rendered")
  t.assert_eq(12, ctx.renders[101][2].bufnr, "new buffer selected")
  t.assert_eq(0, #ctx.renders[101][2].marks, "old buffer markers cleared")

  ctx.emit(11)
  ctx.flush()
  t.assert_eq(2, #ctx.renders[101], "old-buffer event ignored")

  ctx.emit(12)
  ctx.flush()
  t.assert_eq(3, #ctx.renders[101], "new-buffer event refreshed")
  t.assert_eq(12, ctx.renders[101][3].bufnr, "new buffer rendered")
end)

t:test("BufWinEnter clears markers from the previous buffer", function()
  local ctx = setup()
  ctx.diagnostics[11] = {
    { lnum = 1, severity = vim.diagnostic.severity.ERROR },
  }
  attach(ctx, 101, 11)

  ctx.winbuf[101] = 12
  ctx.emit(12)
  ctx.flush()

  t.assert_eq(2, #ctx.renders[101], "entered buffer rendered")
  t.assert_eq(12, ctx.renders[101][2].bufnr, "entered buffer selected")
  t.assert_eq(0, #ctx.renders[101][2].marks, "previous buffer markers cleared")
end)

t:test("detach clears the autocmd and disposes pending refresh", function()
  local ctx = setup()
  attach(ctx, 101, 11)
  local callback = ctx.callbacks["era_minimap_diagnostic_101"]
  t.assert_true(callback ~= nil, "diagnostic autocmd installed")

  ctx.emit(11)
  ctx.Handler.detach(101)
  t.assert_nil(ctx.callbacks["era_minimap_diagnostic_101"], "diagnostic autocmd cleared")
  t.assert_eq(1, ctx.cleared["era_minimap_diagnostic_101"], "autocmd clear count")
  t.assert_true(ctx.debounces[1].disposed, "debounce disposed")
  t.assert_eq(1, ctx.debounces[1].dispose_count, "debounce dispose count")

  callback({ buf = 11 })
  ctx.flush()
  t.assert_eq(1, #ctx.renders[101], "pending and stale callbacks suppressed")
end)

t:run()
