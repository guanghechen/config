---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.load_editor" ---@type string

local Data = require("__test__.bench.cmp.data")
local Editor = require("__test__.bench.cmp.editor")
local M = {}

---@return table
local function resources()
  return {
    usage = vim.uv.getrusage(),
    process_memory_bytes = Data.process_memory_bytes(),
    lua_heap_bytes = collectgarbage("count") * 1024,
  }
end

---@param line                          string
---@param count                         integer
---@param items                         table[]
---@return nil
local function menu_event(line, count, items)
  local first = items[1]
  local raw = first and (first.raw or first)
  local generation = raw and raw._cmp_bench_request or 1
  M.last_menu = { line = line, count = count, generation = generation }
  local trace = M.trace
  if trace == nil then
    return
  end
  local request = M.requests[generation]
  local event = {
    time_ns = vim.uv.hrtime(),
    sequence = #trace.keys,
    query = line,
    buffer_line = vim.api.nvim_buf_get_lines(M.bufnr, 0, 1, false)[1],
    mode = vim.api.nvim_get_mode().mode,
    count = count,
    visible = M.cmp.is_menu_visible(),
    generation = generation,
    request_sequence = request and request.sequence,
    request_query = request and request.query,
  }
  trace.menus[#trace.menus + 1] = event
  vim.rpcnotify(1, "cmp_load_menu", event)
end

---@param options                       table
---@return nil
function M.setup(options)
  M.options = options
  M.namespace = vim.api.nvim_create_namespace(__module_name__)
  M.requests = {}
  M.bufnr = vim.api.nvim_get_current_buf()
  if options.engine == "none" then
    vim.api.nvim_set_option_value("shortmess", "filnxtToOFWIcC", {})
    return
  end
  Editor.setup(options)
  Editor.menu_event = menu_event
  M.cmp = Editor.cmp
  for _, client in ipairs(vim.lsp.get_clients()) do
    client.request = function(_, method, params, callback)
      assert(method == "textDocument/completion", method)
      local id = #M.requests + 1
      local delays = options.response_delays or { 0 }
      local delay = delays[(id - 1) % #delays + 1]
      local request = {
        id = id,
        time_ns = vim.uv.hrtime(),
        sequence = M.trace and #M.trace.keys or 0,
        query = vim.api.nvim_get_current_line(),
        character = params.position.character,
        delay_ms = delay,
        cancel_calls = 0,
      }
      M.requests[id] = request
      if M.trace ~= nil then
        vim.rpcnotify(1, "cmp_load_request", id)
      end
      local raw = assert(M.pool[id], "load response pool exhausted: " .. id)
      vim.defer_fn(function()
        request.response_ns = vim.uv.hrtime()
        if M.trace ~= nil then
          vim.rpcnotify(1, "cmp_load_response", id)
        end
        -- Deliver even after cancellation: clients must reject obsolete server responses themselves.
        callback(nil, { items = raw, isIncomplete = options.incomplete == true })
      end, delay)
      return true, id
    end
    client.cancel_request = function(_, id)
      local request = assert(M.requests[id])
      request.cancel_calls = request.cancel_calls + 1
      if request.cancel_ns == nil then
        request.cancel_ns = vim.uv.hrtime()
        request.cancelled_inflight = request.response_ns == nil
      end
    end
  end
end

---@param key_count                     integer
---@return nil
function M.prepare(key_count)
  assert(M.trace == nil, "previous burst still active")
  if M.cmp ~= nil then
    M.cmp.hide()
  end
  M.last_menu = nil
  local previous = M.bufnr
  M.bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(M.bufnr)
  vim.api.nvim_buf_delete(previous, { force = true })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = M.bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = M.bufnr })
  vim.api.nvim_buf_set_name(M.bufnr, M.options.output .. "/load-" .. M.bufnr .. ".lua")
  M.requests, M.pool = {}, {}
  if M.cmp ~= nil then
    local response_count = (M.options.incomplete or not M.options.seed) and key_count + 4 or 2
    for id = 1, response_count do
      local raw = Data.items(Editor.labels)
      for _, item in ipairs(raw) do
        item._cmp_bench_request = id
      end
      M.pool[id] = raw
    end
  end
  vim.api.nvim_buf_attach(M.bufnr, false, {
    on_lines = function(_, bufnr)
      local trace = M.trace
      if trace ~= nil and bufnr == M.bufnr then
        local event = {
          sequence = #trace.keys,
          time_ns = vim.uv.hrtime(),
          line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1],
        }
        trace.lines[#trace.lines + 1] = event
        vim.rpcnotify(1, "cmp_load_line", event)
      end
    end,
  })
  vim.v.errmsg = ""
  collectgarbage("collect")
end

---@return boolean
function M.ready()
  if M.cmp == nil then
    return vim.api.nvim_get_mode().mode == "i"
  end
  return M.last_menu ~= nil and M.last_menu.line == M.options.seed and M.last_menu.count > 0
end

---@param plan                          table[]
---@return nil
function M.begin(plan)
  collectgarbage("collect")
  local trace = {
    keys = {},
    lines = {},
    menus = {},
    heartbeat_gaps_ms = {},
    unexpected_keys = {},
    start_ns = vim.uv.hrtime(),
    before = resources(),
    initial_requests = #M.requests,
    profile = { cost = {}, calls = {} },
  }
  M.trace = trace
  Editor.active = trace.profile
  local expected = {}
  for index, step in ipairs(plan) do
    expected[index] = vim.api.nvim_replace_termcodes(step.key, true, false, true)
  end
  vim.on_key(function(key, typed)
    if typed == "" then
      return
    end
    -- A fresh burst enters insert mode with "ig"; only the text key belongs to the workload.
    if key == "i" and #trace.keys == 0 and not M.options.seed then
      return
    end
    local sequence = #trace.keys + 1
    local event = { sequence = sequence, time_ns = vim.uv.hrtime(), key = vim.fn.keytrans(key) }
    if key ~= expected[sequence] then
      trace.unexpected_keys[#trace.unexpected_keys + 1] = event
    end
    trace.keys[sequence] = event
    if plan[sequence] and plan[sequence].key == "<Esc>" then
      trace.escape_ns = event.time_ns
    end
    if sequence == #plan then
      vim.rpcnotify(1, "cmp_load_input_done", event.time_ns)
    end
  end, M.namespace)
  local previous = vim.uv.hrtime()
  M.heartbeat = assert(vim.uv.new_timer())
  M.heartbeat:start(2, 2, function()
    local now = vim.uv.hrtime()
    trace.heartbeat_gaps_ms[#trace.heartbeat_gaps_ms + 1] = (now - previous) / 1e6
    previous = now
  end)
end

---@return table
function M.finish()
  local trace = assert(M.trace)
  for _, request in ipairs(M.requests) do
    assert(request.response_ns ~= nil, "finish before all server responses settled")
  end
  trace.end_ns = vim.uv.hrtime()
  trace.after = resources()
  M.heartbeat:stop()
  M.heartbeat:close()
  vim.on_key(nil, M.namespace)
  M.trace = nil
  Editor.active = nil
  trace.requests = M.requests
  trace.final_line = vim.api.nvim_buf_get_lines(M.bufnr, 0, 1, false)[1]
  trace.final_mode = vim.api.nvim_get_mode().mode
  trace.final_visible = M.cmp ~= nil and M.cmp.is_menu_visible() or false
  trace.final_menu = M.last_menu
  trace.errmsg = vim.v.errmsg
  trace.notices = Editor.notices or {}
  local start = vim.uv.hrtime()
  collectgarbage("collect")
  trace.full_gc_ms = (vim.uv.hrtime() - start) / 1e6
  trace.after_gc = resources()
  return trace
end

return M
