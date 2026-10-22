local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local t = harness.new()
bootstrap.with_native(t)
local treeview = require("ux.treeview")
local support = require("__test__.support.treeview")

-- A suite of its own: LuaJIT binds a compiled loop to the closure it ran in only while the function has few
-- closures, so the regression shows in the first publications of a process.
t:test("a detached view stays collectable after its staging loop is compiled", function()
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
  local weak = setmetatable({ data, state, view }, { __mode = "v" })
  view:detach()
  data, state, view = nil, nil, nil
  t.wait_until(function()
    collectgarbage("collect")
    return next(weak) == nil
  end, 5000, "compiled staging must not retain a detached view")
end)

t:run()
