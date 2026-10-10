---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.treeview_guides" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local library = arg[1] or root .. "/lua/yoz.so"
local baseline = arg[2] or ""
local count = tonumber(arg[3]) or 50000
local samples = tonumber(arg[4]) or 300
local height = tonumber(arg[5]) or 50
assert(count >= 50 and samples >= 1 and height >= 20 and height <= 500, "invalid benchmark dimensions")
local ui = require("__test__.support.ui").new({ timeout_ms = 30000 })

---@param values                        number[]
---@return table
local function distribution(values)
  table.sort(values)
  return {
    samples = #values,
    p50 = values[math.ceil(#values * 0.5)],
    p95 = values[math.ceil(#values * 0.95)],
    max = values[#values],
  }
end

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 80, height, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, library, baseline, count = ...
    vim.opt.runtimepath:prepend(root)
    yoz = assert(package.loadlib(library, "luaopen_yoz"))()
    errors, writes, decoration_ms, path_update_ms = {}, 0, 0, 0
    counts = { prepare = 0, full_redraw = 0, range_redraw = 0, guide_marks = 0, row_queries = 0, exported_rows = 0 }
    local set_extmark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, namespace, row, col, options)
      local chunk = options.virt_text and options.virt_text[1]
      if view and bufnr == view.bufnr and options.ephemeral and chunk
        and type(chunk[2]) == "string" and chunk[2]:match("^TreeviewGuide") then
        counts.guide_marks = counts.guide_marks + 1
      end
      return set_extmark(bufnr, namespace, row, col, options)
    end
    local redraw = vim.api.nvim__redraw
    vim.api.nvim__redraw = function(options)
      if view and options.win == view.winnr then
        if options.valid == false then counts.full_redraw = counts.full_redraw + 1 end
        if options.range then counts.range_redraw = counts.range_redraw + 1 end
      end
      return redraw(options)
    end
    stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") },
      reporter = { error = function(options) errors[#errors + 1] = options.message end } }
    local timing_depth = 0
    ---@param callback                  function
    ---@param ...                       any
    ---@return any
    local function timed(callback, ...)
      local started = vim.uv.hrtime()
      timing_depth = timing_depth + 1
      local result = callback(...)
      timing_depth = timing_depth - 1
      if timing_depth == 0 then
        decoration_ms = decoration_ms + (vim.uv.hrtime() - started) / 1000000
      end
      return result
    end
    local register = vim.api.nvim_set_decoration_provider
    vim.api.nvim_set_decoration_provider = function(namespace, callbacks)
      if namespace == vim.api.nvim_get_namespaces()["ux.treeview"] then
        for _, name in ipairs({"on_win", "on_range", "on_end"}) do
          local callback = callbacks[name]
          callbacks[name] = function(...)
            return timed(callback, ...)
          end
        end
      end
      return register(namespace, callbacks)
    end
    if baseline ~= "" then
      package.loaded["ux.treeview.decorations"] = assert(loadfile(baseline .. "/decorations.lua"))()
      package.loaded["ux.treeview.surface"] = assert(loadfile(baseline .. "/surface.lua"))()
      package.loaded["ux.treeview.view"] = assert(loadfile(baseline .. "/view.lua"))()
    end
    ---@param future                    stl.c.Future
    ---@return any
    function await(future)
      assert(vim.wait(30000, function() return future:is_done() end))
      assert(not future:is_failed(), future:get_error())
      local result = future:get_result()
      assert(result.kind ~= "Rejected", vim.inspect(result))
      return result
    end
    local treeview = require("ux.treeview")
    local decorations = require("ux.treeview.decorations")
    local prepare = decorations.prepare
    decorations.prepare = function(frame, first, last, previous)
      counts.prepare = counts.prepare + 1
      local proxy = {
        id = function() return frame:id() end,
        header = function() return frame:header() end,
        rows = function(_, start, finish)
          counts.row_queries = counts.row_queries + 1
          local rows = frame:rows(start, finish)
          counts.exported_rows = counts.exported_rows + finish-start+1
          return rows
        end,
      }
      return prepare(proxy, first, last, previous)
    end
    if decorations.cursor_moved then
      local cursor_moved = decorations.cursor_moved
      decorations.cursor_moved = function(...)
        local started = vim.uv.hrtime()
        timed(cursor_moved, ...)
        path_update_ms = path_update_ms + (vim.uv.hrtime() - started) / 1000000
      end
    end
    data = treeview.new_data({ limits = { memory_bytes = 1024 * 1024 * 1024, nodes = count + 1,
      batch_nodes = count + 1, batch_bytes = 128 * 1024 * 1024 } })
    local upload = data:begin_import()
    local records = { { key = "root", label = "root", can_expand = true } }
    for index = 1, count do
      records[#records + 1] = {
        key = "n" .. index, parent = index == 1 and "root" or "n" .. math.floor((index - 2) / 8 + 1),
        label = string.format("node-%06d", index) .. string.rep("x", 85), can_expand = index * 8 - 6 <= count,
      }
      if #records == 512 then
        local reply = upload:append(records)
        assert(reply.kind == "NoChange", vim.inspect(reply))
        records = {}
      end
    end
    if #records > 0 then
      local reply = upload:append(records)
      assert(reply.kind == "NoChange", vim.inspect(reply))
    end
    await(upload:commit())
    state = await(data:create_state({kind="children_of",node=data:source():id("root")}))
    await(state:set_expanded({data:source():id("root")}, true, true))
    view = treeview.attach(state, {keymaps=false, on_frame=function(frame)
      if pending and frame:header().cursor_row == pending.row then
        pending.publication = vim.uv.hrtime()
      end
    end})
    assert(vim.wait(30000,function() return view:frame() and view:frame():header().row_count == count and not view._busy end))
    local set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(bufnr, ...)
      if bufnr == view.bufnr then writes = writes + 1 end
      return set_lines(bufnr, ...)
    end
    vim.api.nvim_set_option_value("cursorline", true, {win=view.winnr})
    await(view:set_cursor(20))
    assert(vim.wait(30000,function() return view:frame():header().cursor_row == 20 and not view._busy end))
    collectgarbage("collect")
  ]=],
    { root, library, baseline, count }
  )

  local output = {
    rows = count,
    ui = { 80, height },
    baseline = baseline ~= "",
    units = "milliseconds",
    paths = {},
    nvim = vim.version(),
    system = vim.uv.os_uname(),
  }
  for _, kind in ipairs({ "adjacent", "normal", "visible_branch", "burst", "early_redraw", "jump", "scroll", "visual" }) do
    if kind ~= "adjacent" and kind ~= "jump" and kind ~= "scroll" then
      ui:rpc(
        "nvim_exec_lua",
        [=[
        pending = nil
        await(view:set_cursor(20))
        assert(vim.wait(30000,function() return view:frame():header().cursor_row == 20 and not view._busy end))
        vim.api.nvim_win_call(view.winnr, function() vim.fn.winrestview({topline=1,leftcol=0}) end)
      ]=],
        {}
      )
    end
    if kind == "visual" then
      ui:rpc("nvim_exec_lua", 'vim.cmd.normal({args={"V"},bang=true})', {})
    end
    local flush, publication, decoration, path_update, settled = {}, {}, {}, {}, {}
    local calls =
      { prepare = 0, full_redraw = 0, range_redraw = 0, guide_marks = 0, row_queries = 0, exported_rows = 0 }
    for index = 1, samples + 30 do
      ui:rpc(
        "nvim_exec_lua",
        [=[
        local kind, index, count, height = ...
        local row
        if kind == "adjacent" or kind == "visual" or kind == "normal" then
          row = 20 + index % 2
        elseif kind == "visible_branch" or kind == "burst" or kind == "early_redraw" then
          row = index % 2 == 0 and 5 or math.min(height - 10, count)
        elseif kind == "jump" then
          row = 1 + index * 7919 % count
        else
          row = 1 + index % (count - 1)
        end
        if row == vim.api.nvim_win_get_cursor(view.winnr)[1] then row = row + 1 end
        if index == 31 then process_cpu_before = vim.uv.getrusage() end
        decoration_ms, path_update_ms = 0, 0
        for key in pairs(counts) do counts[key] = 0 end
        pending = {row=row, frame=view:frame():id(), started=vim.uv.hrtime()}
        if kind == "normal" then
          vim.cmd.normal({args={row > vim.api.nvim_win_get_cursor(view.winnr)[1] and "j" or "k"},bang=true})
        elseif kind == "early_redraw" then
          vim.api.nvim_win_set_cursor(view.winnr,{row,0})
          vim.cmd.redraw()
        else
          if kind == "burst" then
            for at = 1, 7 do
              view:set_cursor(at % 2 == 0 and row or (row == 5 and math.min(height - 10, count) or 5))
            end
          end
          pending.requires_commit = true
          view:set_cursor(row):finally(function(ok,result)
            assert(ok and result.kind == "Applied", vim.inspect(result))
            pending.commit = result.revisions.commit
          end)
        end
      ]=],
        { kind, index, count, height }
      )
      local timing
      assert(
        vim.wait(30000, function()
          timing = ui:rpc(
            "nvim_exec_lua",
            [=[
          assert(#errors == 0, table.concat(errors,"\n"))
          if pending.publication and view:frame():id() ~= pending.frame
            and view:frame():header().cursor_row == pending.row and not view._busy and not view._latest
            and not view._guide_dirty and not view._guide_redraw_pending
            and (not pending.requires_commit or pending.commit and state._native:applicable(view:frame(),pending.commit)) then
            return {pending.started,pending.publication,decoration_ms,path_update_ms,counts}
          end
        ]=],
            {}
          )
          -- Cursor-only publication may acknowledge a frame after its identical pixels have already flushed.
          return timing and ui.last_flush and ui.last_flush >= timing[1]
        end, 1),
        "cursor did not reach UI flush"
      )
      if index > 30 then
        flush[#flush + 1] = (ui.last_flush - timing[1]) / 1000000
        publication[#publication + 1] = (timing[2] - timing[1]) / 1000000
        decoration[#decoration + 1] = timing[3]
        path_update[#path_update + 1] = timing[4]
        settled[#settled + 1] = (math.max(timing[2], ui.last_flush) - timing[1]) / 1000000
        for key, value in pairs(timing[5]) do
          calls[key] = calls[key] + value / samples
        end
      end
    end
    local cpu_ms = ui:rpc(
      "nvim_exec_lua",
      [=[
      local after, before = vim.uv.getrusage(), process_cpu_before
      return (after.utime.sec+after.stime.sec-before.utime.sec-before.stime.sec)*1000
        + (after.utime.usec+after.stime.usec-before.utime.usec-before.stime.usec)/1000
    ]=],
      {}
    ) / samples
    output.paths[kind] = {
      cpu_ms_per_move = cpu_ms,
      flush = distribution(flush),
      publication = distribution(publication),
      decorations = distribution(decoration),
      path_update = distribution(path_update),
      settled = distribution(settled),
      calls_per_move = calls,
    }
  end
  output.writes = ui:rpc("nvim_exec_lua", "return writes", {})
  output.lua_heap_kib = ui:rpc("nvim_exec_lua", 'collectgarbage("collect"); return collectgarbage("count")', {})
  assert(output.writes == 0, "cursor movement wrote body text")
  ui:rpc("nvim_exec_lua", "view:detach()", {})
  return output
end, debug.traceback)
ui:close()
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
