require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

---@return table
local function controls()
  local values = {}
  for _, name in ipairs({
    "exclude",
    "foldempty",
    "fuzzy",
    "gitignore",
    "regex",
    "case_sensitive",
    "selected",
  }) do
    values["flag_" .. name] = stl.c.Observable.from_value(false)
  end
  values.flag_viewtype = stl.c.Observable.from_value("tree")
  values.search_pattern = stl.c.Observable.from_value("")
  values.includes, values.excludes = stl.c.Observable.from_value({}), stl.c.Observable.from_value({})
  t:defer(function()
    for _, value in pairs(values) do
      value:dispose()
    end
  end)
  return values
end

---@return table
local function facade()
  local state = { preparations = {}, contents = {}, closed = 0 }
  t:patch_table(era.m.picker.FiletreeComposer, "new", function(props)
    state.props = props
    return {
      finder = {
        set_title = function() end,
        set_content = function(_, content)
          state.contents[#state.contents + 1] = content
        end,
      },
      isexistent = function()
        return false
      end,
      isfocused = function()
        return state.focused == true
      end,
      close = function()
        state.closed = state.closed + 1
      end,
      attach = function()
        error("a pending uncached root must not be attached")
      end,
      mark_result_flags_dirty = function() end,
      focus = function()
        if props.on_focused then
          props.on_focused()
        end
      end,
      prepare_filepaths = function(_, root, paths)
        local future, resolve = stl.c.Future.new_with_resolver()
        state.preparations[#state.preparations + 1] = { root = root, paths = paths, resolve = resolve }
        return future
      end,
    }
  end)
  return state
end

t:test("Find Files coalesces a pending root and applies flag changes to that requested root", function()
  local values, picker = controls(), facade()
  values.includes:next({ "*.lua", "*.md" })
  t:patch_table(dot.context.select, "find_file", values)
  t:patch_table(dot.path, "cwd", function()
    return "/context"
  end)
  local scans, cancels = {}, 0
  t:patch_table(yoz.find, "start_find_files", function(options)
    scans[#scans + 1] = options
    local cancelled = false
    return {
      poll = function()
        return cancelled and "cancelled" or "running"
      end,
      cancel = function()
        cancelled, cancels = true, cancels + 1
      end,
      dispose = function() end,
    }
  end)
  local find = assert(loadfile("lua/era/fn/find-files.lua"))()
  find("/requested")
  local first = picker.preparations[#picker.preparations]
  t.assert_true(getmetatable(first.paths) == stl.c.Future, "the paths load while the walk finds them")
  t.assert_eq("*.lua,*.md", scans[#scans].include_patterns, "the includes reach the walk")
  local count = #scans
  find("/requested")
  t.assert_eq(count, #scans, "focusing the same pending root does not rescan")
  values.flag_gitignore:next(true)
  t.wait_until(function()
    return #scans > count
  end, 1000)
  t.assert_eq("/requested", scans[#scans].cwd)
  t.assert_true(scans[#scans].flag_gitignore)
  t.assert_eq(1, cancels, "the walk the flag change replaced stops")
  first.resolve({ kind = "Superseded" })
  count = #scans
  find("/requested")
  t.assert_eq(count, #scans, "an older completion cannot clear the current pending root")
  picker.props.on_hidden()
  t.assert_eq(2, cancels, "hiding stops the pending walk")
  find("/requested")
  t.assert_eq(count + 1, #scans, "reopening a cancelled root starts fresh preparation")
end)

t:test("Find Files lists no files when the walk rejects a pattern", function()
  local values, picker = controls(), facade()
  values.flag_exclude:next(true)
  values.excludes:next({ "[" })
  t:patch_table(dot.context.select, "find_file", values)
  local warnings = {}
  t:patch_table(stl.reporter, "warn", function(report)
    warnings[#warnings + 1] = report.message
  end)
  local find = assert(loadfile("lua/era/fn/find-files.lua"))()
  find("/requested")
  local paths = picker.preparations[#picker.preparations].paths
  t.wait_until(function()
    return paths:is_done()
  end, 1000)
  t.assert_same({}, paths:get_result(), "no file matches a rejected pattern")
  t.assert_eq(1, #warnings)
  t.assert_true(vim.startswith(warnings[1], "Invalid exclude glob '['"), warnings[1])
end)

t:test("Find Files hands a path outside its root to Find Buffers", function()
  local values, picker = controls(), facade()
  local root, sibling = t:tempdir(), t:tempdir()
  t:patch_table(dot.context.select, "find_file", values)
  t:patch_table(dot.path, "cwd", function()
    return root
  end)
  local handed = {}
  t:patch_table(era.fn, "find_buffers", function(scope, pattern)
    handed[#handed + 1] = { scope = scope, pattern = pattern }
  end)
  assert(loadfile("lua/era/fn/find-files.lua"))()
  ---@param query                       string
  ---@return integer
  local function type_query(query)
    values.search_pattern:next(query)
    vim.wait(20)
    return #handed
  end
  picker.focused = true
  for _, query in ipairs({
    root .. "/lua",
    root:sub(1, 8),
    "/init.lua",
    "!" .. sibling,
    sibling .. " lua",
    "lua",
  }) do
    t.assert_eq(0, type_query(query), query)
  end
  picker.focused = false
  t.assert_eq(0, type_query(sibling), "only while Find Files has the focus")
  picker.focused = true
  t.assert_eq(1, type_query("'" .. sibling .. "/a.lua"))
  t.assert_same({ pattern = sibling .. "/a.lua" }, handed[1], "the path without its marks")
  t.assert_eq("", picker.contents[#picker.contents], "its own query clears")
  t.assert_eq(1, picker.closed)
  t.assert_eq(2, type_query("~/elsewhere"))
  t.assert_same({ pattern = "~/elsewhere" }, handed[2])
end)

t:run()
