require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

---@return table
local function facade()
  local state = { contents = {} }
  t:patch_table(era.m.picker.ListComposer, "new", function(props)
    state.props = props
    return {
      finder = {
        set_title = function() end,
        set_content = function(_, content)
          state.contents[#state.contents + 1] = content
        end,
      },
      reset_data = function() end,
      focus = function() end,
    }
  end)
  return state
end

t:test("Find Buffers reads a path in a query as the list shows it, relative to the working directory", function()
  local picker = facade()
  local cwd, outside = t:tempdir(), t:tempdir()
  t:patch_table(dot.path, "cwd", function()
    return cwd
  end)
  local find = assert(loadfile("lua/era/fn/find-buffers.lua"))()
  local rewrite = picker.props.rewrite_query
  t.assert_eq("lua/a.lua", rewrite(cwd .. "/lua/a.lua"))
  t.assert_eq(dot.path.relative(cwd, outside .. "/b.lua", "/"), rewrite(outside .. "/b.lua"))
  t.assert_eq("'lua !spec", rewrite("'" .. cwd .. "/lua !" .. cwd .. "/spec"), "each term keeps its marks")
  t.assert_eq("/init.lua lua", rewrite("/init.lua lua"), "a term that names no path stays")
  t.assert_eq(dot.path.relative(cwd, vim.uv.os_homedir() .. "/x", "/"), rewrite("~/x"))
  find(nil, outside .. "/b.lua")
  t.assert_eq(outside .. "/b.lua", picker.contents[#picker.contents], "the query it starts with")
end)

t:run()
