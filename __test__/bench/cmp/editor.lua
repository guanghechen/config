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
  if options.blink ~= nil then
    vim.opt.runtimepath:append(options.blink)
  end
  local Runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
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
  if options.engine == "era" then
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
      M.menu_event(context.line, #items, nil, items)
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
  else
    M.cmp = require("blink.cmp")
    M.cmp.setup({
      fuzzy = {
        implementation = "rust",
        prebuilt_binaries = { download = false },
        frecency = {
          enabled = options.frecency == true,
          path = options.output .. "/frecency-" .. vim.uv.os_getpid() .. ".dat",
        },
        sorts = { "score", "exact", "sort_text" },
        max_typos = function(query)
          return math.min(2, math.floor(vim.str_utfindex(query, "utf-32") / 4))
        end,
      },
      sources = {
        default = sources,
        providers = {
          lsp = { score_offset = 180 },
          buffer = {
            score_offset = 100,
            opts = {
              get_bufnrs = function()
                return vim.api.nvim_list_bufs()
              end,
            },
          },
        },
      },
      keymap = {
        preset = "none",
        ["<Tab>"] = { "select_next", "fallback" },
        ["<CR>"] = { "select_and_accept", "fallback" },
      },
      completion = {
        keyword = { range = "prefix" },
        list = { max_items = 200, selection = { preselect = true, auto_insert = true } },
        menu = {
          border = "rounded",
          max_height = 10,
          draw = {
            treesitter = {},
            columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
          },
        },
        documentation = { auto_show = false },
        ghost_text = { enabled = false },
      },
      signature = { enabled = false },
      cmdline = { enabled = false },
    })
    assert(
      vim.wait(5000, function()
        return package.loaded["blink.cmp.completion.windows.menu"] ~= nil
      end, 1),
      "Blink setup timeout"
    )
    if options.frecency and (options.frecency_entries or 0) > 0 then
      local fuzzy = require("blink.cmp.fuzzy")
      fuzzy.init_db()
      -- Seed synchronously so background DB writes cannot leak into timed bursts.
      for index = 1, math.min(options.frecency_entries, #M.labels) do
        local label = M.labels[(index * 7919) % #M.labels + 1]
        assert(fuzzy.implementation.access({ label = label, kind = 6, source_id = "lsp" }))
      end
    end
    profile(require("blink.cmp.fuzzy").implementation, "set_provider_items", "prepare")
    profile(require("blink.cmp.fuzzy"), "fuzzy", "rank_including_prepare")
    local menu = require("blink.cmp.completion.windows.menu")
    profile(menu, "open_with_items", "menu")
    local show = menu.open_with_items
    menu.open_with_items = function(context, items)
      show(context, items)
      M.menu_event(context.line, #items, menu.win:get_win(), items)
    end
    vim.api.nvim_create_autocmd("User", {
      pattern = "BlinkCmpAccept",
      callback = function()
        if M.active ~= nil then
          vim.rpcnotify(1, "cmp_bench_accept", M.active.sequence, (vim.uv.hrtime() - M.active.start) / 1e6)
        end
      end,
    })
  end
  if options.engine == "blink" then
    vim.api.nvim_create_autocmd("User", {
      pattern = "BlinkCmpListSelect",
      callback = function()
        if M.active ~= nil and M.active.keys == "<Tab>" then
          vim.rpcnotify(1, "cmp_bench_select", M.active.sequence, (vim.uv.hrtime() - M.active.start) / 1e6)
        end
      end,
    })
  end
  return { setup_ms = (vim.uv.hrtime() - start) / 1e6, rss_kib = Data.rss_kib(), lua_kib = collectgarbage("count") }
end

---@param line                          string
---@param count                         integer
---@param winnr                         ?integer
---@param _items                        ?table[]
---@return nil
function M.menu_event(line, count, winnr, _items)
  local active = M.active
  if active == nil or line ~= active.query or count == 0 or not M.cmp.is_menu_visible() then
    return
  end
  active.renders = active.renders + 1
  vim.rpcnotify(1, "cmp_bench_menu", {
    sequence = active.sequence,
    elapsed_ms = (vim.uv.hrtime() - active.start) / 1e6,
    count = count,
    winnr = winnr,
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
    rss_kib = Data.rss_kib(),
    lua_kib = collectgarbage("count"),
    notices = M.notices,
    mode = vim.api.nvim_get_mode().mode,
  }
end

return M
