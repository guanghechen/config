---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.cmdline")
_G.yoz = require("yoz")
bootstrap.with_stl(t, {
  icon = { kind = { Property = "property" } },
  nvim = { fn = {
    augroup = function()
      return 1
    end,
  } },
})

---@return era.m.cmp.cmdline
---@return table
local function setup()
  local view = {
    visible = false,
    items = nil,
    selected = nil,
    owner = nil,
    generation = nil,
    ghost = nil,
  }
  t:patch_table(package.loaded, "era.m.ui_attach.popupmenu", {
    dismiss = function(owner, generation)
      if view.owner ~= owner or generation ~= nil and view.generation ~= generation then
        return false
      end
      view.visible = false
      return true
    end,
    present = function(owner, generation, items, selected)
      view.visible = true
      view.owner = owner
      view.generation = generation
      view.items = items
      view.selected = selected
    end,
    select_owned = function(owner, generation, selected)
      if view.owner ~= owner or view.generation ~= generation then
        return false
      end
      view.selected = selected
      return true
    end,
    visible = function(owner, generation)
      return view.visible and view.owner == owner and view.generation == generation
    end,
  })
  t:patch_table(package.loaded, "era.m.ui_attach.cmdline", {
    set_ghost = function(ghost)
      view.ghost = ghost
    end,
    sync = function(_, _, ghost)
      view.ghost = ghost
    end,
    sync_preview = function(_, _, ghost)
      view.ghost = ghost
    end,
  })
  return assert(loadfile("lua/era/m/cmp/cmdline.lua"))(), view
end

t:test("path completion enumerates the stable directory and fuzzy ranks basenames", function()
  local line = "edit lua/era/m/cm"
  local pos = #line + 1
  local completion_calls = 0
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "file"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return "lua/era/m/cm"
  end)
  t:patch_table(vim.fn, "getcompletion", function(pattern, completion_type)
    completion_calls = completion_calls + 1
    t.assert_eq("lua/era/m/", pattern, "directory enumeration")
    t.assert_eq("file", completion_type, "completion type")
    return {
      "lua/era/m/cmp/",
      "lua/era/m/commentstring.lua",
      "lua/era/m/statuscolumn.lua",
      "lua/era/m/virtcolumn.lua",
    }
  end)
  t:patch_table(vim.fn, "setcmdline", function(value, value_pos)
    line = value
    pos = value_pos
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()

  t.assert_true(view.visible, "visible popup")
  t.assert_eq(4, #view.items, "fuzzy candidates")
  t.assert_eq("cmp/", view.items[1][1], "first candidate")
  t.assert_eq("[path]", view.items[1][3], "path source")
  t.assert_eq("Directory", view.items[1][8], "path source highlight")
  t.assert_true(vim.deep_equal({ { 0, 2, "PmenuMatch", 150 } }, view.items[1][7]), "basename match highlight")
  t.assert_eq(1, completion_calls, "single enumeration")

  t.assert_true(Cmdline.move(1), "preview")
  t.assert_eq("edit lua/era/m/cmp/", line, "preview line")
  t.assert_eq(0, view.selected, "selected row")
  t.assert_true(Cmdline.cancel(), "cancel")
  t.assert_eq("edit lua/era/m/cm", line, "restored line")
end)

t:test("selection cycles through the original command line", function()
  local line = "edi"
  local pos = #line + 1
  local setcmdline_calls = 0
  local redraws = 0
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "command"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return "edi"
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    return { "edit" }
  end)
  t:patch_table(vim.fn, "setcmdline", function(value, value_pos)
    setcmdline_calls = setcmdline_calls + 1
    line = value
    pos = value_pos
  end)
  t:patch_table(vim.api, "nvim__redraw", function()
    redraws = redraws + 1
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()
  Cmdline.move(1)
  t.assert_eq("edit", line, "candidate preview")
  t.assert_eq(1, setcmdline_calls, "single preview mutation")
  Cmdline.move(1)
  t.assert_eq("edi", line, "original input")
  t.assert_eq(-1, view.selected, "original selection")
  t.assert_eq("t", view.ghost, "restored ghost")
  t.assert_eq(2, setcmdline_calls, "single restore mutation")
  t.assert_eq(0, redraws, "input-loop-owned redraw")
end)

t:test("automatic Ex completion projects ghost text without mutating input", function()
  local line = "ed"
  local pos = #line + 1
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "command"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return line
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    return { "edit", "echo" }
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()

  t.assert_eq("ed", line, "unchanged input")
  t.assert_eq(-1, view.selected, "unselected list")
  t.assert_eq("it", view.ghost, "candidate continuation")
end)

t:test("show builds a hidden search session and previews its first item", function()
  local line = "alp"
  local pos = #line + 1
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return "/"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "setcmdline", function(value, value_pos)
    line = value
    pos = value_pos
  end)
  t:patch_table(vim.api, "nvim_buf_get_lines", function()
    return { "alphaOne alphaTwo" }
  end)

  local Cmdline, view = setup()

  t.assert_true(Cmdline.show(1), "show handled")
  t.assert_true(view.visible, "popup")
  t.assert_eq("alphaOne", line, "preview")
end)

t:test("search completion stays hidden until explicitly shown", function()
  local line = "alp"
  local pos = #line + 1
  local cmdtype = "/"
  local callbacks = {} ---@type table<string, function>
  local scheduled = {} ---@type function[]
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    for _, name in ipairs(type(event) == "table" and event or { event }) do
      callbacks[name] = opts.callback
    end
    return 1
  end)
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return cmdtype
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "setcmdline", function(value, value_pos)
    line = value
    pos = value_pos
  end)
  t:patch_table(vim.api, "nvim_buf_get_lines", function()
    return { "alphaOne alphaTwo" }
  end)

  local Cmdline = setup()
  Cmdline.dressing()
  callbacks.CmdlineChanged()
  t.assert_eq(0, #scheduled, "hidden search")

  t.assert_true(Cmdline.show(1), "explicit search completion")
  Cmdline.leave()
  cmdtype = ":"
  callbacks.CmdlineChanged()
  t.assert_eq(1, #scheduled, "automatic Ex completion")
end)

t:test("queued automatic refreshes do not reset a preview", function()
  local line = "edi"
  local pos = #line + 1
  local callbacks = {} ---@type table<string, function>
  local scheduled = {} ---@type function[]
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    for _, name in ipairs(type(event) == "table" and event or { event }) do
      callbacks[name] = opts.callback
    end
    return 1
  end)
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "command"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return line
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    return { "edit", "EditQuery" }
  end)
  t:patch_table(vim.fn, "setcmdline", function(value, value_pos)
    line = value
    pos = value_pos
  end)

  local Cmdline, view = setup()
  Cmdline.dressing()
  callbacks.CmdlineChanged()
  callbacks.CmdlineChanged()
  callbacks.CmdlineChanged()
  t.assert_eq(1, #scheduled, "coalesced refresh")

  t.assert_true(Cmdline.show(1), "preview")
  t.assert_eq("edit", line, "first candidate")
  assert(table.remove(scheduled, 1))()
  t.assert_eq(0, view.selected, "preserved selection")

  t.assert_true(Cmdline.move(1), "cycle")
  t.assert_eq("EditQuery", line, "second candidate")
  t.assert_eq(1, view.selected, "cycled selection")
end)

t:test("show refreshes a session after unscheduled command-line input", function()
  local line = "e"
  local pos = #line + 1
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "command"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return line
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    return { "echo", "edit" }
  end)
  t:patch_table(vim.fn, "setcmdline", function(value, value_pos)
    line = value
    pos = value_pos
  end)

  local Cmdline = setup()
  Cmdline.refresh()
  line = "ed"
  pos = #line + 1

  t.assert_true(Cmdline.show(1), "show handled")
  t.assert_eq("edit", line, "freshly ranked preview")
end)

t:test("filename modifiers expose descriptions and expanded insertion", function()
  local line = "edit %:"
  local pos = #line + 1
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "file"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return "%:"
  end)
  t:patch_table(vim.fn, "expand", function(value)
    return value == "%:p" and "/repo/file.lua" or value == "%:t" and "file.lua" or ""
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()

  t.assert_true(view.visible, "modifier popup")
  local rows = {} ---@type table<string, string[]>
  for _, row in ipairs(view.items) do
    rows[row[1]] = row
  end
  t.assert_eq("full path", rows.p[5], "modifier description")
  t.assert_eq("[path]", rows.p[3], "source")
  t.assert_eq("Directory", rows.p[8], "source highlight")
  t.assert_eq("property", rows.p[2], "kind")
end)

t:test("query-only refresh reuses the immutable candidate index", function()
  local line = "e"
  local pos = 2
  local completion_calls = 0
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "command"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return line
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    completion_calls = completion_calls + 1
    return { "edit", "earlier", "echo" }
  end)

  local Cmdline = setup()
  Cmdline.refresh()
  line = "ed"
  pos = 3
  Cmdline.refresh()

  t.assert_eq(1, completion_calls, "cached enumeration")
end)

t:test("input custom completion is normalized through the same controller", function()
  local line = "al"
  local pos = 3
  local args = nil ---@type table|nil
  _G.era_cmp_test_custom = function(pattern, full_line, cursor_pos)
    args = { pattern, full_line, cursor_pos }
    return { "alpha\nbeta", "alphabet", "beta" }
  end
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return "@"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "customlist,v:lua.era_cmp_test_custom"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return "al"
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()

  t.assert_eq("al", assert(args)[1], "pattern")
  t.assert_eq(line, args[2], "line")
  t.assert_eq(pos, args[3], "cursor")
  t.assert_eq(2, #view.items, "fuzzy custom candidates")
  t.assert_true(
    vim.iter(view.items):any(function(row)
      return row[1] == "alpha↲beta"
    end),
    "single-line custom label"
  )
  _G.era_cmp_test_custom = nil
end)

t:test("command-line window uses buffer mutation with the same completion state", function()
  local line = "edit lua/era/m/cm"
  local cursor = { 3, #line }
  t:patch_table(vim.fn, "win_gettype", function()
    return "command"
  end)
  t:patch_table(vim.fn, "getcmdwintype", function()
    return ":"
  end)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_get_current_line", function()
    return line
  end)
  t:patch_table(vim.api, "nvim_set_current_line", function(value)
    line = value
  end)
  t:patch_table(vim.api, "nvim_win_get_cursor", function()
    return cursor
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function(_, value)
    cursor = value
  end)
  t:patch_table(vim.fn, "getcompletiontype", function()
    return "file"
  end)
  t:patch_table(vim.fn, "getcompletion", function(pattern, completion_type)
    t.assert_eq("lua/era/m/", pattern, "directory enumeration")
    t.assert_eq("file", completion_type, "completion type")
    return { "lua/era/m/cmp/", "lua/era/m/commentstring.lua" }
  end)
  t:patch_table(vim.fn, "screenpos", function()
    return { row = 4, col = 6 }
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()
  Cmdline.move(1)

  t.assert_true(view.visible, "visible popup")
  t.assert_eq("edit lua/era/m/cmp/", line, "buffer preview")
  t.assert_eq(#line, cursor[2], "buffer cursor")
end)

t:test("cached command-line reranking stays within one frame at scale", function()
  local line = "candidate"
  local pos = #line + 1
  local values = {} ---@type string[]
  for index = 1, 2000 do
    values[index] = string.format("candidate_value_%04d", index)
  end
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "command"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return line
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    return values
  end)

  local Cmdline = setup()
  Cmdline.refresh()
  line = "candidate199"
  pos = #line + 1
  local started = vim.uv.hrtime()
  Cmdline.refresh()
  local elapsed_ms = (vim.uv.hrtime() - started) / 1000000

  print(string.format("BENCH cmp cmdline cached2k=%.3fms", elapsed_ms))
  t.assert_true(elapsed_ms < 10, string.format("cached cmdline refresh %.3fms", elapsed_ms))
end)

t:test("boolean option completion includes its negative form", function()
  local line = "set nonu"
  local pos = #line + 1
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "option"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return "nonu"
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    return { "number" }
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()

  t.assert_eq("nonumber", view.items[1][1], "negative option")
end)

t:test("fast file acceptance suppresses its queued preview refresh", function()
  local line = "edit lua/era/m/cm"
  local pos = #line + 1
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "c" }
  end)
  t:patch_table(vim.fn, "getcmdtype", function()
    return ":"
  end)
  t:patch_table(vim.fn, "getcmdline", function()
    return line
  end)
  t:patch_table(vim.fn, "getcmdpos", function()
    return pos
  end)
  t:patch_table(vim.fn, "getcmdcompltype", function()
    return "file"
  end)
  t:patch_table(vim.fn, "getcmdcomplpat", function()
    return line:sub(#"edit " + 1)
  end)
  t:patch_table(vim.fn, "getcompletion", function()
    return { "lua/era/m/commentstring.lua" }
  end)
  t:patch_table(vim.fn, "setcmdline", function(value, value_pos)
    line = value
    pos = value_pos
  end)

  local Cmdline, view = setup()
  Cmdline.refresh()
  Cmdline.move(1)
  t.assert_true(Cmdline.accept(), "accepted")
  t.assert_false(view.visible, "accepted popup")

  Cmdline.refresh()
  t.assert_false(view.visible, "queued preview refresh")
end)

t:run()
