--- Run with: nvim -l __test__/run.lua era/dressing/notifier/
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
local nvim_fn = require("stl.nvim.fn")
local enums = require("stl.e")
local module_name = "era.dressing.notifier"
local t = harness.new(module_name)

local function setup()
  local runtime = { observers = {}, groups = {}, group_ids = {}, schedules = 0, delays = {} }
  runtime.original_notify = vim.notify
  t:patch_table(vim, "notify", vim.notify)
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)
  t:patch_table(vim, "treesitter", nil)

  local level = {
    snapshot = function()
      return "INFO"
    end,
  }
  local paused = {
    snapshot = function()
      return false
    end,
  }
  t:patch_global("dot", {
    state = { status = { notification_level = level, notification_paused = paused } },
    context = { theme = {
      get_float_winblend = function()
        return 0
      end,
    } },
    var = { zindex = { NOTIFIER = 50 }, N_WINLINE_DISABLED = "winline_disabled" },
  })
  t:patch_global("yoz", { fn = {
    md5 = function(value)
      return value
    end,
  } })
  t:patch_global("stl", {
    e = enums,
    filetype = require("stl.filetype"),
    icon = { loglevel = { INFO = "I" } },
    c = {
      CircularQueue = require("stl.c.circular_queue"),
      Observable = {
        from_value = function(value)
          return {
            snapshot = function()
              return value
            end,
          }
        end,
      },
      Scheduler = {
        new = function(props)
          runtime.task = props.task
          return {
            schedule = function()
              runtime.schedules = runtime.schedules + 1
            end,
          }
        end,
      },
    },
    fn = {
      truthy = function()
        return true
      end,
      observe = function(observables, callback)
        t.assert_eq(level, observables[1], "observed notification level")
        t.assert_eq(paused, observables[2], "observed pause state")
        runtime.observers[#runtime.observers + 1] = callback
        callback()
      end,
    },
    nvim = {
      buf = { is_valid = vim.api.nvim_buf_is_valid },
      win = { is_valid = vim.api.nvim_win_is_valid },
      fn = {
        bindkeys = function() end,
        txt = function(text)
          return text
        end,
        augroup = function(name)
          local group = nvim_fn.augroup(name)
          if runtime.groups[name] == nil then
            t:defer(function()
              vim.api.nvim_del_augroup_by_id(group)
            end)
          end
          runtime.groups[name] = group
          runtime.group_ids[#runtime.group_ids + 1] = group
          return group
        end,
      },
    },
    timer = {
      delay = function(callback)
        runtime.delays[#runtime.delays + 1] = callback
      end,
    },
  })
  t:patch_global("era", require("era"))
  t:patch_table(package.loaded, module_name, nil)
  t.assert_eq(module_name, era.dressing.__mods.notifier, "module registration")
  t.assert_nil(era.m.__mods.notifier, "old registration removed")
  runtime.notifier = era.dressing.notifier
  t:defer(function()
    runtime.notifier.dismiss_all()
  end)
  return runtime
end

t:test("loading notification history does not install global or event hooks", function()
  local runtime = setup()
  t.assert_eq(0, #runtime.notifier.history(), "initial history")
  t.assert_eq(runtime.original_notify, vim.notify, "notify remains owned by the caller until setup")
  t.assert_eq(0, #runtime.observers, "no observers before setup")
  t.assert_eq(0, #runtime.group_ids, "no event groups before setup")
end)

t:test("dressing initializes once and preserves later notify wrappers and event callbacks", function()
  local runtime = setup()
  runtime.notifier.dressing()
  t.assert_eq(runtime.notifier, vim.notify, "installed notifier")
  local enter_group = runtime.group_ids[1]
  local resize_group = runtime.group_ids[2]
  local enter_events = vim.api.nvim_get_autocmds({ group = enter_group })
  local resize_events = vim.api.nvim_get_autocmds({ group = resize_group })
  local wrapper = function() end
  t:patch_table(vim, "notify", wrapper)

  runtime.notifier.dressing()
  t.assert_eq(1, #runtime.observers, "observer registrations")
  t.assert_eq(wrapper, vim.notify, "later notify wrapper preserved")
  t.assert_eq(2, #runtime.group_ids, "event groups registered once")
  t.assert_eq(1, runtime.schedules, "initial observer notification")
  t.assert_true(
    vim.deep_equal(enter_events, vim.api.nvim_get_autocmds({ group = enter_group })),
    "entry callback preserved"
  )
  t.assert_true(
    vim.deep_equal(resize_events, vim.api.nvim_get_autocmds({ group = resize_group })),
    "resize callback preserved"
  )

  runtime.observers[1]()
  vim.api.nvim_exec_autocmds("VimResized", { group = resize_group, modeline = false })
  t.assert_eq(3, runtime.schedules, "state and resize events still schedule rendering")
end)

t:test("notifications render natively, retain history, and dismiss through reporter groups", function()
  local runtime = setup()
  runtime.notifier.dressing()
  vim.notify("message body", vim.log.levels.INFO, { group = "notification:1" })
  t.assert_true(runtime.task(), "notification renders successfully")

  local winnrs = {}
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    if vim.w[winnr].wintype == enums.WinTypeEnum.NOTIFY then
      winnrs[#winnrs + 1] = winnr
    end
  end
  t.assert_eq(1, #winnrs, "notification window count")
  local winnr = winnrs[1]
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  t.assert_eq("message body", vim.api.nvim_buf_get_lines(bufnr, 1, -1, false)[1], "notification content")
  t.assert_eq("message body", runtime.notifier.history()[1].content, "notification history")

  vim.api.nvim_set_current_win(winnr)
  t.assert_eq(1, #runtime.delays, "notification timeout")
  runtime.delays[1]()
  t.assert_true(vim.api.nvim_win_is_valid(winnr), "focused notification survives its previous timeout")

  require("stl.reporter").dismiss("notification:1")
  t.assert_false(vim.api.nvim_win_is_valid(winnr), "dismissed notification window")
  t.assert_false(vim.api.nvim_buf_is_valid(bufnr), "dismissed notification buffer")
  t.assert_eq(1, #runtime.notifier.history(), "dismissal preserves history")
end)

t:run()
