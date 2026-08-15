---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/view/filetree.lua

local harness = require("__test__.harness")
local filetree = require("era.view.filetree")

local t = harness.new("era.view.filetree")

---@param node era.view.filetree.ITreeNode
---@param _ integer
---@param indent string
---@return string, stl.t.IHighlight[]
local function render_node(node, _, indent)
  return indent .. node.name, {}
end

t:test("render: uses TreeLayout for order, folding, and navigation", function()
  local result = filetree.render({
    { filepath = "src/lib/b.lua" },
    { filepath = "z.lua" },
    { filepath = "src/lib/a.lua" },
  }, {
    render_directory = render_node,
    render_file = render_node,
  })

  t.assert_eq(4, #result.lines, "rendered row count")
  t.assert_eq("├─src/lib", result.lines[1], "folded directory row")
  t.assert_eq("│ ├─a.lua", result.lines[2], "sorted first child")
  t.assert_eq("│ ╰─b.lua", result.lines[3], "sorted last child")
  t.assert_eq("╰─z.lua", result.lines[4], "root file row")

  t.assert_eq("src/lib", result.layout:id(1), "representative ID")
  t.assert_eq(1, result.layout:lnum("src"), "folded parent lookup")
  t.assert_eq(1, result.layout:lnum("src/lib"), "folded representative lookup")
  t.assert_eq(1, result.layout:parent_lnum(2), "child navigation")
  t.assert_eq(3, result.layout:last_descendant_lnum(1), "subtree range")
  t.assert_eq("src/lib", result.line_map[1].filepath, "line map representative")
end)

t:test("render: collapse stops before single-child folding", function()
  local result = filetree.render({
    { filepath = "src/lib/a.lua" },
  }, {
    render_directory = render_node,
    render_file = render_node,
    is_collapsed = function(node)
      return node.filepath == "src"
    end,
  })

  t.assert_eq(1, #result.lines, "collapsed row count")
  t.assert_eq("╰─src", result.lines[1], "collapsed directory row")
  t.assert_eq("src", result.layout:id(1), "collapsed representative")
  t.assert_nil(result.layout:lnum("src/lib"), "collapsed descendant excluded")
end)

t:test("render: rejects duplicate semantic paths", function()
  local ok, err = pcall(filetree.render, {
    { filepath = "same.lua" },
    { filepath = "same.lua" },
  }, {
    render_directory = render_node,
    render_file = render_node,
  })

  t.assert_false(ok, "duplicate path must fail")
  t.assert_true(tostring(err):find("appears more than once", 1, true) ~= nil, "duplicate path error")
end)

t:test("render: 5000-file regression benchmark", function()
  local items = {} ---@type era.view.filetree.IFileItem[]
  for index = 1, 5000 do
    items[index] = {
      filepath = string.format("src/group%02d/file%05d.lua", math.floor((index - 1) / 100), index),
    }
  end

  collectgarbage("collect")
  collectgarbage("stop")
  local heap_before = collectgarbage("count") ---@type number
  local started_at = vim.uv.hrtime() ---@type integer
  local ok, result = pcall(filetree.render, items, {
    render_directory = render_node,
    render_file = render_node,
  }) ---@type boolean, era.view.filetree.IRenderResult|string
  local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6 ---@type number
  local heap_kib = collectgarbage("count") - heap_before ---@type number
  collectgarbage("restart")

  if not ok then
    error(result, 0)
  end
  ---@cast result era.view.filetree.IRenderResult

  print(string.format("BENCH filetree-render 5000 time=%.3fms heap=%.1fKiB", elapsed_ms, heap_kib))

  t.assert_eq(5051, result.layout:len(), "benchmark layout length")
  t.assert_true(elapsed_ms < 100, "5000-file render should stay below the regression ceiling")
  t.assert_true(heap_kib < 32768, "5000-file render should stay below the heap regression ceiling")
end)

t:run()
