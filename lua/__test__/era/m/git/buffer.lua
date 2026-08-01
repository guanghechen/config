---@diagnostic disable: undefined-global
--- Test for era.m.git.buffer module
--- Run with: nvim -l lua/__test__/era/m/git/buffer.lua

local Future = require("stl.c.future")
local harness = require("__test__.harness")

local t = harness.new("era.m.git.buffer")

---@param callback fun(...)
---@return table
local function callable(callback)
  return setmetatable({
    dispose = function() end,
  }, {
    __call = function(_, ...)
      return callback(...)
    end,
  })
end

---@param initial_visible table<integer, boolean>
---@param get_file_info fun(bufnr: integer): stl.c.Future|nil
---@return era.m.git.buffer, table<string, fun(event: { buf: integer })>, fun(): nil, fun(bufnr: integer, visible: boolean), fun(bufnr: integer, valid: boolean), table<integer, integer>
local function setup(initial_visible, get_file_info)
  local callbacks = {} ---@type table<string, fun(event: { buf: integer })>
  local file_info_calls = {} ---@type table<integer, integer>
  local pending_debounce = nil ---@type fun()|nil
  local valid = {} ---@type table<integer, boolean>
  local visible = vim.deepcopy(initial_visible) ---@type table<integer, boolean>
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

  t:patch_global("stl", {
    c = {
      Future = Future,
      Ticker = {
        new = function()
          return { tick = function() end }
        end,
      },
    },
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
        return callable(function()
          pending_debounce = callback
        end)
      end,
      throttle = function(callback)
        return callable(callback)
      end,
    },
  })
  t:patch_global("dot", {
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
  })
  t:patch_global("yoz", {
    path = {
      is_exist = function()
        return true
      end,
    },
  })
  t:patch_global("era", {
    m = {
      git = {
        repo = {
          create = function()
            return Future.resolve(repo)
          end,
        },
        state = { o_branch = { next = function() end } },
        watcher = { update = function() end },
      },
    },
  })

  t:patch_table(vim.api, "nvim_buf_attach", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_get_name", function(bufnr)
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
      callbacks[event] = opts.callback
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

  local Buffer = assert(loadfile("lua/era/m/git/buffer.lua"))()
  Buffer.setup()

  return Buffer,
    callbacks,
    function()
      local callback = pending_debounce
      pending_debounce = nil
      if callback then
        callback()
      end
    end,
    function(bufnr, value)
      visible[bufnr] = value
    end,
    function(bufnr, value)
      valid[bufnr] = value
    end,
    file_info_calls
end

t:test("setup initializes visible buffers immediately", function()
  local Buffer, _, _, _, _, calls = setup({ [11] = true })

  t.assert_true(Buffer.is_attached(11), "visible buffer attached")
  t.assert_eq(1, calls[11], "visible file info query")
  t.assert_false(Buffer.is_dirty(11), "visible initialization in flight")
end)

t:test("setup defers hidden buffers and refreshes every buffer that becomes visible", function()
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

---@return era.m.git.buffer
---@return table<integer, table>
---@return era.m.git.diff
---@return era.m.git.staging|nil
local function setup_reset_runtime()
  local diff = require("era.m.git.diff")
  local hunk = require("era.m.git.hunk")
  local has_staging, staging = pcall(require, "era.m.git.staging") ---@type boolean, era.m.git.staging|nil
  t:patch_global("stl", { c = { Future = Future, Ticker = {
    new = function()
      return {}
    end,
  } } })
  t:patch_global("era", { m = { git = { diff = diff, hunk = hunk, staging = has_staging and staging or nil } } })

  local Buffer = assert(loadfile("lua/era/m/git/buffer.lua"))()
  local cache ---@type table<integer, table>
  for index = 1, 50 do
    local name, value = debug.getupvalue(Buffer.reset_hunk, index)
    if name == "cache" then
      cache = value
      break
    end
  end
  t.assert_true(cache ~= nil, "cache upvalue")
  return Buffer, cache, diff, staging
end

---@param cache                         table<integer, table>
---@param diff                          era.m.git.diff
---@param staging                       era.m.git.staging|nil
---@param head                          string[]
---@param edited                        string[]
---@return integer
local function seed_reset_buffer(cache, diff, staging, head, edited)
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.list_slice(edited, 1, #edited - 1))
  cache[bufnr] = {
    compare_text = head,
    hunks = diff.run_diff(head, edited),
    index_document = staging and staging.from_text(table.concat(head, "\n")) or nil,
    untracked = false,
  }
  return bufnr
end

t:test("reset_hunk restores pure deletions at their anchors", function()
  local Buffer, cache, diff, staging = setup_reset_runtime()
  local cases = {
    { { "a", "b", "c", "d", "" }, { "a", "c", "d", "" }, "a|b|c|d" },
    { { "a", "b", "c", "" }, { "b", "c", "" }, "a|b|c" },
  }

  for _, case in ipairs(cases) do
    local bufnr = seed_reset_buffer(cache, diff, staging, case[1], case[2])
    t.assert_true(Buffer.reset_hunk(bufnr, { 1, 1 }), "reset")
    t.assert_eq(case[3], table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "|"), "buffer order")
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end)

t:test("working-buffer unstage refuses unsafe coordinate projection", function()
  local Buffer = setup_reset_runtime()
  local outcome = nil ---@type table|nil
  Buffer.unstage_hunk(0):finally(function(_, result)
    outcome = result
  end)

  t.assert_true(outcome ~= nil, "settled")
  t.assert_false(outcome.ok, "refused")
end)

t:test("reset_hunk preserves unchanged gaps between nearby hunks", function()
  local Buffer, cache, diff, staging = setup_reset_runtime()
  local head = { "local M = {}", "function M.hello()", '  return "hi"', "end", "return M", "" } ---@type string[]
  local edited = {
    "local M = {}",
    "function M.hello()",
    '  return "changed"',
    "end",
    "function M.extra() end",
    "return M",
    "",
  } ---@type string[]
  local bufnr = seed_reset_buffer(cache, diff, staging, head, edited)

  t.assert_true(Buffer.reset_hunk(bufnr, { 3, 5 }), "reset")
  t.assert_eq(
    table.concat(head, "|", 1, #head - 1),
    table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "|"),
    "HEAD round-trip"
  )
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
