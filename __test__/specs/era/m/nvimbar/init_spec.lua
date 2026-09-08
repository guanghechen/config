local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local Component = require("era.m.nvimbar.component")
local c = require("era.m.nvimbar").component
local t = harness.new("era.m.nvimbar.init")

bootstrap.with_runtime(t, {
  stl = { reporter = {
    error = function(details)
      error(vim.inspect(details))
    end,
  } },
})

t:test("lazy declarations load once and construct independently for each runtime", function()
  local loads, constructions, refreshes = 0, 0, 0
  local position = "f_sl" ---@type stl.t.NvimbarPositionEnum
  local module = "era.m.nvimbar.component.host"
  t:patch_table(package.loaded, module, nil)
  t:patch_table(package.preload, module, function()
    loads = loads + 1
    return {
      username = function(received_position)
        constructions = constructions + 1
        t.assert_eq(position, received_position, "factory reads arguments when it runs")
        return {
          name = "host:username",
          refresh = function()
            refreshes = refreshes + 1
            return { text = "ready", hltext = "ready" }
          end,
        }
      end,
    }
  end)

  local source = c.lazy(function()
    return c.host.username(position)
  end)
  t.assert_eq(0, loads, "declaration does not load the module")
  position = "f_wl"
  local context = { winnr = 1, bufnr = 2, tabnr = 3, filepath = "test.lua", cwd = "/test" }
  local definitions = {}
  for index = 1, 2 do
    local runtime = Component.new(source, function() end, function()
      return true
    end)
    t:defer(function()
      runtime:dispose()
    end)
    runtime:request(context)
    t.assert_eq(index - 1, constructions, "construction stays in the queue")
    t.wait_until(function()
      return runtime.status == "ready"
    end, 1000)
    definitions[index] = runtime.definition
    runtime:request(context, true)
    t.wait_until(function()
      return runtime.status == "ready"
    end, 1000)
    t.assert_eq(index, constructions, "refresh reuses the initialized definition")
    t.assert_eq(index * 2, refreshes)
  end
  t.assert_eq(1, loads)
  t.assert_true(definitions[1] ~= definitions[2], "runtimes do not share a constructed definition")
end)

t:run()
