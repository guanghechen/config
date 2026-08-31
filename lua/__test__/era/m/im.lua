---@diagnostic disable: undefined-global
--- Test for era.m.im composition and lifecycle
--- Run with: nvim -l lua/__test__/era/m/im.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.im")
local reports = {} ---@type table[]

bootstrap.with_runtime(t, {
  dot = {
    path = {
      locate_config_filepath = function(filename)
        return "/config/" .. filename
      end,
    },
  },
  stl = {
    env = { IS_X64 = true, IS_X86 = false },
    reporter = {
      error = function(report)
        reports[#reports + 1] = report
      end,
    },
  },
})

---@param module_name                   string
local function unload(module_name)
  t:patch_table(package.loaded, module_name, nil)
end

---@param use_wsl                       boolean|nil
---@param setup_error                   string|nil
local function setup_lifecycle(use_wsl, setup_error)
  reports = {}
  local callbacks = {} ---@type table<string, fun()>
  local scheduled = {} ---@type fun()[]
  local selected_input_methods = {} ---@type era.m.im.InputMethod[]
  local restored_snapshots = {} ---@type era.m.im.Snapshot[]
  local current_snapshot = "source.one" ---@type era.m.im.Snapshot
  local current_input_method = "Chinese" ---@type era.m.im.InputMethod
  local auto_im = true ---@type boolean
  local active_subscriber = nil ---@type stl.c.ISubscriber|nil
  local unsubscribe_count = 0 ---@type integer
  local mode = "n" ---@type string
  local backend_errors = {} ---@type table<string, string|nil>
  local setup_executables = {} ---@type string[]

  local auto_im_observable = {
    snapshot = function()
      return auto_im
    end,
    subscribe = function(_, subscriber)
      active_subscriber = subscriber
      local unsubscribed = false
      return {
        unsubscribe = function()
          if unsubscribed then
            return
          end
          unsubscribed = true
          unsubscribe_count = unsubscribe_count + 1
          if active_subscriber == subscriber then
            active_subscriber = nil
          end
        end,
      }
    end,
  }

  local backend = {
    setup = function(options)
      setup_executables[#setup_executables + 1] = options.executable
      if setup_error ~= nil then
        return nil, setup_error
      end
      return true, nil
    end,
    capture = function()
      local err = backend_errors.capture
      if err ~= nil then
        return nil, err
      end
      return current_snapshot, nil
    end,
    restore = function(snapshot)
      local err = backend_errors.restore
      if err ~= nil then
        return nil, err
      end
      restored_snapshots[#restored_snapshots + 1] = snapshot
      return true, nil
    end,
    is_input_method = function(snapshot, input_method)
      return snapshot == "source.english" and input_method == "English"
    end,
    get_input_method = function()
      local err = backend_errors.get_input_method
      if err ~= nil then
        return nil, err
      end
      return current_input_method, nil
    end,
    set_input_method = function(input_method)
      local err = backend_errors.set_input_method
      if err ~= nil then
        return nil, err
      end
      selected_input_methods[#selected_input_methods + 1] = input_method
      return true, nil
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
    env = {
      IS_OSX = not use_wsl,
      IS_WSL = not not use_wsl,
      IS_WIN = false,
      IS_NIX = false,
    },
    nvim = {
      fn = {
        augroup = function()
          return 1
        end,
      },
    },
    reporter = {
      error = function(report)
        reports[#reports + 1] = report
      end,
    },
  })
  bootstrap.with_dot(t, {
    context = {
      behavior = {
        auto_im = auto_im_observable,
      },
    },
  })
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    callbacks[events] = opts.callback
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = mode }
  end)
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_global("yoz", { im = backend })
  unload("era.m.im")

  local im = require("era.m.im")
  im.dressing()

  return {
    im = im,
    callbacks = callbacks,
    reports = reports,
    restored_snapshots = restored_snapshots,
    scheduled = scheduled,
    selected_input_methods = selected_input_methods,
    setup_executables = setup_executables,
    flush = function()
      local callback = table.remove(scheduled, 1)
      if callback ~= nil then
        callback()
      end
    end,
    get_unsubscribe_count = function()
      return unsubscribe_count
    end,
    set_auto_im = function(enabled)
      local previous = auto_im
      auto_im = enabled
      if active_subscriber ~= nil then
        active_subscriber:next(enabled, previous)
      end
    end,
    set_backend_error = function(subject, err)
      backend_errors[subject] = err
    end,
    set_current_snapshot = function(snapshot)
      current_snapshot = snapshot
    end,
    set_mode = function(next_mode)
      mode = next_mode
    end,
  }
end

t:test("public interface hides source operations and reports backend failures", function()
  local ctx = setup_lifecycle()

  t.assert_eq("function", type(ctx.im.get_input_method), "get input method interface")
  t.assert_eq("function", type(ctx.im.set_input_method), "set input method interface")
  t.assert_nil(ctx.im.capture, "capture implementation")
  t.assert_nil(ctx.im.restore, "restore implementation")
  t.assert_nil(ctx.im.current, "source getter implementation")
  t.assert_nil(ctx.im.select, "source setter implementation")
  t.assert_eq("Chinese", ctx.im.get_input_method(), "forwarded input method")

  ctx.set_backend_error("set_input_method", "selection failed")
  ctx.im.set_input_method("English")
  t.assert_eq(1, #ctx.reports, "reported public failure")
  t.assert_eq("set_input_method", ctx.reports[1].subject, "public failure subject")
end)

t:test("lifecycle: captures and restores the insert snapshot", function()
  local ctx = setup_lifecycle()

  ctx.callbacks.InsertEnter()
  t.assert_eq(0, #ctx.scheduled, "first insert restore")

  ctx.set_current_snapshot("source.chinese.token")
  ctx.callbacks.InsertLeave()
  t.assert_eq("English", ctx.selected_input_methods[1], "normal input method")

  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  t.assert_eq(1, #ctx.scheduled, "deferred restore")
  ctx.flush()
  t.assert_eq("source.chinese.token", ctx.restored_snapshots[1], "restored snapshot")
end)

t:test("lifecycle: invalidates stale restores on mode and setting changes", function()
  local ctx = setup_lifecycle()

  ctx.callbacks.InsertLeave()
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  ctx.set_mode("n")
  ctx.callbacks.InsertLeave()
  ctx.flush()
  t.assert_eq(0, #ctx.restored_snapshots, "mode-invalidated restore")

  ctx.set_current_snapshot("source.chinese.next")
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  ctx.set_auto_im(false)
  ctx.flush()
  t.assert_eq(0, #ctx.restored_snapshots, "setting-invalidated restore")

  ctx.set_auto_im(true)
  ctx.callbacks.InsertEnter()
  t.assert_eq(0, #ctx.scheduled, "cleared snapshot")
end)

t:test("lifecycle: skips restore for an English snapshot", function()
  local ctx = setup_lifecycle()

  ctx.set_current_snapshot("source.english")
  ctx.callbacks.InsertLeave()
  t.assert_eq(0, #ctx.selected_input_methods, "redundant English selection")
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  t.assert_eq(0, #ctx.scheduled, "English snapshot restore")
end)

t:test("lifecycle: FocusGained affects command modes only", function()
  local ctx = setup_lifecycle()

  for _, mode in ipairs({ "n", "no", "nov", "noV", "no" .. string.char(22), "v", "V", string.char(22) }) do
    ctx.set_mode(mode)
    ctx.callbacks.FocusGained()
  end
  t.assert_eq(8, #ctx.selected_input_methods, "command-mode selections")

  for _, mode in ipairs({
    "niI",
    "niR",
    "niV",
    "nt",
    "ntT",
    "vs",
    "Vs",
    string.char(22) .. "s",
    "i",
    "R",
    "t",
    "c",
    "s",
    "S",
    string.char(19),
  }) do
    ctx.set_mode(mode)
    ctx.callbacks.FocusGained()
  end
  t.assert_eq(8, #ctx.selected_input_methods, "text-entry-mode selections")
end)

t:test("lifecycle: repeated dressing replaces the auto-im subscription", function()
  local ctx = setup_lifecycle()

  ctx.im.dressing()
  t.assert_eq(1, ctx.get_unsubscribe_count(), "previous subscription")
end)

t:test("wsl: composition installs the lifecycle", function()
  local ctx = setup_lifecycle(true)

  t.assert_eq("/config/bin/wsl.yoz-im.exe", ctx.setup_executables[1], "helper executable")
  t.assert_eq("function", type(ctx.callbacks.InsertLeave), "InsertLeave callback")
  t.assert_eq("function", type(ctx.callbacks.InsertEnter), "InsertEnter callback")
  t.assert_eq("function", type(ctx.callbacks.FocusGained), "FocusGained callback")
end)

t:test("wsl: setup failure reports and leaves lifecycle disabled", function()
  local ctx = setup_lifecycle(true, "setup failed")

  t.assert_eq("/config/bin/wsl.yoz-im.exe", ctx.setup_executables[1], "helper executable")
  t.assert_nil(ctx.callbacks.InsertLeave, "InsertLeave callback")
  t.assert_eq(1, #ctx.reports, "setup report count")
  t.assert_eq("setup", ctx.reports[1].subject, "setup report subject")
end)

t:test("linux: unconditional composition safely no-ops without a backend", function()
  local created_autocmd = false
  bootstrap.with_stl(t, {
    env = { IS_OSX = false, IS_WSL = false, IS_WIN = false, IS_NIX = true },
  })
  t:patch_global("yoz", {})
  t:patch_table(vim.api, "nvim_create_autocmd", function()
    created_autocmd = true
    return 1
  end)
  unload("era.m.im")

  local im = require("era.m.im")
  t.assert_nil(im.get_input_method(), "unsupported input method")
  im.set_input_method("English")
  im.dressing()
  t.assert_false(created_autocmd, "unsupported lifecycle")
end)

t:run()
