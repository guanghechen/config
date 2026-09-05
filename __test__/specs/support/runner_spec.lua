--- Run with: nvim -l __test__/run.lua __test__/specs/support/runner_spec.lua

local harness = require("__test__.support.harness")
local runner = require("__test__.support.runner")
local t = harness.new("__test__.support.runner")
local root = assert(vim.uv.cwd()) ---@type string

---@param callback                      fun(dir: string): nil
---@return nil
local function with_temp_root(callback)
  local dir = vim.fn.tempname() .. " suite space 中文" ---@type string
  vim.fn.mkdir(dir .. "/nested", "p")
  t:defer(function()
    vim.fn.delete(dir, "rf")
  end)
  callback(dir)
end

---@param lines                         string[]
---@param filepath                      string
---@return nil
local function write_file(lines, filepath)
  t.assert_eq(0, vim.fn.writefile(lines, filepath), "write fixture")
end

---@param body                          string
---@param filepath                      string
---@return nil
local function write_spec(body, filepath)
  local lines = {
    'local harness = require("__test__.support.harness")',
    'local t = harness.new("fixture")',
    't:test("case", function()',
  }
  vim.list_extend(lines, vim.split(body, "\n", { plain = true }))
  vim.list_extend(lines, { "end)", "t:run()" })
  write_file(lines, filepath)
end

---@param callback                      fun(): any
---@param fragment                      string
---@return nil
local function assert_error(callback, fragment)
  local ok, err = pcall(callback)
  t.assert_false(ok, "must fail")
  t.assert_true(tostring(err):find(fragment, 1, true) ~= nil, tostring(err))
end

---@param opts                          __test__.support.runner.IOptions
---@return integer, string
local function run_suites(opts)
  local output = {} ---@type string[]
  local restore = t:patch_table(io, "write", function(...)
    for _, value in ipairs({ ... }) do
      output[#output + 1] = tostring(value)
    end
  end)
  local ok, failed = pcall(runner.run_all, opts)
  restore()
  if not ok then
    error(failed, 0)
  end
  return failed, table.concat(output)
end

---@param args                          string[]
---@param cwd                           ?string
---@param entry                         ?string
---@return vim.SystemCompleted
local function cli(args, cwd, entry)
  local command =
    { vim.v.progpath, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", entry or (root .. "/__test__/run.lua") }
  vim.list_extend(command, args)
  return vim.system(command, { cwd = cwd or root, text = true, timeout = 5000 }):wait()
end

t:test("requiring the runner only exposes its API", function()
  t.assert_eq("function", type(runner.discover), "discover")
  t.assert_eq("function", type(runner.run_all), "run_all")
  t.assert_eq("function", type(runner.main), "main")
end)

t:test("default discovery includes framework specs and only spec files", function()
  local suites = runner.discover()
  t.assert_true(#suites > 0, "discovered suites")
  t.assert_true(vim.list_contains(suites, root .. "/__test__/specs/support/runner_spec.lua"), "runner self-test")
  for index, suite in ipairs(suites) do
    t.assert_true(suite:find(root .. "/__test__/specs/", 1, true) == 1, "spec directory")
    t.assert_true(suite:match("_spec%.lua$") ~= nil, "spec suffix")
    if index > 1 then
      t.assert_true(suites[index - 1] < suite, "deterministic order")
    end
  end
end)

t:test("discovery ignores support and fixture files without a name blacklist", function()
  with_temp_root(function(dir)
    write_file({}, dir .. "/harness.lua")
    write_file({}, dir .. "/nested/helper.lua")
    write_file({}, dir .. "/nested/fixture_spec.lua.txt")
    write_file({}, dir .. "/runner_spec.lua")
    write_file({}, dir .. "/nested/harness_spec.lua")
    local suites = runner.discover(dir)
    t.assert_eq(2, #suites, "spec count")
    t.assert_eq(dir .. "/nested/harness_spec.lua", suites[1], "nested spec")
    t.assert_eq(dir .. "/runner_spec.lua", suites[2], "top-level spec")
  end)
end)

t:test("filters use literal paths", function()
  with_temp_root(function(dir)
    write_file({}, dir .. "/alpha[1]_spec.lua")
    write_file({}, dir .. "/alpha1_spec.lua")
    local suites = runner.discover(dir, "alpha[1]")
    t.assert_eq(1, #suites, "filtered count")
    t.assert_eq(dir .. "/alpha[1]_spec.lua", suites[1], "literal filter")
  end)
end)

t:test("missing directories and empty selections fail", function()
  with_temp_root(function(dir)
    assert_error(function()
      runner.discover(dir .. "/missing")
    end, "test directory does not exist")
    assert_error(function()
      runner.run_all({ root = dir })
    end, "no test suites matched")
    write_spec("", dir .. "/pass_spec.lua")
    assert_error(function()
      runner.run_all({ root = dir, filter = "missing" })
    end, "no test suites matched: missing")
  end)
end)

t:test("list mode discovers without launching a suite", function()
  with_temp_root(function(dir)
    write_spec("error('must not execute')", dir .. "/listed_spec.lua")
    t:patch_table(vim, "system", function()
      error("must not spawn")
    end)
    local failed, output = run_suites({ root = dir, list = true })
    t.assert_eq(0, failed, "listing result")
    t.assert_true(output:find("listed_spec.lua", 1, true) ~= nil, "listed path")
  end)
end)

t:test("an unreadable nested directory fails discovery before any suite starts", function()
  with_temp_root(function(dir)
    write_spec("", dir .. "/pass_spec.lua")
    write_spec("error('must not be omitted')", dir .. "/nested/blocked_spec.lua")
    local scan = vim.uv.fs_scandir
    t:patch_table(vim.uv, "fs_scandir", function(path)
      if path == dir .. "/nested" then
        return nil, "EACCES: permission denied"
      end
      return scan(path)
    end)
    local launches = 0 ---@type integer
    t:patch_table(vim, "system", function()
      launches = launches + 1
      error("must not launch a partial selection")
    end)
    assert_error(function()
      runner.run_all({ root = dir })
    end, "cannot read test directory " .. dir .. "/nested: EACCES")
    t.assert_eq(0, launches, "no partial run")
  end)
end)

t:test("discovery resolves missing directory entry types", function()
  with_temp_root(function(dir)
    write_file({}, dir .. "/first_spec.lua")
    write_file({}, dir .. "/nested/second_spec.lua")
    local next_entry = vim.uv.fs_scandir_next
    t:patch_table(vim.uv, "fs_scandir_next", function(scanner)
      local name = next_entry(scanner)
      return name
    end)
    local suites = runner.discover(dir)
    t.assert_eq(2, #suites, "specs with unknown entry types")
    t.assert_eq(dir .. "/first_spec.lua", suites[1], "file entry")
    t.assert_eq(dir .. "/nested/second_spec.lua", suites[2], "directory entry")
  end)
end)

t:test("suite subprocesses isolate globals and handle paths with spaces", function()
  with_temp_root(function(dir)
    write_spec("vim.g.runner_probe = true", dir .. "/first_spec.lua")
    write_spec("assert(vim.g.runner_probe == nil)", dir .. "/nested/second_spec.lua")
    local failed = run_suites({ root = dir })
    t.assert_eq(0, failed, "isolated suites")
  end)
end)

t:test("case failures, load errors, empty files, and missing run calls fail independently", function()
  with_temp_root(function(dir)
    write_spec("error('expected failure')", dir .. "/case_spec.lua")
    write_file({ "this is not Lua" }, dir .. "/load_spec.lua")
    write_file({}, dir .. "/empty_spec.lua")
    write_file({ 'require("__test__.support.harness").new("empty"):run()' }, dir .. "/no_cases_spec.lua")
    write_file({ 'require("__test__.support.harness").new("missing run")' }, dir .. "/no_run_spec.lua")
    write_spec("", dir .. "/pass_spec.lua")
    local failed, output = run_suites({ root = dir })
    t.assert_eq(5, failed, "failed suite count")
    t.assert_true(output:find("6 suite(s), 5 failed", 1, true) ~= nil, "aggregate summary")
    t.assert_true(output:find("expected failure", 1, true) ~= nil, "failure details")
  end)
end)

t:test("timeout terminates a suite and allows the following suite to run", function()
  with_temp_root(function(dir)
    write_spec("vim.wait(10000)", dir .. "/hang_spec.lua")
    write_spec("", dir .. "/pass_spec.lua")
    local failed, output = run_suites({ root = dir, timeout_ms = 250 })
    t.assert_eq(1, failed, "timed out suite")
    t.assert_true(output:find("timeout after 250 ms", 1, true) ~= nil, "timeout diagnostic")
    t.assert_true(output:find("2 suite(s), 1 failed", 1, true) ~= nil, "following suite ran")
  end)
end)

t:test("spawn errors fail the run", function()
  with_temp_root(function(dir)
    write_spec("", dir .. "/pass_spec.lua")
    t:patch_table(vim, "system", function()
      error("injected spawn failure")
    end)
    local failed, output = run_suites({ root = dir })
    t.assert_eq(1, failed, "failed launch")
    t.assert_true(output:find("injected spawn failure", 1, true) ~= nil, "spawn diagnostic")
  end)
end)

t:test("entry prepares the checkout from another CWD without loading user config", function()
  with_temp_root(function(dir)
    local suite = dir .. "/startup_spec.lua"
    write_spec(
      table.concat({
        "assert(vim.uv.cwd() == " .. string.format("%q", root) .. ")",
        'assert(package.loaded["ark.bootstrap"] == nil)',
        'assert(loadfile("lua/era/dressing/indentline/parser.lua"))',
        "assert(vim.opt.runtimepath:get()[1] == " .. string.format("%q", root) .. ")",
      }, "\n"),
      suite
    )
    local result = cli({ "--suite", suite }, dir)
    t.assert_eq(0, result.code, (result.stdout or "") .. (result.stderr or ""))
  end)
end)

t:test("CLI reports invalid options and unmatched selectors with nonzero status", function()
  for _, args in ipairs({
    { "--unknown" },
    { "--timeout" },
    { "--timeout", "0" },
    { "--timeout", "1.5" },
    { "first", "second" },
    { "__no_matching_suite__" },
  }) do
    local result = cli(args)
    t.assert_eq(1, result.code, table.concat(args, " "))
    t.assert_true((result.stderr or "") ~= "", "actionable diagnostic")
  end
  local help = cli({ "--help" })
  t.assert_eq(0, help.code, "help exit")
  t.assert_true((help.stdout or ""):find("Usage:", 1, true) ~= nil, "help output")
end)

t:test("entry preserves Neovim's built-in parsers", function()
  with_temp_root(function(dir)
    local suite = dir .. "/parser_spec.lua"
    write_spec(
      table.concat({
        'assert(vim.treesitter.language.add("lua"))',
        'local parser = vim.treesitter.get_string_parser("local value = 1", "lua")',
        'assert(parser:parse()[1]:root():type() == "chunk")',
      }, "\n"),
      suite
    )
    local result = cli({ "--suite", suite }, dir)
    t.assert_eq(0, result.code, (result.stdout or "") .. (result.stderr or ""))
  end)
end)

t:test("entry uses one canonical checkout path through a directory symlink", function()
  with_temp_root(function(dir)
    local alias = dir .. "/checkout"
    local ok, err = vim.uv.fs_symlink(root, alias, { dir = true, junction = vim.fn.has("win32") == 1 })
    t.assert_true(ok, tostring(err))
    t:defer(function()
      assert(vim.uv.fs_unlink(alias))
    end)
    local suite = dir .. "/symlink_spec.lua"
    write_spec(
      table.concat({
        'local runner = require("__test__.support.runner")',
        "assert(vim.uv.cwd() == " .. string.format("%q", root) .. ")",
        "assert(vim.opt.runtimepath:get()[1] == " .. string.format("%q", root) .. ")",
        "assert(vim.list_contains(runner.discover(), "
          .. string.format("%q", root .. "/__test__/specs/support/runner_spec.lua")
          .. "))",
      }, "\n"),
      suite
    )
    local result = cli({ "--suite", suite }, dir, alias .. "/__test__/run.lua")
    t.assert_eq(0, result.code, (result.stdout or "") .. (result.stderr or ""))
  end)
end)

t:run()
