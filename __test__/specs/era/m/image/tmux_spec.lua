local harness = require("__test__.support.harness")
local t = harness.new()

local scenarios = {
  { name = "enables passthrough for the owning pane before installing image hooks", calls = 1, watches_client = true },
  { name = "skips image setup without an owning pane", pane = false, calls = 0, skipped = true },
  { name = "reports failed passthrough activation", set_code = 1, calls = 1, skipped = true, warned = true },
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
          return { code = scenario.set_code or 0, stdout = "", stderr = "controlled tmux failure" }
        end,
      }
    end)

    local Image = assert(loadfile("lua/era/m/image/init.lua"))()
    Image.dressing()

    -- Inside tmux the image hooks also watch which client shows the pane, asked once right away.
    local watched = scenario.watches_client and 1 or 0
    t.assert_eq(scenario.calls + watched, #commands, "tmux calls")
    t.assert_eq(not scenario.skipped, state.did_setup, "image setup result")
    t.assert_eq(scenario.skipped and 0 or 4 + watched, hooks, "image hooks")
    t.assert_eq(scenario.warned and 1 or 0, #warnings, "failure diagnostic")
    if warnings[1] then
      t.assert_eq("tmux image passthrough", warnings[1].subject, "warning subject")
      t.assert_true(warnings[1].message:find("controlled tmux failure", 1, true) ~= nil, "warning carries stderr")
    end
    if commands[1] then
      t.assert_same(
        { "tmux", "set-option", "-p", "-t", "%7312", "allow-passthrough", "all" },
        commands[1],
        "activation targets only the owning pane"
      )
    end
    if scenario.watches_client then
      t.assert_same(
        { "tmux", "display-message", "-p", "-t", "%7312", "#{client_pid}:#{client_created}" },
        commands[2],
        "client query targets only the owning pane"
      )
    end
    if not scenario.skipped then
      Image.dressing()
      t.assert_eq(scenario.calls + watched, #commands, "repeated dressing does not rerun tmux setup")
      t.assert_eq(4 + watched, hooks, "repeated dressing does not duplicate hooks")
    end
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
