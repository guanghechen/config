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

---@param options                       { use_wsl?: boolean, setup_error?: string, initial_snapshot?: era.m.im.Snapshot, with_ui?: boolean, ui_count?: integer, capture_and_select_error?: string, capture_failed?: boolean }|nil
local function setup_lifecycle(options)
  options = options or {}
  reports = {}
  local callbacks = {} ---@type table<string, fun()>
  local restored_snapshots = {} ---@type era.m.im.Snapshot[]
  local current_snapshot = options.initial_snapshot or "source.english" ---@type era.m.im.Snapshot
  local auto_im = true ---@type boolean
  local active_subscriber = nil ---@type stl.c.ISubscriber|nil
  local unsubscribe_count = 0 ---@type integer
  local capture_count = 0 ---@type integer
  local capture_and_select_count = 0 ---@type integer
  local restore_count = 0 ---@type integer
  local english_switch_count = 0 ---@type integer
  local ui_count = options.ui_count or 1 ---@type integer
  if options.with_ui == false then
    ui_count = 0
  end
  local mode = "n" ---@type string
  ---@type table<string, string|nil>
  local backend_errors = {
    capture_and_select_english = options.capture_and_select_error,
  }
  ---@type boolean
  local capture_and_select_failed = options.capture_failed == true
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
    setup = function(setup_options)
      setup_executables[#setup_executables + 1] = setup_options.executable
      if options.setup_error ~= nil then
        return nil, options.setup_error
      end
      return true, nil
    end,
    capture = function()
      capture_count = capture_count + 1
      return current_snapshot, nil
    end,
    capture_and_select_english = function()
      capture_and_select_count = capture_and_select_count + 1
      local snapshot = current_snapshot
      local err = backend_errors.capture_and_select_english
      if err ~= nil then
        if capture_and_select_failed then
          return nil, false, err
        end
        return snapshot, false, err
      end
      if snapshot:match("^source%.english") == nil then
        english_switch_count = english_switch_count + 1
      end
      current_snapshot = "source.english"
      return snapshot, true, nil
    end,
    restore = function(snapshot)
      restore_count = restore_count + 1
      local err = backend_errors.restore
      if err ~= nil then
        return nil, err
      end
      restored_snapshots[#restored_snapshots + 1] = snapshot
      current_snapshot = snapshot
      return true, nil
    end,
    is_english = function(snapshot)
      return snapshot:match("^source%.english") ~= nil
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
      IS_OSX = not options.use_wsl,
      IS_WSL = not not options.use_wsl,
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
    if type(events) == "string" then
      callbacks[events] = opts.callback
    else
      for _, event in ipairs(events) do
        callbacks[event] = opts.callback
      end
    end
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = mode }
  end)
  t:patch_table(vim.api, "nvim_list_uis", function()
    local uis = {}
    for _ = 1, ui_count do
      uis[#uis + 1] = {}
    end
    return uis
  end)
  t:patch_global("yoz", { im = backend })
  unload("era.m.im")

  local im = require("era.m.im")
  im.dressing()
  if callbacks.UIEnter ~= nil then
    callbacks.UIEnter()
  end

  return {
    im = im,
    callbacks = callbacks,
    reports = reports,
    restored_snapshots = restored_snapshots,
    setup_executables = setup_executables,
    get_backend_call_count = function()
      return capture_count + capture_and_select_count + restore_count
    end,
    get_capture_count = function()
      return capture_count
    end,
    get_capture_and_select_count = function()
      return capture_and_select_count
    end,
    get_current_snapshot = function()
      return current_snapshot
    end,
    get_english_switch_count = function()
      return english_switch_count
    end,
    get_restore_count = function()
      return restore_count
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
    set_backend_error = function(subject, err, capture_failed)
      backend_errors[subject] = err
      if subject == "capture_and_select_english" then
        capture_and_select_failed = capture_failed == true
      end
    end,
    set_current_snapshot = function(snapshot)
      current_snapshot = snapshot
    end,
    set_mode = function(next_mode)
      mode = next_mode
    end,
    set_ui_count = function(count)
      ui_count = count
    end,
  }
end

t:test("public interface exposes only lifecycle setup", function()
  local ctx = setup_lifecycle()

  t.assert_nil(rawget(ctx.im, "capture"), "capture implementation")
  t.assert_nil(rawget(ctx.im, "capture_and_select_english"), "capture and select implementation")
  t.assert_nil(rawget(ctx.im, "restore"), "restore implementation")
  t.assert_nil(rawget(ctx.im, "is_english"), "English predicate implementation")
end)

t:test("focus entry: command mode selects English with one fused call", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry" })

  t.assert_eq(1, ctx.get_capture_and_select_count(), "single fused call")
  t.assert_eq(1, ctx.get_backend_call_count(), "single backend call")
  t.assert_eq(1, ctx.get_english_switch_count(), "English selection")
  t.assert_eq("source.english", ctx.get_current_snapshot(), "focused command source")
end)

t:test("focus entry: fused capture failure reports once", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    capture_and_select_error = "capture timed out",
    capture_failed = true,
  })

  t.assert_eq(1, ctx.get_capture_and_select_count(), "single fused attempt")
  t.assert_eq(1, #ctx.reports, "single failure report")
end)

t:test("focus entry: selection failure reports once", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    capture_and_select_error = "selection failed",
  })

  t.assert_eq(1, ctx.get_capture_and_select_count(), "single fused attempt")
  t.assert_eq(1, #ctx.reports, "single failure report")
  t.assert_eq("source.non_english.entry", ctx.get_current_snapshot(), "unchanged source")
end)

t:test("insert lifecycle: captures and synchronously restores its source", function()
  local ctx = setup_lifecycle()

  -- InsertEnter callbacks observe the preceding mode through nvim_get_mode().
  ctx.callbacks.InsertEnter()
  t.assert_eq(0, ctx.get_restore_count(), "first InsertEnter")

  ctx.set_current_snapshot("source.non_english.editing")
  ctx.set_mode("n")
  ctx.callbacks.InsertLeave()
  t.assert_eq(1, ctx.get_english_switch_count(), "English selection")

  local fused_calls = ctx.get_capture_and_select_count()
  ctx.callbacks.InsertEnter()
  t.assert_eq("source.non_english.editing", ctx.restored_snapshots[1], "synchronous restore")
  t.assert_eq(fused_calls, ctx.get_capture_and_select_count(), "no InsertEnter capture")
end)

t:test("insert lifecycle: failed capture clears the restore target", function()
  local ctx = setup_lifecycle()

  ctx.set_current_snapshot("source.non_english.observed")
  ctx.callbacks.InsertLeave()
  ctx.set_backend_error("capture_and_select_english", "capture failed", true)
  ctx.callbacks.InsertLeave()

  ctx.callbacks.InsertEnter()
  t.assert_eq(0, ctx.get_restore_count(), "cleared restore target")
end)

t:test("insert lifecycle: skips redundant restore for an English source", function()
  local ctx = setup_lifecycle()

  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()

  t.assert_eq(0, ctx.get_english_switch_count(), "redundant English selection")
  t.assert_eq(0, ctx.get_restore_count(), "redundant English restore")
end)

t:test("setting lifecycle: disabling clears the Insert source", function()
  local ctx = setup_lifecycle()

  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.set_mode("i")
  ctx.set_auto_im(false)
  local calls = ctx.get_backend_call_count()
  ctx.callbacks.InsertEnter()
  ctx.set_auto_im(true)

  t.assert_eq(calls, ctx.get_backend_call_count(), "disabled and re-enabled calls")
end)

t:test("setting lifecycle: enabling reconciles a focused command mode", function()
  local ctx = setup_lifecycle()

  ctx.set_auto_im(false)
  ctx.set_current_snapshot("source.non_english.current")
  local calls = ctx.get_capture_and_select_count()
  ctx.set_auto_im(true)

  t.assert_eq(calls + 1, ctx.get_capture_and_select_count(), "reconcile call")
  t.assert_eq("source.english", ctx.get_current_snapshot(), "reconciled source")
end)

t:test("focus entry: only command modes select English", function()
  local ctx = setup_lifecycle()
  local initial_fused_count = ctx.get_capture_and_select_count()

  local function refocus(mode)
    ctx.callbacks.FocusLost()
    ctx.set_current_snapshot("source.non_english.entry")
    ctx.set_mode(mode)
    ctx.callbacks.FocusGained()
  end

  for _, mode in ipairs({ "n", "no", "nov", "noV", "no" .. string.char(22), "v", "V", string.char(22) }) do
    refocus(mode)
  end
  t.assert_eq(initial_fused_count + 8, ctx.get_capture_and_select_count(), "command-mode fused calls")
  local command_fused_count = ctx.get_capture_and_select_count()

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
    refocus(mode)
  end
  t.assert_eq(command_fused_count, ctx.get_capture_and_select_count(), "other-mode fused calls")
end)

t:test("focus exit: leaves the external source untouched", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry" })
  local calls = ctx.get_backend_call_count()

  ctx.set_current_snapshot("source.external.current")
  ctx.callbacks.FocusLost()

  t.assert_eq(calls, ctx.get_backend_call_count(), "focus exit backend calls")
  t.assert_eq("source.external.current", ctx.get_current_snapshot(), "external source")
end)

t:test("focus entry: Insert mode restores the Neovim source", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.FocusLost()

  ctx.set_current_snapshot("source.external.current")
  ctx.set_mode("i")
  ctx.callbacks.FocusGained()

  t.assert_eq("source.non_english.editing", ctx.restored_snapshots[1], "Neovim Insert source")
  t.assert_eq("source.non_english.editing", ctx.get_current_snapshot(), "focused source")
end)

t:test("focus entry: Insert mode restores a known English source", function()
  local ctx = setup_lifecycle()
  ctx.callbacks.InsertLeave()
  ctx.callbacks.FocusLost()

  ctx.set_current_snapshot("source.non_english.external")
  ctx.set_mode("i")
  ctx.callbacks.FocusGained()

  t.assert_eq("source.english", ctx.restored_snapshots[1], "English Insert source")
end)

t:test("focus lifecycle: only the last UILeave releases ownership", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry", ui_count = 2 })

  ctx.set_ui_count(1)
  ctx.callbacks.UILeave()
  ctx.callbacks.FocusGained()
  t.assert_eq(1, ctx.get_capture_and_select_count(), "remaining UI keeps focus state")

  ctx.set_ui_count(0)
  ctx.callbacks.UILeave()
  t.assert_eq(0, ctx.get_restore_count(), "last UI does not restore")

  ctx.set_current_snapshot("source.non_english.next")
  ctx.set_ui_count(1)
  ctx.callbacks.UIEnter()
  t.assert_eq(2, ctx.get_capture_and_select_count(), "reattach reconciles source")
end)

t:test("focus lifecycle: duplicate boundary events are idempotent", function()
  local ctx = setup_lifecycle()

  ctx.callbacks.FocusGained()
  ctx.callbacks.VimResume()
  t.assert_eq(1, ctx.get_capture_and_select_count(), "duplicate focus entry")

  ctx.callbacks.FocusLost()
  ctx.callbacks.VimSuspend()
  ctx.callbacks.VimLeavePre()
  t.assert_eq(0, ctx.get_restore_count(), "duplicate focus exit")

  ctx.callbacks.FocusGained()
  ctx.callbacks.VimResume()
  t.assert_eq(2, ctx.get_capture_and_select_count(), "next focus entry")
end)

t:test("focus lifecycle: headless setup does not touch the source", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry", with_ui = false })

  t.assert_eq(0, ctx.get_backend_call_count(), "headless backend calls")
end)

t:test("restore failure is reported", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.set_backend_error("restore", "restore failed")

  ctx.callbacks.InsertEnter()

  t.assert_eq(1, ctx.get_restore_count(), "restore attempt")
  t.assert_eq("InsertEnter", ctx.reports[1].subject, "restore report subject")
end)

t:test("lifecycle: repeated dressing replaces the auto-im subscription", function()
  local ctx = setup_lifecycle()
  local calls = ctx.get_backend_call_count()

  ctx.im.dressing()

  t.assert_eq(1, ctx.get_unsubscribe_count(), "previous subscription")
  t.assert_eq(calls, ctx.get_backend_call_count(), "redundant backend calls")
end)

t:test("wsl: composition installs the lifecycle", function()
  local ctx = setup_lifecycle({ use_wsl = true })

  t.assert_eq("/config/bin/wsl.yoz-im.exe", ctx.setup_executables[1], "helper executable")
  t.assert_eq("function", type(ctx.callbacks.InsertLeave), "InsertLeave callback")
  t.assert_eq("function", type(ctx.callbacks.InsertEnter), "InsertEnter callback")
  t.assert_eq("function", type(ctx.callbacks.UIEnter), "UIEnter callback")
  t.assert_eq("function", type(ctx.callbacks.FocusGained), "FocusGained callback")
  t.assert_eq("function", type(ctx.callbacks.FocusLost), "FocusLost callback")
  t.assert_eq("function", type(ctx.callbacks.VimResume), "VimResume callback")
  t.assert_eq("function", type(ctx.callbacks.VimSuspend), "VimSuspend callback")
  t.assert_eq("function", type(ctx.callbacks.VimLeavePre), "VimLeavePre callback")
  t.assert_eq("function", type(ctx.callbacks.UILeave), "UILeave callback")
end)

t:test("wsl: setup failure reports and leaves lifecycle disabled", function()
  local ctx = setup_lifecycle({ use_wsl = true, setup_error = "setup failed" })

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
  im.dressing()
  t.assert_false(created_autocmd, "unsupported lifecycle")
end)

t:run()
