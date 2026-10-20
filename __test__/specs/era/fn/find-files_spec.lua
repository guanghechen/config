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
    "textonly",
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
  local state = { preparations = {} }
  t:patch_table(era.m.picker.FiletreeComposer, "new", function(props)
    state.props = props
    return {
      finder = { set_title = function() end, set_content = function() end },
      isexistent = function()
        return false
      end,
      isfocused = function()
        return false
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
  t:patch_table(dot.context.select, "find_file", values)
  t:patch_table(dot.path, "cwd", function()
    return "/context"
  end)
  local scans = {}
  t:patch_table(yoz.find, "find_files", function(options)
    scans[#scans + 1] = options
    return { filepaths = { "one.lua" } }
  end)
  local find = assert(loadfile("lua/era/fn/find-files.lua"))()
  find("/requested")
  local first = picker.preparations[#picker.preparations]
  local count = #scans
  find("/requested")
  t.assert_eq(count, #scans, "focusing the same pending root does not rescan")
  values.flag_gitignore:next(true)
  t.wait_until(function()
    return #scans > count
  end, 1000)
  t.assert_eq("/requested", scans[#scans].cwd)
  t.assert_true(scans[#scans].flag_gitignore)
  first.resolve({ kind = "Superseded" })
  count = #scans
  find("/requested")
  t.assert_eq(count, #scans, "an older completion cannot clear the current pending root")
  picker.props.on_hidden()
  find("/requested")
  t.assert_eq(count + 1, #scans, "reopening a cancelled root starts fresh preparation")
end)

t:run()
