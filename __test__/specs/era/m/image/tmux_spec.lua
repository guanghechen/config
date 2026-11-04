local harness = require("__test__.support.harness")
local t = harness.new()

local scenarios = {
  { name = "enables passthrough for the owning pane before installing image hooks", calls = 2, owns_pane = true },
  { name = "skips image setup without an owning pane", pane = false, calls = 0, skipped = true },
  { name = "reports failed passthrough activation", set_code = 1, calls = 2, skipped = true, warned = true },
  { name = "does not invoke tmux outside tmux", tmux = false, calls = 0 },
}

for _, scenario in ipairs(scenarios) do
  t:test(scenario.name, function()
    local commands = {}
    local warnings = {}
    local hooks = 0
    local state = {
      did_setup = false,
      data = { extnames = { ".png" }, doc = { enabled = false } },
      is_support_terminal = function()
        return true
      end,
    }
    t:patch_global("stl", {
      env = { IS_OSX = true, IS_TMUX = scenario.tmux ~= false },
      nvim = { fn = {
        augroup = function()
          return 1
        end,
      } },
      reporter = {
        warn = function(report)
          warnings[#warnings + 1] = report
        end,
      },
    })
    t:patch_table(vim, "env", { TMUX_PANE = scenario.pane ~= false and "%7312" or nil })
    t:patch_table(package.loaded, "era.m.image.state", state)
    t:patch_table(vim.api, "nvim_create_autocmd", function()
      t.assert_eq(scenario.calls, #commands, "passthrough setup precedes image hooks")
      hooks = hooks + 1
      return hooks
    end)
    t:patch_table(vim, "system", function(command, opts)
      commands[#commands + 1] = command
      t.assert_eq(1000, opts.timeout, "bounded tmux wait")
      return {
        wait = function()
          local code = command[2] == "set-option" and scenario.set_code or 0
          return { code = code, stdout = "", stderr = "controlled tmux failure" }
        end,
      }
    end)

    local Image = assert(loadfile("lua/era/m/image/init.lua"))()
    Image.dressing()

    -- Inside tmux the image hooks also give the pane its passthrough back on suspension and take it again on
    -- resumption, and watch which client shows the pane, asked once right away.
    local watched = scenario.owns_pane and 1 or 0
    local tmux_hooks = scenario.owns_pane and 3 or 0
    t.assert_eq(scenario.calls + watched, #commands, "tmux calls")
    t.assert_eq(not scenario.skipped, state.did_setup, "image setup result")
    t.assert_eq(scenario.skipped and 0 or 4 + tmux_hooks, hooks, "image hooks")
    t.assert_eq(scenario.warned and 1 or 0, #warnings, "failure diagnostic")
    if warnings[1] then
      t.assert_eq("tmux image passthrough", warnings[1].subject, "warning subject")
      t.assert_true(warnings[1].message:find("controlled tmux failure", 1, true) ~= nil, "warning carries stderr")
    end
    if commands[1] then
      t.assert_same(
        { "tmux", "show-options", "-p", "-q", "-v", "-t", "%7312", "allow-passthrough" },
        commands[1],
        "the pane's own value is read first"
      )
      t.assert_same(
        { "tmux", "set-option", "-p", "-t", "%7312", "allow-passthrough", "all" },
        commands[2],
        "activation targets only the owning pane"
      )
    end
    if scenario.owns_pane then
      t.assert_same(
        { "tmux", "display-message", "-p", "-t", "%7312", "#{client_pid}:#{client_created}" },
        commands[3],
        "client query targets only the owning pane"
      )
    end
    if not scenario.skipped then
      Image.dressing()
      t.assert_eq(scenario.calls + watched, #commands, "repeated dressing does not rerun tmux setup")
      t.assert_eq(4 + tmux_hooks, hooks, "repeated dressing does not duplicate hooks")
    end
  end)
end

for _, case in ipairs({
  { own = "on", restore = "tmux set-option -p -t %7312 allow-passthrough on" },
  { own = "", restore = "tmux set-option -p -u -t %7312 allow-passthrough" },
}) do
  t:test(("the pane gets its own passthrough %q back on exit and suspension"):format(case.own), function()
    local callbacks = {} ---@type table<string, fun()[]>
    local log = {} ---@type string[]
    t:patch_global("stl", {
      env = { IS_OSX = true, IS_TMUX = true },
      nvim = { fn = {
        augroup = function()
          return 1
        end,
      } },
    })
    t:patch_table(vim, "env", { TMUX_PANE = "%7312" })
    t:patch_table(package.loaded, "era.m.image.state", {
      did_setup = false,
      data = { extnames = { ".png" }, doc = { enabled = false } },
      is_support_terminal = function()
        return true
      end,
    })
    t:patch_table(package.loaded, "era.m.image.placement", {
      clean = function()
        log[#log + 1] = "placements closed"
      end,
    })
    t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
      for _, event in ipairs(type(events) == "table" and events or { events }) do
        callbacks[event] = callbacks[event] or {}
        table.insert(callbacks[event], opts.callback)
      end
      return 1
    end)
    t:patch_table(vim, "system", function(command, _, on_exit)
      if command[2] == "set-option" then
        log[#log + 1] = table.concat(command, " ")
      end
      if on_exit then
        on_exit({ code = 0, stdout = "" })
      end
      return {
        wait = function()
          return { code = 0, stdout = command[2] == "show-options" and case.own .. "\n" or "", stderr = "" }
        end,
      }
    end)
    ---@param event                     string
    local function fire(event)
      for _, callback in ipairs(callbacks[event] or {}) do
        callback()
      end
    end

    assert(loadfile("lua/era/m/image/init.lua"))().dressing()
    fire("VimSuspend")
    fire("VimResume")
    fire("VimLeavePre")

    local enable = "tmux set-option -p -t %7312 allow-passthrough all" ---@type string
    -- On exit the placements are deleted first, which still needs the passthrough.
    t.assert_same({ enable, case.restore, enable, "placements closed", case.restore }, log, "pane passthrough")
  end)
end

t:test("images are sent again once another tmux client shows the pane", function()
  local client = "4242:1793780000" ---@type string
  local focus = nil ---@type fun()|nil
  local resent, redrawn = 0, 0
  t:patch_global("stl", {
    env = { IS_OSX = true, IS_TMUX = true },
    nvim = { fn = {
      augroup = function()
        return 1
      end,
    } },
  })
  t:patch_table(vim, "env", { TMUX_PANE = "%7312" })
  t:patch_table(package.loaded, "era.m.image.state", {
    did_setup = false,
    data = { extnames = { ".png" }, doc = { enabled = false } },
    is_support_terminal = function()
      return true
    end,
  })
  t:patch_table(package.loaded, "era.m.image.image", {
    resend = function()
      resent = resent + 1
    end,
  })
  t:patch_table(package.loaded, "era.m.image.placement", {
    redraw = function()
      redrawn = redrawn + 1
    end,
  })
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    if type(events) == "table" and events[1] == "FocusGained" then
      focus = opts.callback
    end
    return 1
  end)
  t:patch_table(vim, "schedule", function(callback)
    callback()
  end)
  t:patch_table(vim, "system", function(_, _, on_exit)
    if on_exit then
      on_exit({ code = 0, stdout = client .. "\n" })
    end
    return {
      wait = function()
        return { code = 0, stdout = "", stderr = "" }
      end,
    }
  end)

  assert(loadfile("lua/era/m/image/init.lua"))().dressing()
  assert(focus)()
  t.assert_eq(0, resent, "same client")

  -- Another client, even on a recycled tty.
  client = "4343:1793780100"
  assert(focus)()
  t.assert_eq(1, resent, "another client")
  t.assert_eq(1, redrawn, "placements drawn again")
end)

t:run()
