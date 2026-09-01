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

---@param options                       { use_wsl?: boolean, setup_error?: string, initial_snapshot?: era.m.im.Snapshot, with_ui?: boolean, ui_count?: integer, capture_and_select_error?: string, capture_failed?: boolean, capture_duration_ms?: number }|nil
local function setup_lifecycle(options)
  options = options or {}
  reports = {}
  local callbacks = {} ---@type table<string, fun()>
  local scheduled = {} ---@type fun()[]
  local restored_snapshots = {} ---@type era.m.im.Snapshot[]
  local current_snapshot = options.initial_snapshot or "source.english" ---@type era.m.im.Snapshot
  local auto_im = true ---@type boolean
  local active_subscriber = nil ---@type stl.c.ISubscriber|nil
  local unsubscribe_count = 0 ---@type integer
  local capture_count = 0 ---@type integer
  local capture_and_select_count = 0 ---@type integer
  local capture_duration_ms = options.capture_duration_ms or 0 ---@type number
  local english_switch_count = 0 ---@type integer
  local now = 0 ---@type number
  local ui_count = options.ui_count or 1 ---@type integer
  if options.with_ui == false then
    ui_count = 0
  end
  local mode = "n" ---@type string
  local backend_errors = {
    capture_and_select_english = options.capture_and_select_error,
  } ---@type table<string, string|nil>
  local capture_failures = {
    capture_and_select_english = options.capture_failed,
  } ---@type table<string, boolean|nil>
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
      now = now + capture_duration_ms * 1e6
      local err = backend_errors.capture
      if err ~= nil then
        return nil, err
      end
      return current_snapshot, nil
    end,
    capture_and_select_english = function()
      capture_and_select_count = capture_and_select_count + 1
      now = now + capture_duration_ms * 1e6
      local snapshot = current_snapshot
      local err = backend_errors.capture_and_select_english
      if err ~= nil then
        if capture_failures.capture_and_select_english then
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
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.uv, "hrtime", function()
    return now
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
    scheduled = scheduled,
    setup_executables = setup_executables,
    advance_ms = function(duration)
      now = now + duration * 1e6
    end,
    flush = function()
      local callback = table.remove(scheduled, 1)
      if callback ~= nil then
        callback()
      end
    end,
    get_unsubscribe_count = function()
      return unsubscribe_count
    end,
    get_capture_count = function()
      return capture_count + capture_and_select_count
    end,
    get_capture_and_select_count = function()
      return capture_and_select_count
    end,
    get_english_switch_count = function()
      return english_switch_count
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
      capture_failures[subject] = capture_failed
    end,
    set_current_snapshot = function(snapshot)
      current_snapshot = snapshot
    end,
    set_capture_duration_ms = function(duration)
      capture_duration_ms = duration
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

  t.assert_nil(ctx.im.capture, "capture implementation")
  t.assert_nil(ctx.im.capture_and_select_english, "capture and select implementation")
  t.assert_nil(ctx.im.restore, "restore implementation")
  t.assert_nil(ctx.im.is_english, "English predicate implementation")
end)

t:test("focus lifecycle: fused capture failure reports once without a fallback process", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    capture_and_select_error = "capture timed out",
    capture_failed = true,
  })

  t.assert_eq(1, ctx.get_capture_and_select_count(), "single fused attempt")
  t.assert_eq(1, #ctx.reports, "single failure report")
  ctx.callbacks.FocusLost()
  t.assert_eq(0, #ctx.restored_snapshots, "missing entry snapshot")
end)

t:test("focus lifecycle: selection failure preserves the entry snapshot", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    capture_and_select_error = "selection failed",
  })

  t.assert_eq(1, ctx.get_capture_and_select_count(), "single fused attempt")
  t.assert_eq(1, #ctx.reports, "single failure report")
  ctx.callbacks.FocusLost()
  t.assert_eq("source.non_english.entry", ctx.restored_snapshots[1], "preserved entry snapshot")
end)

t:test("lifecycle: captures and restores the insert snapshot", function()
  local ctx = setup_lifecycle()

  ctx.callbacks.InsertEnter()
  t.assert_eq(0, #ctx.scheduled, "first insert restore")

  ctx.set_current_snapshot("source.non_english.token")
  ctx.callbacks.InsertLeave()
  t.assert_eq(1, ctx.get_english_switch_count(), "English selection")

  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  t.assert_eq(1, #ctx.scheduled, "deferred restore")
  ctx.flush()
  t.assert_eq("source.non_english.token", ctx.restored_snapshots[1], "restored snapshot")
end)

t:test("lifecycle: invalidates stale restores on mode and setting changes", function()
  local ctx = setup_lifecycle()

  ctx.set_current_snapshot("source.non_english.first")
  ctx.callbacks.InsertLeave()
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  ctx.set_mode("n")
  ctx.callbacks.InsertLeave()
  ctx.flush()
  t.assert_eq(0, #ctx.restored_snapshots, "mode-invalidated restore")

  ctx.set_current_snapshot("source.non_english.next")
  ctx.callbacks.InsertLeave()
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
  t.assert_eq(0, ctx.get_english_switch_count(), "redundant English selection")
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  t.assert_eq(0, #ctx.scheduled, "English snapshot restore")
end)

t:test("lifecycle: FocusGained affects command modes only", function()
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
  t.assert_eq(initial_fused_count + 8, ctx.get_capture_and_select_count(), "command-mode fused captures")
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
  t.assert_eq(command_fused_count, ctx.get_capture_and_select_count(), "text-entry-mode captures")
end)

t:test("focus lifecycle: short sessions restore the entry snapshot", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry" })

  t.assert_eq(1, ctx.get_capture_count(), "entry capture count")
  t.assert_eq(1, ctx.get_english_switch_count(), "command-mode English selection")

  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.advance_ms(60 * 1000)
  ctx.callbacks.FocusLost()

  t.assert_eq("source.non_english.entry", ctx.restored_snapshots[1], "short-session restore")
end)

t:test("focus lifecycle: long sessions restore only observed editing state", function()
  local edited = setup_lifecycle({ initial_snapshot = "source.english" })
  edited.set_current_snapshot("source.non_english.editing")
  edited.callbacks.InsertLeave()
  edited.advance_ms(60 * 1000 + 1)
  edited.callbacks.FocusLost()
  t.assert_eq("source.non_english.editing", edited.restored_snapshots[1], "long edited session")

  local read_only = setup_lifecycle({ initial_snapshot = "source.non_english.entry" })
  read_only.advance_ms(60 * 1000 + 1)
  read_only.callbacks.FocusLost()
  t.assert_eq("source.non_english.entry", read_only.restored_snapshots[1], "long read-only session")
end)

t:test("focus lifecycle: session duration includes entry backend latency", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    capture_duration_ms = 1000,
  })
  ctx.set_capture_duration_ms(0)
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.advance_ms(59 * 1000 + 1)
  ctx.callbacks.FocusLost()

  t.assert_eq("source.non_english.editing", ctx.restored_snapshots[1], "actual long-session restore")
end)

t:test("focus lifecycle: failed capture preserves the latest observed editing state", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.english" })
  ctx.set_current_snapshot("source.non_english.observed")
  ctx.callbacks.InsertLeave()

  ctx.set_backend_error("capture_and_select_english", "capture failed", true)
  ctx.callbacks.InsertLeave()
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  t.assert_eq(0, #ctx.scheduled, "failed capture clears Insert restore target")

  ctx.advance_ms(60 * 1000 + 1)
  ctx.callbacks.FocusLost()
  t.assert_eq("source.non_english.observed", ctx.restored_snapshots[1], "latest observed editing state")
end)

t:test("focus lifecycle: Insert mode restores Neovim state and preserves the new entry snapshot", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.FocusLost()

  ctx.set_current_snapshot("source.external.entry")
  ctx.set_mode("i")
  ctx.callbacks.FocusGained()
  t.assert_eq(1, #ctx.scheduled, "focused Insert restore")
  ctx.flush()
  t.assert_eq("source.non_english.editing", ctx.restored_snapshots[2], "Neovim Insert source")

  ctx.callbacks.FocusLost()
  t.assert_eq("source.external.entry", ctx.restored_snapshots[3], "external entry source")
end)

t:test("focus lifecycle: focused Insert mode restores a known English snapshot", function()
  local ctx = setup_lifecycle()
  ctx.callbacks.InsertLeave()
  ctx.callbacks.FocusLost()

  ctx.set_current_snapshot("source.non_english.external")
  ctx.set_mode("i")
  ctx.callbacks.FocusGained()
  t.assert_eq(1, #ctx.scheduled, "focused English restore")
  ctx.flush()

  t.assert_eq("source.english", ctx.restored_snapshots[2], "restored English snapshot")
end)

t:test("focus lifecycle: only the last UILeave closes the session", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry", ui_count = 2 })

  ctx.set_ui_count(1)
  ctx.callbacks.UILeave()
  t.assert_eq(0, #ctx.restored_snapshots, "remaining UI keeps session")

  ctx.set_ui_count(0)
  ctx.callbacks.UILeave()
  t.assert_eq("source.non_english.entry", ctx.restored_snapshots[1], "last UI restores entry")

  ctx.set_current_snapshot("source.non_english.next")
  ctx.set_ui_count(1)
  ctx.callbacks.UIEnter()
  t.assert_eq(2, ctx.get_capture_count(), "reattach starts a new session")
end)

t:test("focus lifecycle: duplicate boundary events are idempotent", function()
  local ctx = setup_lifecycle()

  ctx.callbacks.FocusGained()
  ctx.callbacks.VimResume()
  t.assert_eq(1, ctx.get_capture_count(), "duplicate entry capture")

  ctx.callbacks.FocusLost()
  ctx.callbacks.VimSuspend()
  ctx.callbacks.VimLeavePre()
  t.assert_eq(1, #ctx.restored_snapshots, "duplicate exit restore")
  t.assert_eq(1, ctx.get_capture_count(), "exit capture count")

  ctx.callbacks.FocusGained()
  ctx.callbacks.VimResume()
  t.assert_eq(2, ctx.get_capture_count(), "next entry capture")
end)

t:test("focus lifecycle: headless setup does not touch the foreground source", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry", with_ui = false })

  t.assert_eq(0, ctx.get_capture_count(), "headless capture")
  t.assert_eq(0, ctx.get_capture_and_select_count(), "headless selection")
  t.assert_eq(0, #ctx.restored_snapshots, "headless restore")
end)

t:test("focus lifecycle: exit invalidates a pending Insert restore", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()

  ctx.callbacks.FocusLost()
  t.assert_eq("source.english", ctx.restored_snapshots[1], "focus exit restore")
  ctx.flush()
  t.assert_eq(1, #ctx.restored_snapshots, "stale Insert restore")
end)

t:test("lifecycle: repeated dressing replaces the auto-im subscription", function()
  local ctx = setup_lifecycle({ initial_snapshot = "source.non_english.entry" })

  ctx.set_current_snapshot("source.non_english.stale")
  ctx.callbacks.InsertLeave()
  ctx.set_mode("i")
  ctx.callbacks.InsertEnter()
  ctx.im.dressing()
  ctx.flush()

  t.assert_eq(1, ctx.get_unsubscribe_count(), "previous subscription")
  t.assert_eq(0, #ctx.restored_snapshots, "previous scheduled restore")
  ctx.callbacks.FocusLost()
  t.assert_eq("source.non_english.entry", ctx.restored_snapshots[1], "preserved entry snapshot")
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
