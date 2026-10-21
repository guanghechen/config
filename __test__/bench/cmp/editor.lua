---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.editor" ---@type string

local Data = require("__test__.bench.cmp.data")
local M = {}

---@param object                        table
---@param key                           string
---@param category                      string
---@return nil
local function profile(object, key, category)
  local original = object[key]
  object[key] = function(...)
    local start = vim.uv.hrtime()
    local result = { original(...) }
    local active = M.active
    if active ~= nil then
      active.cost[category] = (active.cost[category] or 0) + (vim.uv.hrtime() - start) / 1e6
      active.calls[category] = (active.calls[category] or 0) + 1
    end
    return unpack(result)
  end
end

---@param options                       table
---@return table
function M.setup(options)
  M.options = options
  M.notices = {}
  vim.notify = function(message, level)
    M.notices[#M.notices + 1] = { message = message, level = level }
  end
  vim.opt.runtimepath:prepend(options.root)
  local Runtime = require("__test__.support.cmp.runtime")
  Runtime.setup(options.baseline)
  if not options.frecency then
    dot.context.frecency.completions = nil
  end
  vim.api.nvim_set_option_value("filetype", "lua", { buf = 0 })
  vim.api.nvim_set_option_value("swapfile", false, { buf = 0 })
  vim.api.nvim_set_option_value("shortmess", "filnxtToOFWIcC", {})
  vim.api.nvim_buf_set_name(0, options.output .. "/bench.lua")
  M.bufnr = vim.api.nvim_get_current_buf()
  M.labels = Data.labels(options.count, options.dense)
  M.requests, M.responses = {}, {}
  local clients = {}
  for index, delay in ipairs(options.delays or { 0 }) do
    local client = {
      id = 9000 + index,
      name = "bench_" .. index,
      offset_encoding = "utf-16",
      server_capabilities = { completionProvider = { resolveProvider = false, triggerCharacters = { "." } } },
      cancel_request = function() end,
      is_stopped = function()
        return false
      end,
      supports_method = function(_, method)
        return method == "textDocument/completion"
      end,
    }
    client.request = function(_, method, params, callback)
      assert(method == "textDocument/completion", method)
      M.requests[index] = (M.requests[index] or 0) + 1
      local id = M.requests[index]
      local raw = assert(M.responses[index][id], "response pool exhausted")
      if M.active ~= nil then
        M.active.requests = M.active.requests + 1
      end
      local defaults = options.defaults
          and {
            editRange = { start = { line = params.position.line, character = 0 }, ["end"] = params.position },
            insertTextFormat = 1,
            data = { fixture = true },
          }
        or nil
      vim.defer_fn(function()
        callback(nil, { items = raw, isIncomplete = options.incomplete == true, itemDefaults = defaults })
      end, delay)
      return true, id
    end
    clients[index] = client
  end
  vim.lsp.get_clients = function(filter)
    if filter == nil or filter.method == nil or filter.method == "textDocument/completion" then
      return clients
    end
    return {}
  end
  vim.lsp.get_client_by_id = function(id)
    return clients[id - 9000]
  end
  if options.buffer then
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, Data.labels(options.buffer))
  end
  local sources = options.buffer and { "lsp", "buffer" } or { "lsp" }
  local start = vim.uv.hrtime()
  if options.frecency then
    local Item = require("era.keystroke.cmp.item")
    for index = 1, math.min(options.frecency_entries or 0, #M.labels) do
      local label = M.labels[(index * 7919) % #M.labels + 1]
      local item = assert(Item.new(Runtime.context(""), "lsp", { label = label }, clients[1]))
      dot.context.frecency.completions:access("lua\0" .. item.frecency_key)
    end
  end
  require("era.keystroke.cmp.policy").sources_for = function()
    return sources
  end
  M.cmp = require("era.keystroke.cmp")
  M.cmp.setup()
  local session = require("era.keystroke.cmp.session")
  local select = session.on_complete_changed
  session.on_complete_changed = function(...)
    local result = select(...)
    if M.active ~= nil and M.active.keys == "<Tab>" then
      vim.rpcnotify(1, "cmp_bench_select", M.active.sequence, (vim.uv.hrtime() - M.active.start) / 1e6)
    end
    return result
  end
  profile(require("era.keystroke.cmp.rank"), "prepare", "prepare")
  profile(require("era.keystroke.cmp.rank"), "filter", "rank")
  profile(require("era.keystroke.cmp.source.lsp"), "response", "normalize_lsp")
  local menu = require("era.keystroke.cmp.menu")
  profile(menu, "show", "menu")
  local show = menu.show
  menu.show = function(self, context, items, selected)
    show(self, context, items, selected)
    M.menu_event(context.line, #items, items)
  end
  local edit = require("era.keystroke.cmp.edit")
  local apply = edit.apply
  edit.apply = function(...)
    local result = apply(...)
    if result and M.active ~= nil and M.active.keys == "<CR>" then
      vim.rpcnotify(1, "cmp_bench_accept", M.active.sequence, (vim.uv.hrtime() - M.active.start) / 1e6)
    end
    return result
  end
  return { setup_ms = (vim.uv.hrtime() - start) / 1e6, process_memory_bytes = Data.process_memory_bytes(), lua_heap_bytes = collectgarbage("count") * 1024 }
end

---@param line                          string
---@param count                         integer
---@param _items                        table[]
---@return nil
function M.menu_event(line, count, _items)
  local active = M.active
  if active == nil or line ~= active.query or count == 0 or not M.cmp.is_menu_visible() then
    return
  end
  active.renders = active.renders + 1
  vim.rpcnotify(1, "cmp_bench_menu", {
    sequence = active.sequence,
    elapsed_ms = (vim.uv.hrtime() - active.start) / 1e6,
    count = count,
    cost = vim.deepcopy(active.cost),
    calls = vim.deepcopy(active.calls),
  })
end

---@return nil
function M.reset()
  M.active = nil
  M.cmp.hide()
  vim.api.nvim_set_current_buf(M.bufnr)
  vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, { "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  M.requests, M.responses = {}, {}
  for client = 1, #(M.options.delays or { 0 }) do
    M.responses[client] = {}
    for response = 1, M.options.incomplete and 8 or 2 do
      M.responses[client][response] = Data.items(M.labels)
    end
  end
  collectgarbage("collect")
end

---@param sequence                      integer
---@param keys                          string
---@param query                         string
---@return nil
function M.input(sequence, keys, query)
  M.active = {
    sequence = sequence,
    start = vim.uv.hrtime(),
    keys = keys,
    query = query,
    cost = {},
    calls = {},
    requests = 0,
    renders = 0,
  }
  vim.api.nvim_input(keys)
end

---@return table
function M.snapshot()
  return {
    active = M.active,
    requests = M.requests,
    line = vim.api.nvim_get_current_line(),
    errmsg = vim.v.errmsg,
    process_memory_bytes = Data.process_memory_bytes(),
    lua_heap_bytes = collectgarbage("count") * 1024,
    notices = M.notices,
    mode = vim.api.nvim_get_mode().mode,
  }
end

return M
