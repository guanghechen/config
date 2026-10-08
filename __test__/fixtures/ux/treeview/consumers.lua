---@diagnostic disable: undefined-global
local __module_name__ = "__test__.fixtures.ux.treeview.consumers"
local M = {}

---@param future                        stl.c.Future
---@return any
local function await(future)
  assert(vim.wait(30000, function()
    return future:is_done()
  end, 1))
  assert(not future:is_failed(), future:get_error())
  local result = future:get_result()
  assert(result.kind ~= "Rejected", vim.inspect(result))
  return result
end

---@param path                          string
---@param text                          string
---@return nil
local function write(path, text)
  local file = assert(io.open(path, "wb"))
  assert(file:write(text))
  assert(file:close())
end

---@param job                           table|userdata
---@param request                       table
---@return stl.c.Future
local function read_job(job, request)
  return stl.c.Future.new(function(resolve, reject)
    local poll
    poll = function()
      if request.is_cancelled() then
        job:cancel()
      end
      local started = vim.uv.hrtime()
      local status, value, err = job:poll()
      M.pending.native_poll_ns = M.pending.native_poll_ns + vim.uv.hrtime() - started
      if status == "running" then
        vim.defer_fn(poll, 1)
      else
        job:dispose()
        if status == "completed" then
          M.pending.io_ready = vim.uv.hrtime()
          M.pending.raw_heap_kib = collectgarbage("count")
          resolve(value)
        else
          reject(err or status)
        end
      end
    end
    poll()
  end)
end

---@return table
local function listing()
  local result, err = yoz.fs.readdir(M.directory)
  assert(result, vim.inspect(err))
  local records = {}
  for _, item in ipairs(result.items) do
    records[#records + 1] = {
      key = item.name,
      label = item.name,
      right_text = item.size,
      fields = { path = M.directory .. "/" .. item.name },
    }
  end
  return records
end

---@return table
local function search_page()
  local started = vim.uv.hrtime()
  local records = {}
  while #records < 128 and M.file_at <= #M.found.items do
    local file = M.found.items[M.file_at]
    if M.match_at == 0 then
      records[#records + 1] = { key = file.p, label = vim.fs.basename(file.p), can_expand = true }
      M.match_at = 1
    elseif M.match_at <= #file.matches then
      local match = file.matches[M.match_at]
      records[#records + 1] = {
        key = file.p .. ":" .. M.match_at,
        parent = file.p,
        label = match.s:gsub("[\r\n]", " "),
        right_text = tostring(match.lx),
        fields = { path = file.p, line = match.lx, col = match.cx },
      }
      M.match_at = M.match_at + 1
    else
      M.file_at, M.match_at = M.file_at + 1, 0
    end
  end
  local done = M.file_at > #M.found.items
  M.pending.extract_ns = M.pending.extract_ns + vim.uv.hrtime() - started
  M.pending.nodes = M.pending.nodes + #records
  M.pending.pages = M.pending.pages + 1
  if done then
    M.found = nil
  end
  return { records = records, done = done }
end

---@param request                       table
---@return table|stl.c.Future
local function query_page(request)
  if M.mode == "searcher" then
    if M.found then
      return search_page()
    end
    M.pending.io_started = vim.uv.hrtime()
    local job = yoz.search.start_search_in_files({
      cwd = M.root .. "/rust/yoz/src/ux/treeview",
      search_pattern = "fn ",
      search_paths = ".",
      include_patterns = "*.rs",
      exclude_patterns = "",
      flag_case_sensitive = true,
      flag_gitignore = false,
      flag_regex = false,
    })
    return read_job(job, request):map(function(found)
      M.found, M.file_at, M.match_at = found, 1, 0
      return search_page()
    end)
  elseif M.mode == "git" then
    M.pending.io_started = vim.uv.hrtime()
    return read_job(yoz.git.start_status({ cwd = M.root, include_numstat = true, include_untracked = false }), request):map(
      function(snapshot)
        local started = vim.uv.hrtime()
        local exported = snapshot:export()
        local records = {
          { key = "staged", label = "Staged", can_expand = true },
          { key = "unstaged", label = "Unstaged", can_expand = true },
        }
        local paths = vim.tbl_keys(exported.status_map)
        table.sort(paths)
        for _, path in ipairs(paths) do
          local entry = exported.status_map[path]
          for _, stage in ipairs({ "staged", "unstaged" }) do
            if entry[stage .. "_bits"] ~= 0 then
              local stat = exported.numstats[stage][path]
              records[#records + 1] = {
                key = stage .. ":" .. path,
                parent = stage,
                label = entry.relative,
                right_text = stat and ("+" .. stat.insertions .. " -" .. stat.deletions) or entry.display,
                fields = { path = path, stage = stage },
              }
            end
          end
        end
        M.pending.nodes, M.pending.pages = #records, 1
        M.pending.extract_ns = vim.uv.hrtime() - started
        return { records = records, done = true }
      end
    )
  end
  M.pending.io_started = vim.uv.hrtime()
  return stl.c.Future.new(function(resolve, reject)
    local sent = M.client:request(
      "textDocument/documentSymbol",
      { textDocument = { uri = M.uri } },
      function(err, symbols)
        if err then
          reject(err)
          return
        end
        M.pending.io_ready = vim.uv.hrtime()
        M.pending.raw_heap_kib = collectgarbage("count")
        local started = vim.uv.hrtime()
        local records, stack = {}, {}
        for index = #symbols, 1, -1 do
          stack[#stack + 1] = { symbol = symbols[index] }
        end
        while #stack > 0 do
          local item = table.remove(stack)
          local symbol = item.symbol
          local range = symbol.selectionRange or symbol.range
          local key = (item.parent or "")
            .. "/"
            .. symbol.name
            .. ":"
            .. range.start.line
            .. ":"
            .. range.start.character
          records[#records + 1] = {
            key = key,
            parent = item.parent,
            label = symbol.name,
            can_expand = symbol.children and #symbol.children > 0 or false,
            right_text = tostring(range.start.line + 1),
            fields = { uri = M.uri, range = range, kind = symbol.kind },
          }
          for index = #(symbol.children or {}), 1, -1 do
            stack[#stack + 1] = { symbol = symbol.children[index], parent = key }
          end
        end
        M.pending.nodes, M.pending.pages = #records, 1
        M.pending.extract_ns = vim.uv.hrtime() - started
        resolve({ records = records, done = true })
      end,
      M.document_bufnr
    )
    assert(sent, "LSP request rejected")
  end)
end

---@param root                          string
---@param mode                          string
---@return nil
function M.setup(root, mode)
  M.root, M.mode, M.errors = root, mode, {}
  M.initial_buffers = #vim.api.nvim_list_bufs()
  vim.opt.runtimepath:prepend(root)
  yoz = assert(package.loadlib(root .. "/lua/yoz.so", "luaopen_yoz"))()
  stl = {
    c = { Future = require("stl.c.future") },
    nvim = { fn = require("stl.nvim.fn") },
    reporter = {
      error = function(options)
        M.errors[#M.errors + 1] = options.message
      end,
    },
  }
  local treeview = require("ux.treeview")
  if mode == "filetree" or mode == "lsp" then
    M.directory = assert(vim.uv.fs_mkdtemp(vim.uv.os_tmpdir() .. "/treeview-consumer-XXXXXX"))
  end
  if mode == "filetree" then
    for index = 1, 128 do
      write(M.directory .. "/file-" .. index .. ".lua", "return " .. index .. "\n")
    end
  elseif mode == "lsp" then
    local file = assert(io.open(root .. "/lua/ux/treeview/view.lua", "rb"))
    local document = file:read("*a")
    file:close()
    write(M.directory .. "/document.lua", document)
    M.document_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.document_bufnr, M.directory .. "/document.lua")
    vim.api.nvim_buf_set_lines(M.document_bufnr, 0, -1, false, vim.split(document, "\n", { plain = true }))
    vim.api.nvim_set_option_value("filetype", "lua", { buf = M.document_bufnr })
    M.uri = vim.uri_from_bufnr(M.document_bufnr)
    local client_id = assert(vim.lsp.start({
      name = "treeview-benchmark-luals",
      cmd = {
        vim.env.HOME .. "/.local/share/nvim/mason/bin/lua-language-server",
        "--logpath=" .. M.directory .. "/logs",
        "--metapath=" .. M.directory .. "/meta",
      },
      root_dir = M.directory,
      settings = { Lua = { workspace = { checkThirdParty = false }, diagnostics = { enable = false } } },
    }, { bufnr = M.document_bufnr }))
    M.client = assert(vim.lsp.get_client_by_id(client_id))
    assert(
      vim.wait(30000, function()
        return M.client.initialized
      end, 10),
      "LSP did not initialize"
    )
  end
  M.data = treeview.new_data()
  await(M.data:import({ { key = "root", label = mode, can_expand = true } }))
  local root_id = M.data:source():id("root")
  M.scope = { kind = "descendants", node = root_id }
  if mode == "filetree" then
    await(M.data:import(listing(), M.scope))
  end
  M.state =
    await(M.data:create_state({ kind = "children_of", node = root_id }, { mode = mode == "lsp" and "list" or "tree" }))
  await(M.state:set_expanded({ root_id }, true, true))
  M.view = treeview.attach(M.state, { keymaps = false })
  assert(vim.wait(30000, function()
    return M.view:frame() ~= nil
  end, 1))
  M.pinned = M.view:frame()
  if mode ~= "filetree" then
    M.provider = await(M.data:create_provider(M.scope))
    M.query = await(M.provider:create_query(query_page))
  else
    M.watcher = assert(vim.uv.new_fs_event())
    assert(M.watcher:start(
      M.directory,
      {},
      vim.schedule_wrap(function(err)
        if err then
          M.errors[#M.errors + 1] = err
          return
        end
        if not M.waiting_watch then
          return
        end
        M.waiting_watch = false
        local p = M.pending
        p.io_started = vim.uv.hrtime()
        local records = listing()
        p.io_ready = vim.uv.hrtime()
        p.nodes, p.pages = #records, 1
        M.data:import(records, M.scope):finally(function(ok, result)
          assert(ok and result.kind ~= "Rejected", vim.inspect(result))
          p.expected = result.revisions.commit
        end)
      end)
    ))
  end
  local native = M.view._native
  M.view._native = setmetatable({}, {
    __index = function(_, key)
      if key ~= "plan" then
        return function(_, ...)
          return native[key](native, ...)
        end
      end
      return function(_, ...)
        if M.pending then
          M.pending.plan_requested = vim.uv.hrtime()
        end
        local ticket = native:plan(...)
        return {
          poll = function()
            local done, value = ticket:poll()
            if done and M.pending then
              M.pending.plan_ready = vim.uv.hrtime()
            end
            return done, value
          end,
        }
      end
    end,
  })
  local set_lines = vim.api.nvim_buf_set_lines
  vim.api.nvim_buf_set_lines = function(...)
    local started = vim.uv.hrtime()
    if M.pending then
      M.pending.staging_done = started
      M.pending.stage_heap_kib = math.max(M.pending.stage_heap_kib or 0, collectgarbage("count"))
    end
    set_lines(...)
    if M.pending then
      M.pending.buffer_ns = M.pending.buffer_ns + vim.uv.hrtime() - started
    end
  end
  local redraw = vim.api.nvim__redraw
  vim.api.nvim__redraw = function(options)
    local p, frame = M.pending, M.view and M.view:frame()
    if p and frame:id() ~= p.base then
      local applicable, complete
      if M.query then
        local origin = frame:source():query_result(M.scope)
        applicable = p.accepted and origin and origin.generation == M.query:info().generation
        complete = applicable and origin.completeness == "complete"
      else
        applicable = p.expected and M.state._native:applicable(frame, p.expected)
        complete = applicable
      end
      if applicable then
        local now = vim.uv.hrtime()
        p.first = p.first or now
        if complete then
          p.published = now
        end
        p.stage_heap_kib = math.max(p.stage_heap_kib or 0, collectgarbage("count"))
      end
    end
    return redraw(options)
  end
end

---@param iteration                     integer
---@return nil
function M.start(iteration)
  M.pending = {
    started = vim.uv.hrtime(),
    base = M.view:frame():id(),
    nodes = 0,
    pages = 0,
    native_poll_ns = 0,
    extract_ns = 0,
    buffer_ns = 0,
  }
  if M.mode == "filetree" then
    M.waiting_watch = true
    if iteration % 2 == 1 then
      write(M.directory .. "/changed.lua", "return true\n")
    else
      assert(vim.uv.fs_unlink(M.directory .. "/changed.lua"))
    end
  else
    M.query:start({ pattern = M.mode == "searcher" and "fn " or tostring(iteration) }):finally(function(ok, result)
      assert(ok and result.kind ~= "Rejected", vim.inspect(result))
      M.pending.accepted = true
    end)
  end
end

---@return table
function M.poll()
  assert(#M.errors == 0, table.concat(M.errors, "\n"))
  local p = M.pending
  if p.published then
    assert(M.view:frame():header().row_count == p.nodes, "source rows were lost")
    assert(M.data._native:queue_depth() == 0, "owner queue did not drain")
    assert(#vim.api.nvim_buf_get_extmarks(M.view.bufnr, -1, 0, -1, {}) == 0, "persistent per-row decorations")
    p.buffer_bytes = vim.api.nvim_buf_get_offset(M.view.bufnr, vim.api.nvim_buf_line_count(M.view.bufnr))
  end
  return p
end

---@return table
function M.finish()
  local started = vim.uv.hrtime()
  local buffers = #vim.api.nvim_list_bufs()
  M.released = setmetatable({ M.data, M.state, M.view, M.query, M.provider }, { __mode = "v" })
  M.pending, M.pinned, M.found = nil, nil, nil
  M.view:detach()
  M.query, M.provider, M.state, M.data, M.view = nil, nil, nil, nil, nil
  if M.watcher then
    M.watcher:stop()
    M.watcher:close()
  end
  if M.client then
    M.client:stop()
    assert(vim.wait(5000, function()
      return M.client:is_stopped()
    end, 10))
    vim.api.nvim_buf_delete(M.document_bufnr, { force = true })
  end
  assert(#vim.api.nvim_list_bufs() == M.initial_buffers, "consumer buffers remained after close")
  return {
    buffers_before_close = buffers,
    buffers_after_close = #vim.api.nvim_list_bufs(),
    release_ms = (vim.uv.hrtime() - started) / 1e6,
    directory = M.directory,
  }
end

---@return table
function M.collect()
  -- Called by a separate RPC after finish's stack and temporary references have gone.
  local started = vim.uv.hrtime()
  assert(
    vim.wait(3000, function()
      collectgarbage("collect")
      return next(M.released) == nil
    end, 5),
    "Treeview handles remained reachable after close"
  )
  return { lua_heap_kib = collectgarbage("count"), gc_ms = (vim.uv.hrtime() - started) / 1e6 }
end

return M
