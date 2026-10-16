---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.lsp.symbols" ---@type string

-- Coordinates textDocument/documentSymbol requests per buffer for the window breadcrumbs.
--
-- A trigger is only satisfied by a request issued after it: triggers wait in the next batch, which
-- moves into the request when it is issued, so freshness matches a request per trigger. The latest
-- confirmed tree only serves the cursor path until that request answers; server state can change
-- without any client-visible signal, so it never replaces a request.

local METHOD = "textDocument/documentSymbol" ---@type string
local INTERVAL = 128 ---@type integer
local LARGE_INTERVAL = 5000 ---@type integer
local LARGE_SYMBOLS = 10000 ---@type integer
local TIMEOUT = 10000 ---@type integer

---@class era.m.lsp.symbols.INode
---@field public name                   string
---@field public kind                   integer
---@field public sl                     integer
---@field public sc                     integer
---@field public el                     integer
---@field public ec                     integer
---@field public children               ?era.m.lsp.symbols.INode[]

---@class era.m.lsp.symbols.ITree
---@field public key                    string
---@field public encoding               string|nil
---@field public nodes                  era.m.lsp.symbols.INode[]
---@field public count                  integer

---@alias era.m.lsp.symbols.IDeliver fun(winnr: integer, symbols: dot.t.ILspSymbol[]): nil

---@class era.m.lsp.symbols.IRequest
---@field public key                    string
---@field public waiters                table<integer, era.m.lsp.symbols.IDeliver>
---@field public clients                table<integer, integer>
---@field public cancel                 ?fun(): nil
---@field public timer                  ?uv.uv_timer_t
---@field public settled                boolean

---@class era.m.lsp.symbols.IEntry
---@field public waiters                table<integer, era.m.lsp.symbols.IDeliver>
---@field public inflight               ?era.m.lsp.symbols.IRequest
---@field public issued_at              integer
---@field public flush_queued           boolean
---@field public timer                  ?uv.uv_timer_t
---@field public tree                   ?era.m.lsp.symbols.ITree

---@class era.m.lsp.symbols
local M = {}

local entries = {} ---@type table<integer, era.m.lsp.symbols.IEntry>
local augroup = nil ---@type integer|nil

---@param bufnr                         integer
---@return boolean
local function is_gated(bufnr)
  local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
  return support_documentSymbol < 1 or vim.b[bufnr][dot.var.N_WINLINE_DISABLED] == true
end

---@param winnr                         integer
---@return boolean
local function is_pum_blocked(winnr)
  return winnr == vim.api.nvim_get_current_win() and vim.fn.pumvisible() == 1
end

-- Besides the text, symbols depend on the document URI and the clients serving it; a restarted
-- client attaches with a new id.
---@param bufnr                         integer
---@return string
local function snapshot_key(bufnr)
  local ids = {} ---@type integer[]
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = METHOD })) do
    ids[#ids + 1] = client.id
  end
  table.sort(ids)
  return table.concat(
    { vim.api.nvim_buf_get_changedtick(bufnr), vim.uri_from_bufnr(bufnr), table.concat(ids, ",") },
    "\n"
  )
end

-- Errors stay silent until every client has answered once; a server that is still indexing is not a
-- failure.
---@param bufnr                         integer
---@return boolean
local function is_silent(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = METHOD })) do
    if not dot.state.status.lsp_symbol_ready[client.id] then
      return true
    end
  end
  return false
end

---@param encoding                      ?string
---@return string
local function normalize_encoding(encoding)
  if type(encoding) == "string" and encoding ~= "" then
    return string.lower(encoding)
  end
  return "utf-16"
end

---@param bufnr                         integer
---@param row                           integer
---@param byte_col                      integer
---@param encoding                      ?string
---@return integer
local function byte_col_to_client_character(bufnr, row, byte_col, encoding)
  local normalized = normalize_encoding(encoding) ---@type string
  if normalized == "utf-8" then
    return byte_col
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] ---@type string|nil
  if line == nil then
    return byte_col
  end

  local ok, character = pcall(vim.str_utfindex, line, normalized, byte_col)
  if ok and type(character) == "number" then
    return character
  end
  return byte_col
end

---@param bufnr                         integer
---@param position                      lsp.Position
---@param encoding                      ?string
---@return integer
local function position_to_byte_col(bufnr, position, encoding)
  local normalized = normalize_encoding(encoding) ---@type string
  local ok, col = pcall(vim.lsp.util._get_line_byte_from_position, bufnr, position, normalized) ---@type boolean, integer
  if ok and type(col) == "number" then
    return col
  end
  return position.character or 0
end

---@param range                         unknown
---@return boolean
local function is_range(range)
  return type(range) == "table"
    and type(range.start) == "table"
    and type(range["end"]) == "table"
    and type(range.start.line) == "number"
    and type(range.start.character) == "number"
    and type(range["end"].line) == "number"
    and type(range["end"].character) == "number"
end

-- Keeps only what the breadcrumbs read. JSON null decodes to vim.NIL, so every field is type checked.
---@param symbols                       unknown
---@param counter                       { count: integer }
---@return era.m.lsp.symbols.INode[]
local function compact(symbols, counter)
  local nodes = {} ---@type era.m.lsp.symbols.INode[]
  if type(symbols) ~= "table" then
    return nodes
  end

  for _, symbol in ipairs(symbols) do
    if type(symbol) == "table" then
      -- SymbolInformation carries a location and no hierarchy; DocumentSymbol carries a range.
      local location = symbol.location
      local is_information = type(location) == "table" ---@type boolean
      local range = is_information and location.range or symbol.range
      if is_range(range) then
        counter.count = counter.count + 1
        ---@type era.m.lsp.symbols.INode
        local node = {
          name = type(symbol.name) == "string" and symbol.name or "",
          kind = symbol.kind,
          sl = range.start.line,
          sc = range.start.character,
          el = range["end"].line,
          ec = range["end"].character,
        }
        if not is_information and type(symbol.children) == "table" then
          node.children = compact(symbol.children, counter)
        end
        nodes[#nodes + 1] = node
      end
    end
  end
  return nodes
end

-- Both ends are inclusive and the first containing sibling wins.
---@param nodes                         era.m.lsp.symbols.INode[]
---@param line                          integer
---@param character                     integer
---@param path                          era.m.lsp.symbols.INode[]
---@return era.m.lsp.symbols.INode[]
local function find_path(nodes, line, character, path)
  for _, node in ipairs(nodes) do
    if
      (line > node.sl or (line == node.sl and character >= node.sc))
      and (line < node.el or (line == node.el and character <= node.ec))
    then
      path[#path + 1] = node
      if node.children ~= nil then
        find_path(node.children, line, character, path)
      end
      return path
    end
  end
  return path
end

---@param bufnr                         integer
---@param winnr                         integer
---@param tree                          era.m.lsp.symbols.ITree
---@return dot.t.ILspSymbol[]
local function derive(bufnr, winnr, tree)
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(winnr)) ---@type integer, integer
  local line = cursor_row - 1 ---@type integer
  local character = byte_col_to_client_character(bufnr, line, cursor_col, tree.encoding) ---@type integer

  local symbols = {} ---@type dot.t.ILspSymbol[]
  for _, node in ipairs(find_path(tree.nodes, line, character, {})) do
    local byte_col = position_to_byte_col(bufnr, { line = node.sl, character = node.sc }, tree.encoding) ---@type integer
    symbols[#symbols + 1] = {
      kind = vim.lsp.protocol.SymbolKind[node.kind],
      name = node.name,
      row = node.sl + 1,
      col = byte_col + 1,
    }
  end
  return symbols
end

local flush

---@param bufnr                         integer
---@param entry                         era.m.lsp.symbols.IEntry
---@return nil
local function queue_flush(bufnr, entry)
  if entry.flush_queued then
    return
  end
  entry.flush_queued = true
  vim.schedule(function()
    entry.flush_queued = false
    if entries[bufnr] == entry then
      flush(bufnr, entry)
    end
  end)
end

---@param bufnr                         integer
---@param entry                         era.m.lsp.symbols.IEntry
---@param request                       era.m.lsp.symbols.IRequest
---@param tree                          ?era.m.lsp.symbols.ITree
---@return nil
local function settle(bufnr, entry, request, tree)
  if request.settled then
    return
  end
  request.settled = true
  stl.timer.clear_timer(request.timer)
  request.timer = nil
  if entry.inflight == request then
    entry.inflight = nil
  end

  -- A response for edited text still answers the windows that asked, but only an exact snapshot is
  -- confirmed; a failure leaves nothing confirmed until the next success.
  if tree == nil then
    entry.tree = nil
  elseif vim.api.nvim_buf_is_valid(bufnr) and snapshot_key(bufnr) == request.key then
    entry.tree = tree
  end

  if tree ~= nil then
    for winnr, deliver in pairs(request.waiters) do
      if vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) == bufnr then
        local ok, err = pcall(deliver, winnr, derive(bufnr, winnr, tree))
        if not ok then
          stl.reporter.error({
            from = __module_name__,
            subject = "settle",
            message = "Failed to deliver document symbols",
            details = { err = err, bufnr = bufnr, winnr = winnr },
          })
        end
      end
    end
  end

  if entries[bufnr] == entry and next(entry.waiters) ~= nil then
    queue_flush(bufnr, entry)
  end
end

-- A request whose windows are all gone answers nobody, so its failures are not worth reporting.
---@param bufnr                         integer
---@param request                       era.m.lsp.symbols.IRequest
---@return boolean
local function has_live_waiter(bufnr, request)
  for winnr in pairs(request.waiters) do
    if vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) == bufnr then
      return true
    end
  end
  return false
end

---@param bufnr                         integer
---@param entry                         era.m.lsp.symbols.IEntry
---@param request                       era.m.lsp.symbols.IRequest
---@param err                           ?lsp.ResponseError
---@param result                        unknown
---@param ctx                           ?lsp.HandlerContext
---@return nil
local function on_response(bufnr, entry, request, err, result, ctx)
  local client_id = ctx ~= nil and ctx.client_id or nil ---@type integer|nil
  if client_id ~= nil then
    dot.state.status.lsp_symbol_ready[client_id] = true
  end
  if request.settled then
    return
  end

  if err ~= nil then
    local message = type(err) == "table" and err.message or nil ---@type string|nil
    if message == "trying to get AST for non-added document" and vim.api.nvim_buf_is_valid(bufnr) then
      vim.b[bufnr][dot.var.N_WINLINE_DISABLED] = true
    elseif
      message ~= "Content modified."
      and not dot.state.status.suppress_warning:snapshot()
      and has_live_waiter(bufnr, request)
    then
      stl.reporter.error({
        from = __module_name__,
        subject = "request",
        message = "Failed to request document symbols",
        details = { err = err, result = result, bufnr = bufnr },
      })
    end
    settle(bufnr, entry, request, nil)
    return
  end

  local client = client_id ~= nil and vim.lsp.get_client_by_id(client_id) or nil ---@type vim.lsp.Client|nil
  local counter = { count = 0 } ---@type { count: integer }
  ---@type era.m.lsp.symbols.ITree
  local tree = {
    key = request.key,
    encoding = client ~= nil and client.offset_encoding or nil,
    nodes = compact(result, counter),
    count = 0,
  }
  tree.count = counter.count
  settle(bufnr, entry, request, tree)
end

---@param bufnr                         integer
---@param entry                         era.m.lsp.symbols.IEntry
---@param key                           string
---@return nil
local function issue(bufnr, entry, key)
  ---@type era.m.lsp.symbols.IRequest
  local request = { key = key, waiters = entry.waiters, clients = {}, settled = false }
  entry.waiters = {}
  entry.inflight = request
  entry.issued_at = vim.uv.now()

  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local ids, cancel = vim.lsp.buf_request(bufnr, METHOD, params, function(err, result, ctx)
    on_response(bufnr, entry, request, err, result, ctx)
  end, stl.fn.noop)
  -- An in-process server may answer before buf_request returns.
  if request.settled then
    return
  end
  if ids == nil or next(ids) == nil then
    settle(bufnr, entry, request, nil)
    return
  end

  request.cancel = cancel
  for client_id, request_id in pairs(ids) do
    request.clients[client_id] = request_id
  end
  request.timer = stl.timer.delay(function()
    if request.settled then
      return
    end
    if request.cancel ~= nil then
      pcall(request.cancel)
    end
    if vim.api.nvim_buf_is_valid(bufnr) and has_live_waiter(bufnr, request) and not is_silent(bufnr) then
      stl.reporter.error({
        from = __module_name__,
        subject = "request",
        message = "Timed out requesting document symbols",
        details = { bufnr = bufnr, timeout = TIMEOUT },
      })
    end
    settle(bufnr, entry, request, nil)
  end, TIMEOUT)
end

---@param bufnr                         integer
---@param entry                         era.m.lsp.symbols.IEntry
---@return nil
function flush(bufnr, entry)
  if entry.inflight ~= nil then
    return
  end

  for winnr in pairs(entry.waiters) do
    if not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= bufnr or is_pum_blocked(winnr) then
      entry.waiters[winnr] = nil
    end
  end
  if next(entry.waiters) == nil then
    return
  end
  if not vim.api.nvim_buf_is_valid(bufnr) or is_gated(bufnr) then
    entry.waiters = {}
    return
  end

  -- Large documents keep their confirmed tree between sparser requests while the snapshot holds;
  -- the waiting batch guarantees the trailing request.
  local key = snapshot_key(bufnr) ---@type string
  local tree = entry.tree ---@type era.m.lsp.symbols.ITree|nil
  local interval = (tree ~= nil and tree.key == key and tree.count >= LARGE_SYMBOLS) and LARGE_INTERVAL or INTERVAL
  local wait = interval - (vim.uv.now() - entry.issued_at) ---@type integer
  if wait > 0 then
    stl.timer.clear_timer(entry.timer)
    entry.timer = stl.timer.delay(function()
      entry.timer = nil
      if entries[bufnr] == entry then
        flush(bufnr, entry)
      end
    end, wait)
    return
  end

  issue(bufnr, entry, key)
end

---@param bufnr                         integer
---@return nil
local function teardown(bufnr)
  local entry = entries[bufnr]
  if entry == nil then
    return
  end
  entries[bufnr] = nil
  stl.timer.clear_timer(entry.timer)
  local request = entry.inflight
  if request ~= nil then
    request.settled = true
    stl.timer.clear_timer(request.timer)
    if request.cancel ~= nil then
      pcall(request.cancel)
    end
  end
end

---@return nil
local function setup_autocmds()
  if augroup ~= nil then
    return
  end
  augroup = stl.nvim.fn.augroup(__module_name__)

  vim.api.nvim_create_autocmd("LspDetach", {
    group = augroup,
    callback = function(ev)
      local entry = entries[ev.buf]
      if entry == nil then
        return
      end
      entry.tree = nil
      -- A detached client never answers for the buffer; cancel its request and settle once no client
      -- remains outstanding.
      local request = entry.inflight
      local client_id = ev.data and ev.data.client_id or nil ---@type integer|nil
      local request_id = request ~= nil and client_id ~= nil and request.clients[client_id] or nil ---@type integer|nil
      if request ~= nil and client_id ~= nil and request_id ~= nil then
        request.clients[client_id] = nil
        local client = vim.lsp.get_client_by_id(client_id) ---@type vim.lsp.Client|nil
        if client ~= nil and client.requests[request_id] ~= nil then
          pcall(client.cancel_request, client, request_id)
        end
        if next(request.clients) == nil then
          settle(ev.buf, entry, request, nil)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufHidden", {
    group = augroup,
    callback = function(ev)
      local entry = entries[ev.buf]
      if entry ~= nil then
        entry.tree = nil
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = augroup,
    callback = function(ev)
      teardown(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      for bufnr in pairs(entries) do
        teardown(bufnr)
      end
    end,
  })
end

---Joins the next documentSymbol request for the buffer shown in the window. `on_result` runs once
---with the path at the cursor when the response arrives, `{}` outside every symbol; a failed or
---gated request leaves the window's current path untouched and calls nothing.
---@param winnr                         integer
---@param on_result                     era.m.lsp.symbols.IDeliver
---@return nil
function M.request(winnr, on_result)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if is_gated(bufnr) then
    return
  end

  setup_autocmds()
  local entry = entries[bufnr]
  if entry == nil then
    entry = { waiters = {}, inflight = nil, issued_at = -INTERVAL, flush_queued = false }
    entries[bufnr] = entry
  end
  entry.waiters[winnr] = on_result
  queue_flush(bufnr, entry)
end

---Path at the window cursor from the confirmed tree of the current snapshot, or nil when no such tree
---exists; the next request still decides what the window finally shows.
---@param winnr                         integer
---@return dot.t.ILspSymbol[]|nil
function M.path(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local entry = entries[bufnr]
  local tree = entry ~= nil and entry.tree or nil ---@type era.m.lsp.symbols.ITree|nil
  if tree == nil or is_gated(bufnr) or is_pum_blocked(winnr) or snapshot_key(bufnr) ~= tree.key then
    return nil
  end
  return derive(bufnr, winnr, tree)
end

return M
