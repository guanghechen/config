---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.plugin.blink-cmp.path")

bootstrap.with_stl(t, {
  reporter = {
    warn = function() end,
  },
})
bootstrap.with_dot(t, {
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
  },
})
bootstrap.with_yoz(t, {
  path = {
    is_exist_directory = function()
      return true
    end,
  },
})

local Path = require("era.plugin.blink-cmp.path")

local function make_source(opts)
  local source = Path.new(opts)
  source.get_dirname = function()
    return "/repo"
  end
  source.get_text_edit_ranges = function()
    return { file = {}, directory = {} }
  end
  return source
end

---@param line ?string
---@param start_col ?integer
local function make_context(line, start_col)
  line = line or "@"
  return {
    id = 1,
    bufnr = 1,
    cursor = { 1, #line },
    line = line,
    bounds = { start_col = start_col or 1, length = 0 },
  }
end

t:test("scan request returns a cancellation function", function()
  local source = make_source({ debounce = false })
  local scan_callback
  local scan_cleanup_count = 0
  source.scan_directory_async = function(_, _, _, _, callback)
    scan_callback = callback
    return function()
      scan_cleanup_count = scan_cleanup_count + 1
    end
  end

  local completion_count = 0
  local cancel = source:get_completions(make_context(), function()
    completion_count = completion_count + 1
  end)

  t.assert_eq("function", type(cancel), "cancellation handle")
  cancel()
  t.assert_eq(1, scan_cleanup_count, "scan cleanup")
  t.assert_eq(0, source.context.active_scans, "active scan count")

  scan_callback({ { name = "late.lua", type = "file" } }, nil)
  vim.wait(20)
  t.assert_eq(0, completion_count, "late callback")

  cancel()
  t.assert_eq(1, scan_cleanup_count, "idempotent cleanup")
end)

t:test("same cursor with different text starts a fresh scan", function()
  local source = make_source({ debounce = false })
  local scan_count = 0
  local completion_count = 0
  source.scan_directory_async = function(_, _, _, _, callback)
    scan_count = scan_count + 1
    callback({}, nil)
    return function() end
  end

  source:get_completions(make_context("@lua/a"), function()
    completion_count = completion_count + 1
  end)
  t.wait_until(function()
    return completion_count == 1
  end, 1000, "first completion")

  local cancel = source:get_completions(make_context("@lua/e"), function() end)
  t.assert_eq("function", type(cancel), "fresh request cancellation handle")
  t.assert_eq(2, scan_count, "fresh scan")
  cancel()
end)

t:test("completion list follows Blink query cache boundaries", function()
  local blink_root = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "blink.cmp")
  t.assert_true(vim.uv.fs_stat(blink_root) ~= nil, "blink.cmp installation")
  vim.opt.runtimepath:prepend(blink_root)
  local ProviderList = require("blink.cmp.sources.lib.provider.list")

  local source = make_source({ debounce = false })
  source.scan_directory_async = function(_, _, _, _, callback)
    callback({ { name = "plugin", type = "directory" } }, nil)
    return function() end
  end

  local function get_list(context)
    local response
    source:get_completions(context, function(result)
      response = result
    end)
    t.wait_until(function()
      return response ~= nil
    end, 1000, "completion response")

    return setmetatable({
      context = context,
      is_incomplete_forward = response.is_incomplete_forward,
      is_incomplete_backward = response.is_incomplete_backward,
    }, { __index = ProviderList })
  end

  local boundary_list = get_list(make_context("@lua/era/", 10))
  t.assert_eq(false, boundary_list:is_valid_for_context(make_context("@lua/era/p", 10)), "path boundary cache")
  t.assert_eq(false, boundary_list:is_valid_for_context(make_context("@lua/e", 6)), "changed directory cache")

  local basename_list = get_list(make_context("@lua/era/p", 10))
  t.assert_eq(true, basename_list:is_valid_for_context(make_context("@lua/era/pl", 10)), "forward basename cache")
  t.assert_eq(false, basename_list:is_valid_for_context(make_context("@lua/era/", 10)), "backward basename cache")
  t.assert_eq(false, basename_list:is_valid_for_context(make_context("@lua/e", 6)), "non-overlapping basename cache")
end)

t:test("cancelled scan can retry the same context", function()
  local source = make_source({ debounce = false })
  local scan_count = 0
  source.scan_directory_async = function()
    scan_count = scan_count + 1
    return function() end
  end

  local context = make_context()
  source:get_completions(context, function() end)()
  local cancel_retry = source:get_completions(context, function() end)

  t.assert_eq("function", type(cancel_retry), "retry cancellation handle")
  t.assert_eq(2, scan_count, "same-context retry")
  cancel_retry()
end)

t:test("cancelling a debounced request prevents its scan", function()
  local source = make_source({ debounce = 1000 })
  local scan_count = 0
  source.scan_directory_async = function()
    scan_count = scan_count + 1
    return function() end
  end

  local cancel = source:get_completions(make_context(), function() end)
  t.assert_eq("function", type(cancel), "debounce cancellation handle")
  cancel()

  vim.wait(20)
  t.assert_eq(0, scan_count, "cancelled debounce scan")
end)

t:run()
