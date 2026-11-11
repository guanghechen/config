local Future = require("stl.c.future")
local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")

local t = harness.new()

---@param initial_visible table<integer, boolean>
---@param get_file_info (fun(bufnr: integer): stl.c.Future|nil)|nil
---@param get_buf_name (fun(bufnr: integer): string)|nil
---@param create_repo (fun(repo: table): stl.c.Future)|nil
---@return era.m.git.buffer, table<string, fun(event: { buf: integer })>, fun(): nil, fun(bufnr: integer, visible: boolean), fun(bufnr: integer, valid: boolean), table<integer, integer>, { count: integer, opts: vim.api.keyset.buf_attach|nil }, table<string, string|string[]|nil>
local function setup(initial_visible, get_file_info, get_buf_name, create_repo)
  local callbacks = {} ---@type table<string, fun(event: { buf: integer })>
  local patterns = {} ---@type table<string, string|string[]|nil>
  local file_info_calls = {} ---@type table<integer, integer>
  local pending_debounce = nil ---@type fun()|nil
  local valid = {} ---@type table<integer, boolean>
  local visible = vim.deepcopy(initial_visible) ---@type table<integer, boolean>
  local listener_calls = { count = 0 } ---@type { count: integer, opts: vim.api.keyset.buf_attach|nil }
  local bufnrs = vim.tbl_keys(initial_visible) ---@type integer[]
  table.sort(bufnrs)

  for _, bufnr in ipairs(bufnrs) do
    valid[bufnr] = true
  end

  local repo = {
    abbrev_head = "main",
    commondir = nil,
    gitdir = "/repo/.git",
    toplevel = "/repo",
    get_relpath = function(_, filepath)
      return filepath:match("[^/]+$")
    end,
  }

  local Buffer = git_buffer.load(t, {
    stl = {
      git = {
        info = {
          get_file_info = function(_, relpath)
            local bufnr = assert(tonumber(relpath:match("(%d+)")))
            file_info_calls[bufnr] = (file_info_calls[bufnr] or 0) + 1
            if get_file_info then
              local future = get_file_info(bufnr)
              if future then
                return future
              end
            end
            return Future.new()
          end,
        },
      },
      reporter = { warn = function() end },
      timer = {
        debounce = function(callback)
          return git_buffer.callable(function()
            pending_debounce = callback
          end)
        end,
        throttle = git_buffer.callable,
      },
    },
    dot = {
      path = {
        is_git_repo = function()
          return true
        end,
        normalize = function(filepath)
          return filepath
        end,
        workspace = function()
          return "/repo"
        end,
      },
    },
    yoz = {
      path = {
        is_descendant = function(from, to)
          return to == from or vim.startswith(to, from .. "/")
        end,
      },
    },
    era = {
      m = {
        git = {
          hunk = { remove = function() end },
          repo = {
            create = function()
              return create_repo and create_repo(repo) or Future.resolve(repo)
            end,
          },
          sign = {
            clear = function() end,
            contains_range = function()
              return true
            end,
            on_lines = function() end,
          },
          state = { o_branch = { next = function() end } },
          watcher = { update = function() end },
        },
      },
    },
  })

  t:patch_table(vim.api, "nvim_buf_attach", function(_, _, opts)
    listener_calls.count = listener_calls.count + 1
    listener_calls.opts = opts
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_get_name", function(bufnr)
    if get_buf_name then
      return get_buf_name(bufnr)
    end
    return string.format("/repo/file-%d.lua", bufnr)
  end)
  t:patch_table(vim.api, "nvim_buf_is_loaded", function(bufnr)
    return valid[bufnr] == true
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return valid[bufnr] == true
  end)
  t:patch_table(vim.api, "nvim_create_augroup", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    events = type(events) == "table" and events or { events }
    for _, event in ipairs(events) do
      callbacks[event], patterns[event] = opts.callback, opts.pattern
    end
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name)
    if name == "buftype" then
      return ""
    end
    error("unexpected option read: " .. name)
  end)
  t:patch_table(vim.api, "nvim_list_bufs", function()
    return bufnrs
  end)
  t:patch_table(vim.fn, "win_findbuf", function(bufnr)
    if valid[bufnr] and visible[bufnr] then
      return { 100 + bufnr }
    end
    return {}
  end)

  Buffer.setup()

  return Buffer,
    callbacks,
    function()
      local callback = pending_debounce
      pending_debounce = nil
      if callback then
        callback()
        ---@diagnostic disable-next-line: missing-return
      end
    end,
    ---@diagnostic disable-next-line: redundant-return-value
    function(bufnr, value)
      visible[bufnr] = value
    end,
    ---@diagnostic disable-next-line: redundant-return-value
    function(bufnr, value)
      valid[bufnr] = value
    end,
    ---@diagnostic disable-next-line: redundant-return-value
    file_info_calls,
    listener_calls,
    patterns
end

t:test("setup initializes visible buffers immediately", function()
  ---@diagnostic disable-next-line: missing-parameter
  local Buffer, _, _, _, _, calls = setup({ [11] = true })

  t.assert_true(Buffer.is_attached(11), "visible buffer attached")
  t.assert_eq(1, calls[11], "visible file info query")
  t.assert_false(Buffer.is_dirty(11), "visible initialization in flight")
end)

for _, case in ipairs({
  {
    name = "attach accepts a workspace file before it exists on disk",
    filepath = "/repo/new-file.lua",
    attached = true,
  },
  { name = "attach rejects files outside the repository", filepath = "/outside/file.lua", attached = false },
}) do
  t:test(case.name, function()
    local Buffer = setup({ [11] = true }, nil, function()
      return case.filepath
    end)

    t.assert_eq(case.attached, Buffer.is_attached(11), "attached " .. case.filepath)
  end)
end

-- A write or rename changes the buffer's file, which then joins or leaves the repository.
for _, case in ipairs({
  {
    name = "BufWritePost retries attach after a buffer becomes a repository file",
    event = "BufWritePost",
    from = "/outside/file.lua",
    to = "/repo/new-file.lua",
    attached = true,
  },
  {
    name = "BufFilePost detaches a buffer renamed outside the repository",
    event = "BufFilePost",
    from = "/repo/file.lua",
    to = "/outside/file.lua",
    attached = false,
  },
}) do
  t:test(case.name, function()
    local name = case.from ---@type string
    local Buffer, callbacks = setup({ [11] = true }, nil, function()
      return name
    end)
    t.assert_eq(not case.attached, Buffer.is_attached(11), "attached as " .. case.from)

    name = case.to
    callbacks[case.event]({ buf = 11 })

    t.assert_eq(case.attached, Buffer.is_attached(11), "attached as " .. case.to .. " after " .. case.event)
  end)
end

t:test("BufFilePost rebinds Git state without duplicating the buffer listener", function()
  local name = "/repo/old.lua" ---@type string
  local Buffer, callbacks, _, _, _, _, listener_calls = setup({ [11] = true }, nil, function()
    return name
  end)

  name = "/repo/new.lua"
  callbacks.BufFilePost({ buf = 11 })

  local current = assert(Buffer.get_cache(11))
  t.assert_eq("/repo/new.lua", current.file, "current filepath")
  t.assert_eq("new.lua", current.relpath, "current Git path")
  t.assert_eq(1, listener_calls.count, "one low-level listener")
end)

t:test("a line ending option change refreshes the buffer it changed in", function()
  local Buffer, callbacks, _, _, _, _, _, patterns = setup({ [11] = true })
  t.assert_same(
    { "fileformat", "bomb", "endofline", "fixendofline", "binary" },
    patterns.OptionSet,
    "full option names"
  )
  local current = assert(Buffer.get_cache(11))
  local updates = 0 ---@type integer
  current.force_next_update = false
  current.update_throttled = function()
    updates = updates + 1
  end
  t:patch_table(vim.api, "nvim_get_current_buf", function()
    return 11
  end)

  callbacks.OptionSet({ buf = 0 })
  t.assert_true(current.force_next_update, "the next update recomputes")
  t.assert_eq(1, updates, "updates")
end)

t:test("only edits that move sign marks force a sign repair", function()
  local Buffer, _, _, _, _, _, listener_calls = setup({ [11] = true })
  local current = assert(Buffer.get_cache(11))
  local on_lines = assert(assert(listener_calls.opts).on_lines)
  local checked ---@type integer[]|nil
  t:patch_table(era.m.git.sign, "contains_range", function(_, start_lnum, end_lnum)
    checked = { start_lnum, end_lnum }
    return true
  end)
  current.hunks = {}
  current.force_next_update = false

  on_lines("lines", 11, 0, 4, 5, 5)
  t.assert_false(current.force_next_update, "typing within a signed line")
  on_lines("lines", 11, 0, 4, 5, 6)
  t.assert_true(current.force_next_update, "a line added among signs")
  current.force_next_update = false
  -- Rewriting lines 15-20 at once keeps their count but moves their marks onto line 21.
  on_lines("lines", 11, 0, 14, 20, 20)
  t.assert_true(current.force_next_update, "a same-count rewrite of several signed lines")
  t.assert_same({ 15, 21 }, checked, "the line below a rewrite holds its moved marks")
end)

t:test("an async attach cannot publish after the buffer leaves the repository", function()
  local name = "/repo/old.lua" ---@type string
  local release = nil ---@type (fun(): nil)|nil
  local Buffer, callbacks = setup({ [11] = true }, nil, function()
    return name
  end, function(repo)
    return Future.new(function(resolve)
      release = function()
        resolve(repo)
      end
    end)
  end)
  t.assert_false(Buffer.is_attached(11), "attach is pending")

  name = "/outside/file.lua"
  callbacks.BufFilePost({ buf = 11 })
  assert(release)()

  t.assert_false(Buffer.is_attached(11), "stale attach discarded")
end)

t:test("setup defers hidden buffers and refreshes every buffer that becomes visible", function()
  ---@diagnostic disable-next-line: missing-parameter
  local Buffer, callbacks, flush, set_visible, _, calls = setup({ [11] = false, [12] = false })

  t.assert_true(Buffer.is_attached(11), "first hidden buffer attached")
  t.assert_true(Buffer.is_attached(12), "second hidden buffer attached")
  t.assert_true(Buffer.is_dirty(11), "first hidden buffer dirty")
  t.assert_true(Buffer.is_dirty(12), "second hidden buffer dirty")
  t.assert_nil(calls[11], "first hidden query")
  t.assert_nil(calls[12], "second hidden query")

  set_visible(11, true)
  set_visible(12, true)
  callbacks.BufWinEnter({ buf = 11 })
  callbacks.BufEnter({ buf = 11 })
  callbacks.BufWinEnter({ buf = 12 })
  flush()

  t.assert_eq(1, calls[11], "first visible query")
  t.assert_eq(1, calls[12], "second visible query")
  t.assert_false(Buffer.is_dirty(11), "first initialization in flight")
  t.assert_false(Buffer.is_dirty(12), "second initialization in flight")

  callbacks.BufEnter({ buf = 11 })
  flush()
  t.assert_eq(1, calls[11], "in-flight initialization is not duplicated")
end)

t:test("deferred refresh ignores buffers invalidated before becoming visible", function()
  ---@diagnostic disable-next-line: missing-parameter
  local Buffer, callbacks, flush, set_visible, set_valid, calls = setup({ [11] = false })

  set_visible(11, true)
  set_valid(11, false)
  callbacks.BufWinEnter({ buf = 11 })
  flush()

  t.assert_true(Buffer.is_dirty(11), "invalid buffer remains pending until detach")
  t.assert_nil(calls[11], "invalid buffer query")
end)

t:test("failed initialization remains dirty for a later visibility event", function()
  local Buffer, callbacks, flush, _, _, calls = setup({ [11] = true }, function()
    return Future.reject("query failed")
  end)

  t.assert_eq(1, calls[11], "initial query")
  t.assert_true(Buffer.is_dirty(11), "failed initialization dirty")

  callbacks.BufEnter({ buf = 11 })
  flush()
  t.assert_eq(2, calls[11], "visibility retry")
  t.assert_true(Buffer.is_dirty(11), "failed retry dirty")
end)

t:run()
