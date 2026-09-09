---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.dressing.dim")

t:test("repeated setup registers one observer and preserves dim toggles", function()
  local toggle = stl.c.Observable.from_value(false)
  t:patch_table(dot.context.flight, "dressing_dim", toggle)
  local observe = stl.fn.observe
  local observations = 0
  t:patch_table(stl.fn, "observe", function(...)
    observations = observations + 1
    local subscription = observe(...)
    t:defer(subscription.unsubscribe)
    return subscription
  end)

  era.dressing.setup({ "dim" })
  era.dressing.setup({ "dim" })
  local group = "guanghechen_era.dressing.dim"
  t:defer(function()
    toggle:next(false)
    t.wait_until(function()
      return #vim.api.nvim_get_autocmds({ group = group }) == 0
    end, 1000, "dim did not disable during cleanup")
    vim.api.nvim_set_decoration_provider(vim.api.nvim_get_namespaces()["era.dressing.dim"], {})
    vim.api.nvim_del_augroup_by_name(group)
  end)

  t.assert_eq(1, observations, "one observer registration")
  t.assert_true(era.dressing.get_load_times().dim ~= nil, "dressing timing recorded")
  toggle:next(true)
  t.wait_until(function()
    return #vim.api.nvim_get_autocmds({ group = group }) > 0
  end, 1000, "dim did not enable")
  local count = #vim.api.nvim_get_autocmds({ group = group })
  era.dressing.setup({ "dim" })
  t.assert_eq(count, #vim.api.nvim_get_autocmds({ group = group }), "no duplicate autocmds")

  toggle:next(false)
  t.wait_until(function()
    return #vim.api.nvim_get_autocmds({ group = group }) == 0
  end, 1000, "dim did not disable")
  toggle:next(true)
  t.wait_until(function()
    return #vim.api.nvim_get_autocmds({ group = group }) == count
  end, 1000, "dim did not re-enable")
  t.assert_eq(1, observations, "toggles reuse the observer")
end)

t:run()
