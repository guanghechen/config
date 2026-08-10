---@diagnostic disable: undefined-global
--- Test for era.m.minimap.handler.marks module
--- Run with: nvim -l lua/__test__/era/m/minimap/handler/marks.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.minimap.handler.marks")

---@class __test__.era.m.minimap.handler.marks.Context
---@field public Handler era.m.minimap.handler.marks
---@field public attached table<integer, boolean>
---@field public autocmds table<string, { pattern: string, callback: function }>
---@field public cleared table<string, integer>
---@field public cmd_callbacks table<string, function>
---@field public group_creates table<string, integer>
---@field public local_mappings table<string, table<string, { callback: function }>>
---@field public mappings table<string, table<string, { callback: function }>>
---@field public renders table<integer, integer>
---@field public flush fun(): nil

---@param existing? table<string, table<string, { callback: function }>>
---@return __test__.era.m.minimap.handler.marks.Context
local function setup(existing)
  local attached = {} ---@type table<integer, boolean>
  local autocmds = {} ---@type table<string, { pattern: string, callback: function }>
  local cleared = {} ---@type table<string, integer>
  local cmd_callbacks = {} ---@type table<string, function>
  local group_creates = {} ---@type table<string, integer>
  local mappings = existing or {} ---@type table<string, table<string, { callback: function }>>
  local local_mappings = {} ---@type table<string, table<string, { callback: function }>>
  local renders = {} ---@type table<integer, integer>
  local scheduled = {} ---@type function[]
  local group_names = {} ---@type table<integer, string>
  local next_group = 0 ---@type integer

  t:patch_table(package.loaded, "era.m.minimap.util", {
    on_cmd = function(cmd, _, callback)
      cmd_callbacks[cmd] = callback
    end,
    row_to_barpos = function(_, row)
      return row
    end,
  })
  t:patch_table(package.loaded, "era.m.minimap.view", {
    is_attached = function(winnr)
      return attached[winnr] == true
    end,
    render_handler = function(winnr)
      renders[winnr] = (renders[winnr] or 0) + 1
    end,
  })

  t:patch_table(vim, "schedule_wrap", function(callback)
    return function(...)
      local args = { ... }
      scheduled[#scheduled + 1] = function()
        callback(unpack(args))
      end
    end
  end)
  t:patch_table(vim.api, "nvim_get_keymap", function(mode)
    local ret = {}
    for lhs, mapping in pairs(mappings[mode] or {}) do
      ret[#ret + 1] = {
        lhs = lhs,
        callback = mapping.callback,
      }
    end
    return ret
  end)
  t:patch_table(vim.fn, "maparg", function(lhs, mode, _, dict)
    local mapping = local_mappings[mode] and local_mappings[mode][lhs] or mappings[mode] and mappings[mode][lhs]
    if dict then
      return mapping or {}
    end
    return mapping and "mapped" or ""
  end)
  t:patch_table(vim.fn, "getmarklist", function()
    return {}
  end)
  t:patch_table(vim.fn, "fnamemodify", function(path)
    return path
  end)
  t:patch_table(vim.keymap, "set", function(mode, lhs, callback)
    mappings[mode] = mappings[mode] or {}
    mappings[mode][lhs] = { callback = callback }
  end)
  t:patch_table(vim.keymap, "del", function(mode, lhs)
    mappings[mode][lhs] = nil
  end)
  t:patch_table(vim.api, "nvim_create_augroup", function(name)
    next_group = next_group + 1
    group_names[next_group] = name
    group_creates[name] = (group_creates[name] or 0) + 1
    return next_group
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    t.assert_eq("User", event, "marks refresh event")
    autocmds[group_names[opts.group]] = {
      pattern = opts.pattern,
      callback = opts.callback,
    }
    return 1
  end)
  t:patch_table(vim.api, "nvim_clear_autocmds", function(opts)
    local name = group_names[opts.group] or opts.group
    autocmds[name] = nil
    cleared[name] = (cleared[name] or 0) + 1
  end)
  t:patch_table(vim.api, "nvim_exec_autocmds", function(event, opts)
    t.assert_eq("User", event, "marks broadcast event")
    for _, autocmd in pairs(autocmds) do
      if autocmd.pattern == opts.pattern then
        autocmd.callback()
      end
    end
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return attached[winnr] == true
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function(winnr)
    return winnr + 1000
  end)
  t:patch_table(vim.api, "nvim_buf_get_name", function(bufnr)
    return "/tmp/" .. tostring(bufnr)
  end)

  local Handler = assert(loadfile("lua/era/m/minimap/handler/marks.lua"))()
  Handler.ns = 1
  Handler.config = {}

  return {
    Handler = Handler,
    attached = attached,
    autocmds = autocmds,
    cleared = cleared,
    cmd_callbacks = cmd_callbacks,
    group_creates = group_creates,
    local_mappings = local_mappings,
    mappings = mappings,
    renders = renders,
    flush = function()
      local pending = scheduled
      scheduled = {}
      for _, callback in ipairs(pending) do
        callback()
      end
    end,
  }
end

---@param ctx                         __test__.era.m.minimap.handler.marks.Context
---@param winnr                       integer
---@return nil
local function attach(ctx, winnr)
  ctx.attached[winnr] = true
  ctx.Handler.attach(winnr)
end

t:test("mark changes refresh every attached window", function()
  local ctx = setup()
  attach(ctx, 101)
  attach(ctx, 102)

  t.assert_eq("mA", ctx.mappings.n.mA.callback(), "expr mapping result")
  ctx.flush()

  t.assert_eq(2, ctx.renders[101], "first window refreshed")
  t.assert_eq(2, ctx.renders[102], "second window refreshed")

  ctx.cmd_callbacks.delm()
  ctx.flush()
  t.assert_eq(3, ctx.renders[101], "command refreshed first window")
  t.assert_eq(3, ctx.renders[102], "command refreshed second window")
end)

t:test("global resources live until the last window detaches", function()
  local ctx = setup()
  attach(ctx, 101)
  attach(ctx, 102)

  ctx.Handler.detach(101)
  ctx.attached[101] = false
  t.assert_true(ctx.mappings.n.mA ~= nil, "normal mapping retained")
  t.assert_true(ctx.mappings.x.mA ~= nil, "visual mapping retained")
  t.assert_eq(0, ctx.cleared.era_minimap_marks or 0, "global hooks retained")

  ctx.mappings.n.mA.callback()
  ctx.flush()
  t.assert_eq(1, ctx.renders[101], "detached window unchanged")
  t.assert_eq(2, ctx.renders[102], "remaining window refreshed")

  ctx.Handler.detach(102)
  ctx.attached[102] = false
  t.assert_nil(ctx.mappings.n.mA, "normal mapping removed")
  t.assert_nil(ctx.mappings.x.mA, "visual mapping removed")
  t.assert_eq(1, ctx.cleared.era_minimap_marks, "global hooks cleared")
end)

t:test("user mappings are preserved independently by mode", function()
  local normal_user = function() end
  local visual_user = function() end
  local replacement = function() end
  local ctx = setup({
    n = { mA = { callback = normal_user } },
    x = { ma = { callback = visual_user } },
  })
  attach(ctx, 101)

  t.assert_eq(normal_user, ctx.mappings.n.mA.callback, "normal user mapping retained")
  t.assert_true(ctx.mappings.x.mA ~= nil, "missing visual mapping created")
  t.assert_true(ctx.mappings.n.ma ~= nil, "missing normal mapping created")
  t.assert_eq(visual_user, ctx.mappings.x.ma.callback, "visual user mapping retained")

  ctx.mappings.n.ma = { callback = replacement }
  ctx.Handler.detach(101)
  t.assert_eq(normal_user, ctx.mappings.n.mA.callback, "normal user mapping preserved")
  t.assert_nil(ctx.mappings.x.mA, "created visual mapping removed")
  t.assert_eq(replacement, ctx.mappings.n.ma.callback, "replacement mapping preserved")
  t.assert_eq(visual_user, ctx.mappings.x.ma.callback, "visual user mapping preserved")
end)

t:test("buffer-local mappings do not hide owned global mappings", function()
  local ctx = setup()
  local local_user = function() end
  ctx.local_mappings.n = { mA = { callback = local_user } }
  attach(ctx, 101)

  t.assert_true(ctx.mappings.n.mA ~= nil, "global mapping created")
  t.assert_eq(local_user, ctx.local_mappings.n.mA.callback, "local mapping retained")

  ctx.Handler.detach(101)
  t.assert_nil(ctx.mappings.n.mA, "owned global mapping removed")
  t.assert_eq(local_user, ctx.local_mappings.n.mA.callback, "local mapping preserved")
end)

t:test("repeated attach and detach are idempotent", function()
  local ctx = setup()
  attach(ctx, 101)
  ctx.Handler.attach(101)

  t.assert_eq(1, ctx.group_creates.era_minimap_marks, "global group created once")
  t.assert_eq(1, ctx.group_creates.era_minimap_marks_101, "window group created once")
  t.assert_eq(1, ctx.renders[101], "window rendered once")

  ctx.Handler.detach(101)
  ctx.Handler.detach(101)
  t.assert_eq(1, ctx.cleared.era_minimap_marks, "global group cleared once")
  t.assert_eq(1, ctx.cleared.era_minimap_marks_101, "window group cleared once")
end)

t:run()
