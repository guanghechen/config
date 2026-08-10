---@diagnostic disable: undefined-global
--- Test for era.m.minimap.handler.search module
--- Run with: nvim -l lua/__test__/era/m/minimap/handler/search.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.minimap.handler.search")

---@class __test__.era.m.minimap.handler.search.Context
---@field public Handler era.m.minimap.handler.search
---@field public lines table<integer, string[]>
---@field public renders table<integer, era.m.minimap.IMark[][]>
---@field public ticks table<integer, integer>
---@field public winbuf table<integer, integer>
---@field public emit fun(event: string, args: table): nil
---@field public flush fun(): nil
---@field public press fun(key: string): nil
---@field public switch_on_read fun(bufnr: integer, next_bufnr: integer): nil

---@return __test__.era.m.minimap.handler.search.Context
local function setup()
  local attached = {} ---@type table<integer, boolean>
  local autocmds = {} ---@type table<string, { group: string, pattern: string|nil, callback: function }[]>
  local lines = {} ---@type table<integer, string[]>
  local on_key_callbacks = {} ---@type table<integer, function>
  local renders = {} ---@type table<integer, era.m.minimap.IMark[][]>
  local scheduled = {} ---@type function[]
  local ticks = {} ---@type table<integer, integer>
  local valid = {} ---@type table<integer, boolean>
  local winbuf = {} ---@type table<integer, integer>
  local group_names = {} ---@type table<integer, string>
  local next_group = 0 ---@type integer
  local next_on_key_ns = 0 ---@type integer
  local switch_bufnr = nil ---@type integer|nil
  local switch_next_bufnr = nil ---@type integer|nil

  local function schedule(callback)
    scheduled[#scheduled + 1] = callback
  end

  local function emit(event, args, pattern)
    local pending = vim.list_slice(autocmds[event] or {})
    for _, autocmd in ipairs(pending) do
      if not pattern or autocmd.pattern == pattern then
        autocmd.callback(args or {})
      end
    end
  end

  t:patch_global("stl", {
    async = {
      ipairs = ipairs,
      pairs = pairs,
      run = function(callback)
        callback()
      end,
    },
  })
  t:patch_table(package.loaded, "era.m.minimap.util", {
    row_to_barpos = function(_, row)
      return row
    end,
    winbuf_pred = function(bufnr, winnr)
      local changedtick = ticks[bufnr]
      return function()
        if valid[bufnr] ~= true or ticks[bufnr] ~= changedtick then
          return false
        end
        if winnr and (valid[winnr] ~= true or winbuf[winnr] ~= bufnr) then
          return false
        end
      end
    end,
  })
  t:patch_table(package.loaded, "era.m.minimap.view", {
    is_attached = function(winnr)
      return attached[winnr] == true
    end,
    render_handler = function(winnr, _, _, marks)
      renders[winnr] = renders[winnr] or {}
      renders[winnr][#renders[winnr] + 1] = marks
    end,
  })

  t:patch_table(
    vim,
    "b",
    setmetatable({}, {
      __index = function(_, bufnr)
        return { changedtick = ticks[bufnr] }
      end,
    })
  )
  t:patch_table(vim, "schedule", schedule)
  t:patch_table(vim, "schedule_wrap", function(callback)
    return function(...)
      local args = { ... }
      schedule(function()
        callback(unpack(args))
      end)
    end
  end)
  t:patch_table(vim, "on_key", function(callback, ns)
    if callback == nil then
      on_key_callbacks[ns] = nil
      return ns
    end
    next_on_key_ns = next_on_key_ns + 1
    on_key_callbacks[next_on_key_ns] = callback
    return next_on_key_ns
  end)
  t:patch_table(vim.uv, "new_timer", function()
    return {
      start = function() end,
      stop = function() end,
      close = function() end,
    }
  end)
  t:patch_table(vim.v, "hlsearch", 1)
  t:patch_table(vim.o, "hlsearch", true)
  t:patch_table(vim.o, "ignorecase", false)
  t:patch_table(vim.o, "incsearch", true)
  t:patch_table(vim.o, "smartcase", false)
  t:patch_table(vim.o, "updatetime", 100)
  t:patch_table(vim.fn, "getreg", function()
    return "needle"
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ""
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "n" }
  end)
  t:patch_table(vim.api, "nvim_buf_get_lines", function(bufnr)
    if switch_bufnr == bufnr then
      winbuf[101] = switch_next_bufnr
      switch_bufnr = nil
      switch_next_bufnr = nil
    end
    return lines[bufnr] or {}
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return valid[bufnr] == true
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return valid[winnr] == true
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function(winnr)
    return winbuf[winnr]
  end)
  t:patch_table(vim.api, "nvim_win_get_cursor", function()
    return { 1, 0 }
  end)
  t:patch_table(vim.api, "nvim_create_augroup", function(name)
    next_group = next_group + 1
    group_names[next_group] = name
    return next_group
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    if type(events) == "string" then
      events = { events }
    end
    for _, event in ipairs(events) do
      autocmds[event] = autocmds[event] or {}
      autocmds[event][#autocmds[event] + 1] = {
        group = group_names[opts.group],
        pattern = opts.pattern,
        callback = opts.callback,
      }
    end
    return 1
  end)
  t:patch_table(vim.api, "nvim_clear_autocmds", function(opts)
    local group = group_names[opts.group] or opts.group
    for event, entries in pairs(autocmds) do
      autocmds[event] = vim.tbl_filter(function(entry)
        return entry.group ~= group
      end, entries)
    end
  end)
  t:patch_table(vim.api, "nvim_exec_autocmds", function(event, opts)
    emit(event, { data = opts.data }, opts.pattern)
  end)

  local Handler = assert(loadfile("lua/era/m/minimap/handler/search.lua"))()
  Handler.ns = 1
  Handler.config = {}

  valid[11] = true
  valid[12] = true
  valid[101] = true
  attached[101] = true
  ticks[11] = 1
  ticks[12] = 1
  winbuf[101] = 11
  lines[11] = { "needle" }
  lines[12] = { "no match" }

  return {
    Handler = Handler,
    lines = lines,
    renders = renders,
    ticks = ticks,
    winbuf = winbuf,
    emit = function(event, args)
      emit(event, args)
    end,
    flush = function()
      local pending = scheduled
      scheduled = {}
      for _, callback in ipairs(pending) do
        callback()
      end
    end,
    press = function(key)
      for _, callback in pairs(on_key_callbacks) do
        callback(key)
      end
    end,
    switch_on_read = function(bufnr, next_bufnr)
      switch_bufnr = bufnr
      switch_next_bufnr = next_bufnr
    end,
  }
end

t:test("BufWinEnter renders search markers for the new buffer", function()
  local ctx = setup()
  ctx.Handler.attach(101)
  t.assert_eq(1, #ctx.renders[101][1], "old buffer marker count")

  ctx.winbuf[101] = 12
  ctx.emit("BufWinEnter", { buf = 12 })
  ctx.flush()

  t.assert_eq(2, #ctx.renders[101], "new buffer rendered")
  t.assert_eq(0, #ctx.renders[101][2], "old markers cleared")
end)

t:test("an old-buffer render cannot publish after the window switches", function()
  local ctx = setup()
  ctx.Handler.attach(101)
  t.assert_eq(1, #ctx.renders[101], "initial render count")

  ctx.ticks[11] = 2
  ctx.switch_on_read(11, 12)
  ctx.press("n")
  ctx.flush()

  t.assert_eq(12, ctx.winbuf[101], "window switched buffers")
  t.assert_eq(1, #ctx.renders[101], "stale render suppressed")
end)

t:run()
