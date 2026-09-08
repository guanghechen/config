--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/im_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.dressing.im composition and lifecycle

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.im")
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
---@return nil
local function unload(module_name)
  t:patch_table(package.loaded, module_name, nil)
end

t:test("module is registered under dressing only", function()
  local namespace = require("era")
  t.assert_eq("era.dressing.im", namespace.dressing.__mods.im, "module registration")
  t.assert_nil(namespace.m.__mods.im, "old registration removed")
end)

---@param options                       { use_wsl?: boolean, setup_error?: string, initial_snapshot?: era.dressing.im.Snapshot, with_ui?: boolean, ui_count?: integer, capture_and_select_error?: string, capture_failed?: boolean, defer_ui_enter?: boolean }|nil
---@return table
local function setup_lifecycle(options)
  options = options or {}
  reports = {}
  local callbacks = {} ---@type table<string, fun()>
  local restored_snapshots = {} ---@type era.dressing.im.Snapshot[]
  local current_snapshot = options.initial_snapshot or "source.english" ---@type era.dressing.im.Snapshot
  local auto_im = true ---@type boolean
  local active_subscriber = nil ---@type stl.c.ISubscriber|nil
  local unsubscribe_count = 0 ---@type integer
  local capture_count = 0 ---@type integer
  local capture_and_select_count = 0 ---@type integer
  local restore_count = 0 ---@type integer
  local english_switch_count = 0 ---@type integer
  local scheduled = {} ---@type function[]
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
  local now_ns = 0 ---@type integer

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
      local err = backend_errors.capture
      if err ~= nil then
        return nil, err
      end
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
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.uv, "hrtime", function()
    return now_ns
  end)
  t:patch_global("yoz", { im = backend })
  unload("era.dressing.im")

  local im = require("era.dressing.im")
  im.dressing()
  if callbacks.UIEnter ~= nil then
    callbacks.UIEnter()
  end

  ---@return nil
  local function flush_scheduled()
    while #scheduled > 0 do
      local callback = table.remove(scheduled, 1)
      callback()
    end
  end
  if not options.defer_ui_enter then
    flush_scheduled()
  end

  return {
    im = im,
    callbacks = callbacks,
    reports = reports,
    restored_snapshots = restored_snapshots,
    setup_executables = setup_executables,
    flush_scheduled = flush_scheduled,
    advance_time = function(milliseconds)
      now_ns = now_ns + milliseconds * 1e6
    end,
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
    get_scheduled_count = function()
      return #scheduled
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

t:test("UI entry: owns focus synchronously and defers backend reconciliation", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    defer_ui_enter = true,
  })

  ctx.callbacks.FocusGained()
  t.assert_eq(0, ctx.get_backend_call_count(), "deferred backend calls")
  t.assert_eq(1, ctx.get_scheduled_count(), "single scheduled reconciliation")

  ctx.flush_scheduled()
  t.assert_eq(1, ctx.get_capture_and_select_count(), "scheduled reconciliation")
end)

t:test("UI entry: focus exit cancels deferred reconciliation", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    defer_ui_enter = true,
  })

  ctx.callbacks.FocusLost()
  ctx.flush_scheduled()

  t.assert_eq(0, ctx.get_backend_call_count(), "stale backend calls")
end)

t:test("UI entry: refocus supersedes deferred reconciliation", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.entry",
    defer_ui_enter = true,
  })

  ctx.callbacks.FocusLost()
  ctx.callbacks.FocusGained()
  t.assert_eq(1, ctx.get_capture_and_select_count(), "synchronous refocus reconciliation")

  ctx.flush_scheduled()
  t.assert_eq(1, ctx.get_capture_and_select_count(), "superseded UI reconciliation")
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

  ---@return nil
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
  ctx.flush_scheduled()
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

t:test("retry: native capture recovers after one second even after repeated failures", function()
  local ctx = setup_lifecycle({
    initial_snapshot = "source.non_english.editing",
    capture_and_select_error = "query failed",
    capture_failed = true,
  })
  for _ = 1, 2 do
    ctx.advance_time(1000)
    ctx.callbacks.InsertLeave()
  end
  t.assert_eq(3, ctx.get_capture_and_select_count(), "fixed native retry interval")

  ctx.set_backend_error("capture_and_select_english", nil)
  ctx.advance_time(999)
  ctx.callbacks.InsertLeave()
  t.assert_eq(3, ctx.get_capture_and_select_count(), "cooldown remains in effect")
  ctx.advance_time(1)
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  t.assert_eq(4, ctx.get_capture_and_select_count(), "native backend retried after one second")
  t.assert_eq("source.non_english.editing", ctx.get_current_snapshot(), "recovered editing source")
end)

t:test("retry: WSL capture failures back off up to eight seconds", function()
  local ctx = setup_lifecycle({ use_wsl = true, capture_and_select_error = "helper timed out", capture_failed = true })

  for index, delay_ms in ipairs({ 1000, 2000, 4000, 8000, 8000 }) do
    t.assert_eq(delay_ms, ctx.reports[index].details.retry_after_ms, "reported cooldown")
    ctx.advance_time(delay_ms - 1)
    ctx.callbacks.InsertLeave()
    t.assert_eq(index, ctx.get_capture_and_select_count(), "no early retry")
    t.assert_eq(index, #ctx.reports, "no repeated report while cooling down")

    ctx.advance_time(1)
    ctx.callbacks.InsertLeave()
    t.assert_eq(index + 1, ctx.get_capture_and_select_count(), "retry at deadline")
  end
end)

t:test("retry: cooldown starts after the blocking backend returns", function()
  local ctx = setup_lifecycle({ use_wsl = true })
  ctx.set_backend_error("capture_and_select_english", "helper timed out", true)
  local capture_and_select = yoz.im.capture_and_select_english
  t:patch_table(yoz.im, "capture_and_select_english", function()
    ctx.advance_time(1000)
    return capture_and_select()
  end)

  ctx.callbacks.InsertLeave()
  ctx.advance_time(999)
  ctx.callbacks.InsertLeave()
  t.assert_eq(2, ctx.get_capture_and_select_count(), "cooldown after completion")

  ctx.advance_time(1)
  ctx.callbacks.InsertLeave()
  t.assert_eq(3, ctx.get_capture_and_select_count(), "retry after a full cooldown")
end)

t:test("retry: a successful WSL capture resets exponential backoff", function()
  local ctx = setup_lifecycle({ use_wsl = true, capture_and_select_error = "capture failed", capture_failed = true })
  ctx.advance_time(1000)
  ctx.callbacks.InsertLeave()

  ctx.advance_time(2000)
  ctx.set_backend_error("capture_and_select_english", nil)
  ctx.callbacks.InsertLeave()
  ctx.set_backend_error("capture_and_select_english", "capture failed again", true)
  ctx.callbacks.InsertLeave()
  t.assert_eq(1000, ctx.reports[3].details.retry_after_ms, "reset cooldown")

  ctx.advance_time(1000)
  ctx.callbacks.InsertLeave()
  t.assert_eq(5, ctx.get_capture_and_select_count(), "retry uses the initial delay")
end)

t:test("retry: a failed English selection still permits exact Insert restoration", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.set_backend_error("capture_and_select_english", "selection failed")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()

  t.assert_eq(1, ctx.get_restore_count(), "independent restore attempt")
  t.assert_eq("source.non_english.editing", ctx.restored_snapshots[1], "preserved snapshot")
end)

t:test("retry: selection cooldown preserves the Insert source after backend recovery", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.set_backend_error("capture_and_select_english", "temporary selection failure")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  ctx.callbacks.InsertLeave()

  ctx.advance_time(1000)
  ctx.set_backend_error("capture_and_select_english", nil)
  ctx.callbacks.FocusLost()
  ctx.set_mode("n")
  ctx.callbacks.FocusGained()
  ctx.callbacks.InsertEnter()
  t.assert_eq("source.non_english.editing", ctx.get_current_snapshot(), "Insert source after recovery")
end)

t:test("retry: selection cooldown keeps observing changes to the Insert source", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.previous")
  ctx.set_backend_error("capture_and_select_english", "selection failed")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()

  ctx.set_current_snapshot("source.non_english.new")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  t.assert_eq(2, ctx.get_capture_and_select_count(), "selection skipped during cooldown")
  t.assert_eq(1, ctx.get_capture_count(), "read-only capture during cooldown")
  t.assert_eq(2, ctx.get_restore_count(), "new target restored")
  t.assert_eq("source.non_english.new", ctx.restored_snapshots[2], "fresh snapshot")
  t.assert_eq("source.non_english.new", ctx.get_current_snapshot(), "current Insert source preserved")
end)

t:test("retry: healthy queries do not reset or extend selection cooldown", function()
  local ctx = setup_lifecycle({ use_wsl = true })
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.set_backend_error("capture_and_select_english", "selection failed")
  ctx.callbacks.InsertLeave()

  ctx.advance_time(500)
  ctx.callbacks.InsertLeave()
  ctx.advance_time(499)
  ctx.callbacks.InsertLeave()
  t.assert_eq(2, ctx.get_capture_count(), "healthy queries stay available")
  t.assert_eq(2, ctx.get_capture_and_select_count(), "no early selection retry")
  t.assert_eq(1, #ctx.reports, "healthy queries do not report selection again")

  ctx.advance_time(1)
  ctx.callbacks.InsertLeave()
  t.assert_eq(3, ctx.get_capture_and_select_count(), "selection retries at its original deadline")
  t.assert_eq(2000, ctx.reports[2].details.retry_after_ms, "selection failure history retained")
end)

t:test("retry: failed read-only queries pause capture as well", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.set_backend_error("capture_and_select_english", "selection failed")
  ctx.callbacks.InsertLeave()
  ctx.advance_time(500)
  ctx.set_backend_error("capture", "query failed")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  t.assert_eq(1, ctx.get_capture_count(), "one failed query")
  t.assert_eq(0, ctx.get_restore_count(), "failed query invalidates restore target")
  t.assert_eq("query failed", ctx.reports[2].details.error, "query failure report")

  ctx.advance_time(999)
  ctx.callbacks.InsertLeave()
  t.assert_eq(1, ctx.get_capture_count(), "query cooldown")
  t.assert_eq(2, ctx.get_capture_and_select_count(), "query cooldown also blocks fused calls")
  t.assert_eq(2, #ctx.reports, "no duplicate failure report")

  ctx.advance_time(1)
  ctx.set_backend_error("capture", nil)
  ctx.set_backend_error("capture_and_select_english", nil)
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  t.assert_eq(3, ctx.get_capture_and_select_count(), "fused operation recovers after query cooldown")
  t.assert_eq("source.non_english.editing", ctx.get_current_snapshot(), "fresh source restored")
end)

t:test("retry: query failures do not grow the selection backoff", function()
  local ctx = setup_lifecycle({ use_wsl = true, capture_and_select_error = "selection failed" })
  ctx.advance_time(100)
  ctx.set_backend_error("capture", "query failed")
  ctx.callbacks.InsertLeave()

  ctx.advance_time(1000)
  ctx.set_backend_error("capture_and_select_english", "query still failed", true)
  ctx.callbacks.InsertLeave()
  t.assert_eq(2000, ctx.reports[3].details.retry_after_ms, "query backoff grows independently")

  ctx.advance_time(2000)
  ctx.set_backend_error("capture_and_select_english", "selection still failed")
  ctx.callbacks.InsertLeave()
  t.assert_eq(2000, ctx.reports[4].details.retry_after_ms, "second selection failure uses its second delay")
end)

t:test("retry: an English snapshot from a read-only query still checks restoration", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.set_backend_error("capture_and_select_english", "selection failed")
  ctx.callbacks.InsertLeave()

  ctx.set_current_snapshot("source.english")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  t.assert_eq(1, ctx.get_capture_count(), "read-only English observation")
  t.assert_eq(1, ctx.get_restore_count(), "unconfirmed English selection is not assumed ready")
  t.assert_eq("source.english", ctx.restored_snapshots[1], "exact English target checked")

  ctx.callbacks.InsertEnter()
  t.assert_eq(1, ctx.get_restore_count(), "successful English restoration reestablishes the shortcut")
end)

t:test("retry: failed fused selection invalidates the previous English guarantee", function()
  local ctx = setup_lifecycle()
  ctx.set_backend_error("capture_and_select_english", "conflicting selection failed")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()

  t.assert_eq(1, ctx.get_restore_count(), "English snapshot restored after failed reconciliation")
  t.assert_eq("source.english", ctx.restored_snapshots[1], "exact English target")
end)

t:test("retry: selection cooldown does not cause unfocused queries", function()
  local ctx = setup_lifecycle({ capture_and_select_error = "selection failed" })
  ctx.callbacks.FocusLost()
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  ctx.advance_time(1000)
  ctx.flush_scheduled()
  t.assert_eq(0, ctx.get_capture_count(), "no unfocused read-only query")
  t.assert_eq(1, ctx.get_capture_and_select_count(), "no unfocused fused operation")
end)

t:test("retry: restore cooldown preserves its snapshot and permits English capture", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.set_backend_error("restore", "restore failed")
  ctx.callbacks.InsertEnter()
  ctx.callbacks.InsertEnter()
  t.assert_eq(1, ctx.get_restore_count(), "restore cooldown")

  ctx.callbacks.FocusLost()
  ctx.callbacks.FocusGained()
  t.assert_eq(3, ctx.get_capture_and_select_count(), "capture remains available")
  ctx.callbacks.InsertEnter()
  t.assert_eq(1, ctx.get_restore_count(), "capture success does not reset restore cooldown")

  ctx.advance_time(1000)
  ctx.set_backend_error("restore", nil)
  ctx.callbacks.InsertEnter()
  t.assert_eq(2, ctx.get_restore_count(), "restore retry")
  t.assert_eq("source.non_english.editing", ctx.restored_snapshots[1], "snapshot retained")
end)

t:test("retry: a new restore target bypasses the previous target's cooldown", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.previous")
  ctx.callbacks.InsertLeave()
  ctx.set_backend_error("restore", "source unavailable")
  ctx.callbacks.InsertEnter()

  ctx.set_current_snapshot("source.non_english.new")
  ctx.callbacks.InsertLeave()
  ctx.set_backend_error("restore", nil)
  ctx.callbacks.InsertEnter()
  t.assert_eq(2, ctx.get_restore_count(), "new target is attempted immediately")
  t.assert_eq("source.non_english.new", ctx.restored_snapshots[1], "new target restored")
end)

t:test("retry: focus transitions do not bypass cooldown or start background retries", function()
  local ctx = setup_lifecycle({ capture_and_select_error = "capture failed", capture_failed = true })
  for _ = 1, 5 do
    ctx.callbacks.FocusLost()
    ctx.callbacks.FocusGained()
  end
  t.assert_eq(1, ctx.get_capture_and_select_count(), "focus churn does not retry")
  t.assert_eq(0, ctx.get_scheduled_count(), "no automatic retry callbacks")

  ctx.callbacks.FocusLost()
  ctx.advance_time(1000)
  ctx.flush_scheduled()
  t.assert_eq(1, ctx.get_capture_and_select_count(), "no unfocused retry")
  ctx.callbacks.FocusGained()
  t.assert_eq(2, ctx.get_capture_and_select_count(), "eligible focus event retries")
end)

t:test("retry: toggling auto-im resets all three operation cooldowns", function()
  local ctx = setup_lifecycle()
  ctx.set_current_snapshot("source.non_english.editing")
  ctx.set_backend_error("capture_and_select_english", "selection failed")
  ctx.callbacks.InsertLeave()
  ctx.set_backend_error("restore", "restore failed")
  ctx.callbacks.InsertEnter()
  ctx.set_backend_error("capture", "query failed")
  ctx.callbacks.InsertLeave()

  ctx.set_auto_im(false)
  ctx.set_backend_error("capture", nil)
  ctx.set_backend_error("capture_and_select_english", nil)
  ctx.set_backend_error("restore", nil)
  ctx.set_auto_im(true)
  t.assert_eq(3, ctx.get_capture_and_select_count(), "enabling retries immediately")

  ctx.set_current_snapshot("source.non_english.editing")
  ctx.callbacks.InsertLeave()
  ctx.callbacks.InsertEnter()
  t.assert_eq(2, ctx.get_restore_count(), "same restore target can retry immediately")
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
  unload("era.dressing.im")

  local im = require("era.dressing.im")
  im.dressing()
  t.assert_false(created_autocmd, "unsupported lifecycle")
end)

t:run()
