local t = require("__test__.support.harness").new()

t:test("an attached UI draws ephemeral viewport marks and independent shared-state buffers", function()
  local channel = require("__test__.support.ui").new()
  t:defer(function()
    channel:close()
  end)
  channel:start({ width = 100, height = 30, runtime = "native" })
  channel:lua([[
    treeview_drawn = {}
    local set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, options)
      if options.ephemeral then treeview_drawn[row] = true end
      return set_extmark(bufnr, namespace, row, col, options)
    end
    local await = require("__test__.support.treeview").await
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
  ]])
  channel:rpc("nvim_command", "redraw")
  channel:wait_until(function()
    return channel:lua("return next(treeview_drawn) ~= nil")
  end, 5000)
  t.assert_eq(0, channel:lua("return #reports.error"))
  t.assert_true(channel:lua("for row in pairs(treeview_drawn) do if row >= 35 then return false end end return true"))
  t.assert_eq(0, channel:lua("return #vim.api.nvim_buf_get_extmarks(treeview_view.bufnr, -1, 0, -1, {})"))
  channel:lua("treeview_drawn = {}; vim.api.nvim_win_set_cursor(treeview_view.winnr, {1800, 0})")
  channel:rpc("nvim_command", "redraw")
  channel:wait_until(function()
    return channel:lua("for row in pairs(treeview_drawn) do if row >= 1790 then return true end end return false")
  end, 5000)
  t.assert_eq(0, channel:lua("return #reports.error"))
  channel:lua([[
    vim.cmd.vsplit()
    treeview_second = require("ux.treeview").attach(treeview_state, { keymaps = false })
    assert(vim.wait(5000, function() return treeview_second:frame() ~= nil end))
    vim.api.nvim_set_current_win(treeview_view.winnr)
    vim.cmd.normal({ args = { "V" }, bang = true })
    treeview_state:set_root({ kind = "forest", nodes = { treeview_data:source():id("n1") } })
  ]])
  channel:wait_until(function()
    return channel:lua("return treeview_second:status().frame.row_count == 1")
  end, 5000)
  t.assert_true(channel:lua("return treeview_view.bufnr ~= treeview_second.bufnr"))
  t.assert_eq(2000, channel:lua("return treeview_view:status().frame.row_count"))
  t.assert_eq("V", channel:lua("return vim.api.nvim_get_mode().mode"))
  channel:lua("vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })")
  channel:wait_until(function()
    return channel:lua("return treeview_view:status().frame.row_count == 1")
  end, 5000)
  t.assert_eq(0, channel:lua("return #reports.error"))
  channel:lua([[
    treeview_view:detach(); treeview_second:detach()
    local await = require("__test__.support.treeview").await
    local root = treeview_data:source():id("root")
    stream_state = await(treeview_data:create_state({ kind = "children_of", node = root }))
    stream_view = require("ux.treeview").attach(stream_state, { keymaps = false })
    assert(vim.wait(5000, function() return stream_view:frame() ~= nil end))
    stream_provider = await(treeview_data:create_provider({ kind = "children", node = root }))
    stream_pages, stream_progress = 0, {}
    stream_query = await(stream_provider:create_query(function()
      stream_pages = stream_pages + 1
      -- Pages arrive faster than the view's paced publication; wait until it shows the previous page, so the
      -- recorded counts prove publication during the stream rather than measure the pace.
      vim.wait(1000, function()
        return stream_view:status().frame.row_count >= (stream_pages - 1) * 500
      end, 1)
      stream_progress[#stream_progress + 1] = stream_view:status().frame.row_count
      local records = {}
      for index = 1, 500 do
        local key = "stream" .. ((stream_pages - 1) * 500 + index)
        records[index] = { key = key, label = key }
      end
      return { records = records, done = stream_pages == 40 }
    end))
    stream_query:start({ pattern = "stream" })
  ]])
  channel:wait_until(function()
    return channel:lua("return stream_view:status().frame.row_count == 20000")
  end, 30000)
  t.assert_eq(40, channel:lua("return stream_pages"))
  local progress = channel:lua("return stream_progress")
  for page = 2, #progress do
    t.assert_true(progress[page] >= (page - 1) * 500, vim.inspect(progress))
  end
  t.assert_eq(0, channel:lua("return #reports.error"))
end)

t:test("connectors and navigation are exact, and persistent decoration errors stop after one resync", function()
  local channel = require("__test__.support.ui").new()
  t:defer(function()
    channel:close()
  end)
  channel:start({ width = 80, height = 30, runtime = "native" })
  channel:lua([[
    marks, writes = {}, 0
    local await = require("__test__.support.treeview").await
    local tv = require("ux.treeview")
    data = tv.new_data()
    await(data:import({ {key="root",label="root",can_expand=true}, {key="a",parent="root",label="parent",can_expand=true}, {key="b",parent="a",label="child"}, {key="c",parent="root",label="sibling"} }))
    state = await(data:create_state({kind="children_of",node=data:source():id("root")}))
    await(state:set_expanded({data:source():id("a")},true,false))
    set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr,ns,row,col,options)
      if options.ephemeral and options.virt_text_pos == "overlay" then
        local column = col
        for _, chunk in ipairs(options.virt_text) do
          for _, glyph in ipairs(vim.fn.split(chunk[1], "\\zs")) do
            marks[row..":"..column] = glyph
            column = column + vim.fn.strdisplaywidth(glyph)
          end
        end
      end
      if fail_marks and options.ephemeral then error("injected decoration failure") end
      return set_extmark(bufnr,ns,row,col,options)
    end
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(...) writes=writes+1; return set_lines(...) end
    view = tv.attach(state,{keymaps=false})
    assert(vim.wait(5000,function() return view:frame()~=nil end))
  ]])
  channel:rpc("nvim_command", "redraw")
  t.assert_eq("╰─", channel:lua('return marks["0:0"] .. marks["0:1"]'))
  t.assert_eq("│", channel:lua('return marks["1:0"]'))
  t.assert_eq("╰─", channel:lua('return marks["1:2"] .. marks["1:3"]'))
  t.assert_eq(
    0,
    channel:lua(
      'vim.api.nvim_win_set_cursor(view.winnr,{2,7}); view:navigate("parent"); return vim.api.nvim_win_get_cursor(view.winnr)[2]'
    )
  )
  channel:lua("fail_marks=true; view:_redraw()")
  channel:wait_until(function()
    return channel:lua("return #reports.error>=2")
  end, 5000)
  local writes = channel:lua("return writes")
  vim.wait(50, function()
    return false
  end)
  t.assert_eq(2, channel:lua("return #reports.error"))
  t.assert_eq(writes, channel:lua("return writes"))
  t.assert_true(channel:lua("return view:status().desynced"))
  channel:lua("fail_marks=false; view:refresh()")
  channel:wait_until(function()
    return channel:lua("return not view:status().desynced and not view._resync_attempted")
  end, 5000)
  channel:lua([[
    local await = require("__test__.support.treeview").await
    await(state:select_node({data:source():id("c")},false))
    local result=await(state:set_display({selected_only=true}))
    assert(vim.wait(5000,function() return state:native():applicable(view:frame(),result.revisions.commit) end))
  ]])
  channel:rpc("nvim_command", "redraw")
  t.assert_eq("╰─", channel:lua('return marks["0:0"] .. marks["0:1"]'))
  channel:lua([[
    visual_layout=view:frame():header().layout_revision
    visual_writes=writes
    vim.cmd.normal({args={"V"},bang=true})
    data:batch({{kind="insert",key="unselected",parent="root",position="last",label="unselected"}}):finally(function(ok,result)
      assert(ok and result.kind~="Rejected",vim.inspect(result)); visual_commit=result.revisions.commit
    end)
  ]])
  channel:wait_until(function()
    return channel:lua("return visual_commit and state:native():applicable(view:frame(),visual_commit)")
  end, 5000)
  channel:rpc("nvim_command", "redraw")
  t.assert_eq("V", channel:lua("return vim.api.nvim_get_mode().mode"))
  t.assert_true(channel:lua("return view:frame():header().layout_revision==visual_layout and writes==visual_writes"))
  t.assert_false(channel:lua("return view:frame():rows(1,1).connector_last[1]"))
  t.assert_eq("╰─", channel:lua('return marks["0:0"] .. marks["0:1"]'))
end)

t:run()
