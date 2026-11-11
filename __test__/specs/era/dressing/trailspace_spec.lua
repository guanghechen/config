local dressing = require("__test__.support.dressing")
local harness = require("__test__.support.harness")
local t = harness.new()
local module_name = "era.dressing.trailspace"
local hlgroup = "f_ux_trailspace"

---@param initially_enabled             boolean
---@return __test__.support.dressing.Flight flight
---@return __test__.support.dressing.Augroups augroups
---@return table trailspace
local function setup(initially_enabled)
  local bufnr = t:buffer({ "local value = 1  " }, { filetype = "lua", scratch = false })
  t:window(bufnr, { split = "right" }, true)
  local previous_hl = vim.api.nvim_get_hl(0, { name = hlgroup, create = false })
  t:defer(function()
    vim.api.nvim_set_hl(0, hlgroup, previous_hl)
  end)
  vim.api.nvim_set_hl(0, hlgroup, { bg = 0xff0000 })

  local flight = dressing.flight(t, initially_enabled)
  local augroups = dressing.augroups(t)
  t:patch_global("dot", { context = { flight = { dressing_trailspace = flight } } })
  t:patch_global("stl", {
    filetype = require("stl.filetype"),
    fn = {
      observe = flight.observe,
    },
    nvim = {
      fn = {
        augroup = function(name)
          t.assert_eq(module_name, name, "augroup name")
          return augroups.augroup(name)
        end,
      },
    },
  })

  return flight, augroups, assert(loadfile("lua/era/dressing/trailspace.lua"))()
end

t:test("dressing preserves one observer and its autocmds across repeated calls", function()
  local flight, augroups, trailspace = setup(true)
  trailspace.dressing()
  local group = augroups.groups[module_name]
  local autocmds = vim.api.nvim_get_autocmds({ group = group })
  t.assert_eq(6, #autocmds, "registered lifecycle events")
  vim.api.nvim_exec_autocmds("BufEnter", { group = group, modeline = false })
  t.assert_eq(1, #vim.fn.getmatches(), "active highlight")

  trailspace.dressing()
  t.assert_eq(1, #flight.observers, "observer registrations")
  t.assert_eq(1, #augroups.ids, "augroup registrations")
  t.assert_same(autocmds, vim.api.nvim_get_autocmds({ group = group }), "autocmds are preserved")

  flight:set(false)
  trailspace.dressing()
  t.assert_eq(1, #flight.observers, "observer registrations while disabled")
  t.assert_eq(0, #vim.fn.getmatches(), "disabled highlight")
  flight:set(true)
  t.assert_eq(1, #vim.fn.getmatches(), "re-enabled highlight")
end)

t:test("dressing subscribes once when initially disabled and responds to later toggles", function()
  local flight, augroups, trailspace = setup(false)
  trailspace.dressing()
  trailspace.dressing()
  t.assert_eq(1, #flight.observers, "observer registrations while initially disabled")
  t.assert_eq(0, #vim.fn.getmatches(), "initially disabled highlight")

  flight:set(true)
  trailspace.dressing()
  t.assert_eq(1, #flight.observers, "observer registrations after enabling")
  t.assert_eq(1, #vim.fn.getmatches(), "enabled highlight")
  flight:set(false)
  t.assert_eq(0, #vim.fn.getmatches(), "disabled highlight")
  t.assert_eq(1, #augroups.ids, "augroup registrations")
end)

t:run()
