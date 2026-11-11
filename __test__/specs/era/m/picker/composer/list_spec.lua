local UI = require("__test__.support.ui")
local picker = require("__test__.support.picker")
local t = require("__test__.support.harness").new()

t:test("native List preserves callback payload identity, match byte offsets and warm buffers", function()
  local ui = picker.list_ui(t)
  t.assert_eq("userdata", ui:lua("return type(picker._treeview.state:native())"))
  t.assert_true(ui:lua("return picker:retrieve(1) == items[1]"), "original item identity")
  t.assert_true(ui:lua("return picker:retrieve(1).data == original"), "original payload identity")
  t.assert_eq(2, ui:lua("return picker.result.lnum_present:snapshot()"))
  ui:lua([[picker.finder:set_content("nee")]])
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:lua([[
      return picker._treeview:linecount() == 2 and matches[0] and matches[0][1] == 6 and matches[0][2] == 9
    ]])
  end, 5000)
  -- The same matches keep their rows; their highlights follow the longer query.
  ui:lua([[picker.finder:set_content("needle")]])
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:lua([[
      return picker._treeview:linecount() == 2 and matches[0] and matches[0][1] == 6 and matches[0][2] == 12
    ]])
  end, 5000)
  ui:lua([[saved_bufnr=picker.result:get_bufnr(); writes=0; picker:hide(); picker:focus()]])
  ui:wait_lua("return picker._treeview.view and not picker._treeview.view:is_suspended()", 5000, "result resumed")
  t.assert_eq(0, ui:lua("return writes"))
  t.assert_true(ui:lua("return saved_bufnr == picker.result:get_bufnr()"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("a Visual frame keeps its published payloads while a replacement reorders the List", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    vim.cmd.stopinsert()
    vim.api.nvim_set_current_win(picker.result:get_winnr())
    vim.cmd.normal({args={"V"}, bang=true})
    old_frame = picker._treeview:frame()
    next_items = {
      {uuid="two", text="next second", text_lower="next second", data={}},
      {uuid="one", text="next first", text_lower="next first", data={}},
    }
    picker:reset_data({items=next_items, uuid_current="two"})
  ]])
  ui:wait_lua(
    [[
      return picker._treeview.state:snapshot():header().data_revision ~= old_frame:header().data_revision
    ]],
    5000,
    "replacement prepared"
  )
  t.assert_true(ui:lua("return picker:retrieve(1) == items[1]"))
  ui:lua([[vim.cmd.normal({args={vim.keycode("<Esc>")}, bang=true})]])
  ui:wait_lua(
    "return picker:retrieve(1) == next_items[1] and picker._treeview:linecount() == 2",
    5000,
    "replacement published"
  )
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("equal presentation replaces action payloads through a new revision without rewriting text", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    previous_revision=picker._treeview:frame():header().data_revision
    replacement={}
    for _,item in ipairs(items) do
      replacement[#replacement+1]={uuid=item.uuid,text=item.text,text_lower=item.text_lower,data={opaque=newproxy(false)}}
    end
    writes=0
    picker:reset_data({items=replacement,uuid_current="one"})
    assert(picker:retrieve(1)==items[1],"old frame must keep the original item until publication")
  ]])
  ui:wait_lua(
    [[
      return picker:retrieve(1)==replacement[1]
        and picker._treeview:frame():header().data_revision~=previous_revision
    ]],
    5000,
    "replacement published"
  )
  t.assert_eq(0, ui:lua("return writes"))
end)

t:test("multiple occurrences remain on one native row with the best alignment highlighted", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    spans={}
    local set_extmark=vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark=function(bufnr,nsnr,row,col,options)
      if bufnr==picker.result:get_bufnr() and options.ephemeral and options.hl_group=="TreeviewMatch" then
        spans[col..":"..options.end_col]=true
      end
      return set_extmark(bufnr,nsnr,row,col,options)
    end
    picker:reset_data({items={{uuid="repeat",text="needle needle",text_lower="needle needle"}}})
    picker.finder:set_content("needle")
  ]])
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:lua([[
      return picker._treeview:linecount()==1 and spans["6:12"] and not spans["13:19"]
    ]])
  end, 5000)
end)

t:test("fuzzy queries rank with smart case and regex queries keep their escapes", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    picker:reset_data({items={
      {uuid="space", text=" ", data={}},
      {uuid="Upper", text="Abc", data={}},
      {uuid="lower", text="abc", data={}},
      {uuid="word", text="ab", data={}},
    }})
    controls.flag_fuzzy:next(true)
  ]])
  ---@param query                       string
  ---@param count                       integer
  ---@return string[]
  local function rows(query, count)
    ui:lua("picker.finder:set_content(...)", query)
    ui:wait_lua(
      "return picker._matched_input == select(1, ...) and picker._treeview:linecount() == select(2, ...)",
      5000,
      "rows of " .. query,
      query,
      count
    )
    return ui:lua([[
      local uuids = {}
      for row = 1, picker._treeview:linecount() do uuids[row] = picker:retrieve(row).uuid end
      return uuids
    ]])
  end
  t.assert_same({ "Upper" }, rows("Ab", 1), "an uppercase query is case-sensitive")
  t.assert_same({ "word", "Upper", "lower" }, rows("ab", 3), "shorter matches rank first")
  ui:lua("controls.flag_regex:next(true)")
  t.assert_same({ "word" }, rows([[^\S\S$]], 1), "\\S stays a non-space class")
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("an invalid regex lists nothing and says why", function()
  local ui = picker.list_ui(t)
  ui:lua("controls.flag_regex:next(true)")
  ui:lua("picker.finder:set_content(...)", "(")
  ui:wait_lua(
    "return picker._matched_input == '(' and picker._treeview:linecount() == 0",
    5000,
    "invalid regex matched"
  )
  t.assert_eq(1, ui:lua("return #errors"))
  t.assert_true(ui:lua("return errors[1].message:find('Invalid regex pattern', 1, true) ~= nil"))
end)

t:test("a newer reset supersedes partially prepared producer records", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    local now=vim.uv.hrtime
    local clock=now()
    vim.uv.hrtime=function() clock=clock+2000000; return clock end
    picker:reset_data({items={
      {uuid="stale-one",text="stale one",text_lower="stale one"},
      {uuid="stale-two",text="stale two",text_lower="stale two"},
    }})
    vim.uv.hrtime=now
    assert(picker._preparing,"producer preparation must yield")
    assert(picker:retrieve(1)==items[1],"the visible frame must keep its payload")
    latest={uuid="latest",text="latest",text_lower="latest",data=newproxy(false)}
    picker:reset_data({items={latest}})
  ]])
  ui:wait_lua("return picker._treeview:linecount()==1 and picker:retrieve(1)==latest", 5000, "latest reset published")
  t.assert_true(ui:lua("return not picker._treeview:frame():source():id('item:stale-one')"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("flat replacements keep stable native identities and selection through a full import", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    before=picker._treeview:frame():source():id("item:one")
    picker._treeview:set_selected("item:one",true)
    replacement={}
    for index=1,300 do
      replacement[index]={uuid=tostring(index),text="row "..index,text_lower="row "..index}
    end
    replacement[151]={uuid="one",text="changed",text_lower="changed"}
    picker:reset_data({items=replacement})
  ]])
  ui:wait_lua(
    [[return picker._treeview:linecount()==300 and picker:retrieve(151)==replacement[151] ]],
    5000,
    "replacement published"
  )
  t.assert_true(ui:lua([[return picker._treeview:frame():source():id("item:one")==before
    and picker._treeview:isselected("item:one")]]))
  ui:lua([[
    latest={}
    for index,item in ipairs(replacement) do
      latest[index]={uuid=item.uuid,text="new "..index,text_lower="new "..index}
    end
    picker:reset_data({items=latest})
  ]])
  ui:wait_lua([[return picker:retrieve(151)==latest[151] ]], 5000, "latest published")
  t.assert_true(ui:lua([[return picker._treeview:isselected("item:one")]]))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("a rejected flat reset leaves the published payloads and selection intact", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    picker._treeview:set_selected("item:one",true)
    picker:reset_data({items={items[1],items[1]}})
  ]])
  ui:wait_lua([[return #errors==1 and picker._treeview:isselected("item:one")]], 5000, "rejected reset reported")
  t.assert_true(ui:lua([[return picker:retrieve(1)==items[1] and picker._treeview:linecount()==3]]))
end)

t:test("a navigation key typed ahead with a query moves over the rows of that query", function()
  local ui = UI.open(t, { width = 100, height = 32, runtime = "ark" })
  ui:lua([[
    confirmed = nil
    picker = era.m.picker.ListComposer.new({
      name = "typed ahead", title = "typed ahead", permanent = false,
      search_pattern = stl.c.Observable.from_value(""),
      flag_fuzzy = stl.c.Observable.from_value(true),
      flag_regex = stl.c.Observable.from_value(false),
      flag_case_sensitive = stl.c.Observable.from_value(false),
      on_confirm = function(composer, item)
        confirmed = item and item.uuid or false
        composer:close()
      end,
    })
    local items = {}
    for _, name in ipairs({ "alpha", "beta", "gamma", "delta", "theta" }) do
      items[#items + 1] = { uuid = name, text = name, text_lower = name, data = {} }
    end
    picker:reset_data({ items = items })
    picker:focus()
  ]])
  ui:wait_lua("return picker._treeview:linecount() == 5", 5000, "five rows")

  -- "ta" leaves beta, delta and theta; the second of them is delta, where the second of all five rows is beta.
  ui:rpc("nvim_input", "ita<C-j><CR>")
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("delta", ui:lua("return confirmed"))
end)

t:test("a query typed ahead of <CR> confirms from its own results", function()
  local ui = UI.open(t, { width = 100, height = 32, runtime = "ark" })
  ui:lua([[
    confirmed = nil
    picker = era.m.picker.ListComposer.new({
      name = "typed ahead", title = "typed ahead", permanent = false,
      search_pattern = stl.c.Observable.from_value(""),
      flag_fuzzy = stl.c.Observable.from_value(true),
      flag_regex = stl.c.Observable.from_value(false),
      flag_case_sensitive = stl.c.Observable.from_value(false),
      on_confirm = function(composer, item)
        confirmed = item and item.uuid or false
        composer:close()
      end,
    })
    picker:reset_data({ items = {
      { uuid = "alpha", text = "alpha", text_lower = "alpha", data = {} },
      { uuid = "beta", text = "beta", text_lower = "beta", data = {} },
      { uuid = "gamma", text = "gamma", text_lower = "gamma", data = {} },
    } })
    picker:focus()
  ]])
  ui:wait_lua("return picker._treeview:linecount() == 3", 5000, "three rows")

  -- One burst, as keys typed faster than the match debounce arrive: <CR> runs before the query is matched.
  ui:rpc("nvim_input", "igam<CR>")
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma", ui:lua("return confirmed"))
end)

t:run()
