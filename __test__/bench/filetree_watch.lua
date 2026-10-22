-- Usage, from the repository root: nvim -l __test__/bench/filetree_watch.lua [iterations=20]
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.filetree_watch" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local iterations = tonumber(arg[1]) or 20
assert(iterations >= 1 and iterations <= 100)
local directory = vim.fn.tempname()
assert(vim.uv.fs_mkdir(directory, 448))
vim.fn.writefile({ "content" }, directory .. "/item-0")
local ui = require("__test__.support.ui").new()
local Record = require("__test__.bench.record")
local Stats = require("__test__.bench.stats")

local ok, result = xpcall(function()
  ui:rpc("nvim_ui_attach", 80, 24, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, directory = ...
    vim.opt.runtimepath:prepend(root)
    yoz = assert(package.loadlib(root .. "/lua/yoz.so", "luaopen_yoz"))()
    stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") }, reporter = { error = function(value) error(value.message) end } }
    local function await(future)
      assert(vim.wait(10000, function() return future:is_done() end, 1))
      assert(not future:is_failed(), future:get_error())
      local value = future:get_result()
      assert(not (type(value) == "table" and value.kind == "Rejected"), vim.inspect(value))
      return value
    end
    local filetree = require("ux.filetree")
    data = await(filetree.open(directory))
    state = await(data:create_state())
    view = filetree.attach(state, { keymaps = false })
    item = await(data:resolve(directory .. "/item-0")):node()
    assert(vim.wait(10000, function() return view:frame() and view:frame():header().row_count == 1 and data:watch_status().directories > 0 end, 1))
    local poll = data._tree._poll
    data._tree._poll = function(owner)
      if pending then
        local node = data:source():node(item)
        if node and node.label == pending.name then pending.source = pending.source or vim.uv.hrtime() end
      end
      return poll(owner)
    end
    local redraw = vim.api.nvim__redraw
    vim.api.nvim__redraw = function(options)
      if pending and view:frame() and view:frame():rows(1, 1).labels[1] == pending.name then
        pending.published = pending.published or vim.uv.hrtime()
      end
      return redraw(options)
    end
  ]],
    { root, directory }
  )
  local changes, publications = {}, {}
  for index = 1, iterations do
    -- Isolate each rename: a change within 150 ms of the previous re-read continues that activity.
    vim.wait(200)
    ui:rpc("nvim_exec_lua", "pending = {name = ..., started = vim.uv.hrtime()}", { "item-" .. index })
    assert(vim.uv.fs_rename(directory .. "/item-" .. (index - 1), directory .. "/item-" .. index))
    local deadline = vim.uv.hrtime() + 10000000000
    ui:wait_until(function()
      assert(vim.uv.hrtime() < deadline, "watch measurement timed out")
      local times =
        ui:rpc("nvim_exec_lua", "return {pending.started, pending.source or false, pending.published or false}", {})
      if times[2] and times[3] and ui.last_flush and ui.last_flush >= times[3] then
        changes[#changes + 1] = (ui.last_flush - times[1]) / 1000000
        publications[#publications + 1] = (ui.last_flush - times[2]) / 1000000
        return true
      end
      return false
    end, 10000, nil, 1)
  end
  local released = ui:rpc(
    "nvim_exec_lua",
    [[
    pending = nil
    view:detach()
    assert(vim.wait(10000, function() return data:watch_status().directories == 0 and not data:native():is_busy() end, 1))
    collectgarbage("collect")
    return { watches = data:watch_status().directories, rust = data:native():stats(), lua_heap_bytes = collectgarbage("count") * 1024, process_memory_bytes = vim.uv.resident_set_memory() }
  ]],
    {}
  )
  return {
    change_to_flush = Stats.summary(changes),
    observed_source_to_flush = Stats.summary(publications),
    after_detach = released,
  }
end, debug.traceback)
ui:close()
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
local conditions = { iterations = iterations, idle_before_change_ms = 200, ui = { 80, 24 } }
io.stdout:write("results: ", Record.write("filetree_watch", { conditions = conditions, results = result }), "\n")
