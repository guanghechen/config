local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")

-- A suite of its own: LuaJIT binds a loop compiled in a closure to that closure, and so to what it holds, only while
-- the closure's function has made few closures, which the first publications of a process show. A trace that enters
-- such a closure may bind it as well, depending on when code turns hot; this suite judges only the loops.
t:test("no loop compiled for a publication runs in a closure that holds the view", function()
  local looped = setmetatable({}, { __mode = "k" }) ---@type table<function, true>
  local function on_trace(what, _, func, pc, parent)
    -- A root trace starts at a loop, or at the entry (pc 0) of a function called often.
    if what == "start" and parent == nil and pc > 0 then
      looped[func] = true
    end
  end
  jit.attach(on_trace, "trace")
  t:defer(function()
    jit.attach(on_trace)
  end)

  local data = treeview.new_data()
  local records = { { key = "root", label = "root", can_expand = true } }
  for index = 1, 2000 do
    records[#records + 1] = { key = "node-" .. index, parent = "root", label = "node-" .. index }
  end
  support.applied(data:import(records))
  local root = data:source():id("root")
  local state = t.await(data:create_state({ kind = "children_of", node = root }))
  support.applied(state:set_expanded({ root }, true, true))
  local view = treeview.attach(state, { keymaps = false })
  t.wait_until(function()
    return view:frame() ~= nil and view:frame():header().row_count == 2000
  end, 5000)
  view:detach()

  local held = { [data] = true, [state] = true, [view] = true }
  for func in pairs(looped) do
    for index = 1, debug.getinfo(func, "u").nups do
      local name, value = debug.getupvalue(func, index)
      local found = held[value] ~= nil
      if type(value) == "table" then
        for _, field in next, value do
          found = found or held[field] ~= nil
        end
      end
      local source = debug.getinfo(func, "S")
      t.assert_false(
        found,
        ("a loop compiled in %s:%d holds the view through `%s`"):format(source.short_src, source.linedefined, name)
      )
    end
  end
end)

t:run()
