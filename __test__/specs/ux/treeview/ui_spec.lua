---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.treeview.ui" ---@type string

local t = require("__test__.support.harness").new("ux.treeview.ui")

---@param channel                       __test__.support.UI
---@param method                        string
---@param ...                           any
---@return any
local function rpc(channel, method, ...)
  local ok, value = pcall(channel.rpc, channel, method, ...)
  assert(ok, method .. " failed: " .. vim.inspect(value) .. "\n" .. debug.traceback())
  return value
end

---@param channel                       __test__.support.UI
---@param code                          string
---@return any
local function eval(channel, code)
  return rpc(channel, "nvim_exec_lua", code, {})
end

t:test("an attached UI draws ephemeral viewport marks and independent shared-state buffers", function()
  local channel = require("__test__.support.ui").new()
  t:defer(function()
    channel:close()
  end)
  rpc(channel, "nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  rpc(
    channel,
    "nvim_exec_lua",
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root)
    local extension = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. extension, "luaopen_yoz"))()
    treeview_errors, treeview_drawn = {}, {}
    stl = {
      c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") },
      reporter = { error = function(options) treeview_errors[#treeview_errors + 1] = options.message end },
    }
    local set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, options)
      if options.ephemeral then treeview_drawn[row] = true end
      return set_extmark(bufnr, namespace, row, col, options)
    end
    local function await(future)
      assert(vim.wait(5000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
      return future:get_result()
    end
    local treeview = require("ux.treeview")
    treeview_data = treeview.new_data()
    local records = { { key = "root", label = "root", can_expand = true } }
    for index = 1, 2000 do
      records[#records + 1] = { key = "n" .. index, parent = "root", label = "row " .. index, right_text = "detail", highlight = "Normal" }
    end
    assert(await(treeview_data:import(records)).kind == "Applied")
    treeview_state = await(treeview_data:create_state({ kind = "children_of", node = treeview_data:source():id("root") }))
    treeview_view = treeview.attach(treeview_state, { keymaps = false })
    assert(vim.wait(5000, function() return treeview_view:frame() ~= nil end))
    await(treeview_state:select_node({ treeview_data:source():id("n1") }, false))
  ]],
    { assert(vim.uv.cwd()) }
  )
  rpc(channel, "nvim_command", "redraw")
  t.wait_until(function()
    return eval(channel, "return next(treeview_drawn) ~= nil")
  end, 5000)
  t.assert_eq(0, eval(channel, "return #treeview_errors"))
  t.assert_true(eval(channel, "for row in pairs(treeview_drawn) do if row >= 35 then return false end end return true"))
  t.assert_eq(0, eval(channel, "return #vim.api.nvim_buf_get_extmarks(treeview_view.bufnr, -1, 0, -1, {})"))
  eval(channel, "treeview_drawn = {}; vim.api.nvim_win_set_cursor(treeview_view.winnr, {1800, 0})")
  rpc(channel, "nvim_command", "redraw")
  t.wait_until(function()
    return eval(channel, "for row in pairs(treeview_drawn) do if row >= 1790 then return true end end return false")
  end, 5000)
  t.assert_eq(0, eval(channel, "return #treeview_errors"))
  eval(
    channel,
    [[
    vim.cmd.vsplit()
    treeview_second = require("ux.treeview").attach(treeview_state, { keymaps = false })
    assert(vim.wait(5000, function() return treeview_second:frame() ~= nil end))
    vim.api.nvim_set_current_win(treeview_view.winnr)
    vim.cmd.normal({ args = { "V" }, bang = true })
    treeview_state:set_root({ kind = "forest", nodes = { treeview_data:source():id("n1") } })
  ]]
  )
  t.wait_until(function()
    return eval(channel, "return treeview_second:status().frame.row_count == 1")
  end, 5000)
  t.assert_true(eval(channel, "return treeview_view.bufnr ~= treeview_second.bufnr"))
  t.assert_eq(2000, eval(channel, "return treeview_view:status().frame.row_count"))
  t.assert_eq("V", eval(channel, "return vim.api.nvim_get_mode().mode"))
  eval(channel, "vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })")
  t.wait_until(function()
    return eval(channel, "return treeview_view:status().frame.row_count == 1")
  end, 5000)
  t.assert_eq(0, eval(channel, "return #treeview_errors"))
  eval(
    channel,
    [[
    treeview_view:detach(); treeview_second:detach()
    local function await(future)
      assert(vim.wait(10000, function() return future:is_done() end))
      return future:get_result()
    end
    local root = treeview_data:source():id("root")
    stream_state = await(treeview_data:create_state({ kind = "children_of", node = root }))
    stream_view = require("ux.treeview").attach(stream_state, { keymaps = false })
    assert(vim.wait(5000, function() return stream_view:frame() ~= nil end))
    stream_provider = await(treeview_data:create_provider({ kind = "children", node = root }))
    stream_pages, stream_progress = 0, {}
    stream_query = await(stream_provider:create_query(function()
      stream_pages = stream_pages + 1
      stream_progress[#stream_progress + 1] = stream_view:status().frame.row_count
      local records = {}
      for index = 1, 500 do
        local key = "stream" .. ((stream_pages - 1) * 500 + index)
        records[index] = { key = key, label = key }
      end
      return { records = records, done = stream_pages == 40 }
    end))
    stream_query:start({ pattern = "stream" })
  ]]
  )
  t.wait_until(function()
    return eval(channel, "return stream_view:status().frame.row_count == 20000")
  end, 30000)
  t.assert_eq(40, eval(channel, "return stream_pages"))
  t.assert_true(
    eval(
      channel,
      "for page = 2, #stream_progress do if stream_progress[page] < (page - 1) * 500 then return false end end return true"
    )
  )
  t.assert_eq(0, eval(channel, "return #treeview_errors"))
end)

t:test("connectors and navigation are exact, and persistent decoration errors stop after one resync", function()
  local channel = require("__test__.support.ui").new()
  t:defer(function()
    channel:close()
  end)
  rpc(channel, "nvim_ui_attach", 80, 30, { rgb = true, ext_linegrid = true })
  rpc(
    channel,
    "nvim_exec_lua",
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root)
    local extension = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. extension, "luaopen_yoz"))()
    errors, marks, writes = {}, {}, 0
    stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") }, reporter = { error = function(options) errors[#errors+1] = options.message end } }
    local function await(future)
      assert(vim.wait(5000, function() return future:is_done() end))
      local result = future:get_result(); assert(result.kind ~= "Rejected", vim.inspect(result)); return result
    end
    local tv = require("ux.treeview")
    data = tv.new_data()
    await(data:import({ {key="root",label="root",can_expand=true}, {key="a",parent="root",label="parent",can_expand=true}, {key="b",parent="a",label="child"}, {key="c",parent="root",label="sibling"} }))
    state = await(data:create_state({kind="children_of",node=data:source():id("root")}))
    await(state:set_expanded({data:source():id("a")},true,false))
    set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr,ns,row,col,options)
      if options.ephemeral and options.virt_text then marks[row..":"..col] = options.virt_text[1][1] end
      if fail_marks and options.ephemeral then error("injected decoration failure") end
      return set_extmark(bufnr,ns,row,col,options)
    end
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(...) writes=writes+1; return set_lines(...) end
    view = tv.attach(state,{keymaps=false})
    assert(vim.wait(5000,function() return view:frame()~=nil end))
  ]],
    { assert(vim.uv.cwd()) }
  )
  rpc(channel, "nvim_command", "redraw")
  t.assert_eq("├─", eval(channel, 'return marks["0:0"]'))
  t.assert_eq("│", eval(channel, 'return marks["1:0"]'))
  t.assert_eq("╰─", eval(channel, 'return marks["1:2"]'))
  t.assert_eq(
    0,
    eval(
      channel,
      'vim.api.nvim_win_set_cursor(view.winnr,{2,7}); view:navigate("parent"); return vim.api.nvim_win_get_cursor(view.winnr)[2]'
    )
  )
  eval(channel, "fail_marks=true; view:_redraw()")
  t.wait_until(function()
    return eval(channel, "return #errors>=2")
  end, 5000)
  local writes = eval(channel, "return writes")
  vim.wait(50, function()
    return false
  end)
  t.assert_eq(2, eval(channel, "return #errors"))
  t.assert_eq(writes, eval(channel, "return writes"))
  t.assert_true(eval(channel, "return view:status().desynced"))
  eval(channel, "fail_marks=false; view:refresh()")
  t.wait_until(function()
    return eval(channel, "return not view:status().desynced and not view._resync_attempted")
  end, 5000)
  eval(
    channel,
    [[
    local function await(future)
      assert(vim.wait(5000, function() return future:is_done() end))
      local result = future:get_result(); assert(result.kind ~= "Rejected", vim.inspect(result)); return result
    end
    await(state:select_node({data:source():id("c")},false))
    local result=await(state:set_display({selected_only=true}))
    assert(vim.wait(5000,function() return state._native:applicable(view:frame(),result.revisions.commit) end))
  ]]
  )
  rpc(channel, "nvim_command", "redraw")
  t.assert_eq("╰─", eval(channel, 'return marks["0:0"]'))
  eval(
    channel,
    [[
    visual_layout=view:frame():header().layout_revision
    visual_writes=writes
    vim.cmd.normal({args={"V"},bang=true})
    data:batch({{kind="insert",key="unselected",parent="root",position="last",label="unselected"}}):finally(function(ok,result)
      assert(ok and result.kind~="Rejected",vim.inspect(result)); visual_commit=result.revisions.commit
    end)
  ]]
  )
  t.wait_until(function()
    return eval(channel, "return visual_commit and state._native:applicable(view:frame(),visual_commit)")
  end, 5000)
  rpc(channel, "nvim_command", "redraw")
  t.assert_eq("V", eval(channel, "return vim.api.nvim_get_mode().mode"))
  t.assert_true(eval(channel, "return view:frame():header().layout_revision==visual_layout and writes==visual_writes"))
  t.assert_eq("├─", eval(channel, 'return marks["0:0"]'))
end)

t:run()
