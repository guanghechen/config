---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.filetree_watch" ---@type string

local root =
  vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))))))
vim.api.nvim_set_current_dir(root)
vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local samples = tonumber(arg[1]) or 20
assert(samples >= 1 and samples <= 100)
local directory = vim.fn.tempname()
assert(vim.uv.fs_mkdir(directory, 448))
vim.fn.writefile({ "content" }, directory .. "/item-0")
local ui = require("__test__.support.ui").new()

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
  for index = 1, samples do
    ui:rpc("nvim_exec_lua", "pending = {name = ..., started = vim.uv.hrtime()}", { "item-" .. index })
    assert(vim.uv.fs_rename(directory .. "/item-" .. (index - 1), directory .. "/item-" .. index))
    local deadline = vim.uv.hrtime() + 10000000000
    assert(vim.wait(10000, function()
      assert(vim.uv.hrtime() < deadline, "watch measurement timed out")
      local times =
        ui:rpc("nvim_exec_lua", "return {pending.started, pending.source or false, pending.published or false}", {})
      if times[2] and times[3] and ui.last_flush and ui.last_flush >= times[3] then
        changes[#changes + 1] = (ui.last_flush - times[1]) / 1000000
        publications[#publications + 1] = (ui.last_flush - times[2]) / 1000000
        return true
      end
      return false
    end, 1))
  end
  local released = ui:rpc(
    "nvim_exec_lua",
    [[
    pending = nil
    view:detach()
    assert(vim.wait(10000, function() return data:watch_status().directories == 0 and not data._native:is_busy() end, 1))
    collectgarbage("collect")
    return { watches = data:watch_status().directories, rust = data._native:stats(), lua_heap_kib = collectgarbage("count") }
  ]],
    {}
  )
  return {
    samples = samples,
    units = "milliseconds",
    merge_window_ms = 150,
    change_to_flush = distribution(changes),
    observed_source_to_flush = distribution(publications),
    after_detach = released,
    system = vim.uv.os_uname(),
    nvim = vim.version(),
  }
end, debug.traceback)
ui:close()
vim.fn.delete(directory, "rf")
assert(ok, result)
io.stdout:write(vim.json.encode(result), "\n")
