---@diagnostic disable: undefined-global
--- Test for __test__.runner module
--- Run with: nvim -l lua/__test__/__test__/runner.lua

local harness = require("__test__.harness")
local runner = require("__test__.runner")

local t = harness.new("__test__.runner")

---@param path                          string
---@return boolean
local function has_path(paths, path)
  for _, item in ipairs(paths) do
    if item == path then
      return true
    end
  end
  return false
end

---@param callback                      fun(root: string)
---@return nil
local function with_temp_root(callback)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/nested", "p")

  local ok, err = pcall(callback, root)
  vim.fn.delete(root, "rf")

  if not ok then
    error(err, 0)
  end
end

---@param lines                         string[]
---@param filepath                      string
---@return nil
local function write_suite(lines, filepath)
  local ok = vim.fn.writefile(lines, filepath)
  if ok ~= 0 then
    error("failed to write temp suite: " .. filepath)
  end
end

t:test("module: require exposes API without running", function()
  t.assert_eq("function", type(runner.discover), "discover API")
  t.assert_eq("function", type(runner.run_all), "run_all API")
  t.assert_eq("function", type(runner.main), "main API")
end)

t:test("discover: excludes support scripts from default root", function()
  local suites = runner.discover()
  t.assert_false(has_path(suites, "lua/__test__/bootstrap.lua"), "bootstrap should be excluded")
  t.assert_false(has_path(suites, "lua/__test__/harness.lua"), "harness should be excluded")
  t.assert_false(has_path(suites, "lua/__test__/run.lua"), "script entry should be excluded")
  t.assert_false(has_path(suites, "lua/__test__/runner.lua"), "runner should be excluded")
  t.assert_true(has_path(suites, "lua/__test__/__test__/runner.lua"), "runner suite should be included")
end)

t:test("discover: excludes top-level support scripts from custom root", function()
  with_temp_root(function(root)
    write_suite({}, root .. "/bootstrap.lua")
    write_suite({}, root .. "/harness.lua")
    write_suite({}, root .. "/run.lua")
    write_suite({}, root .. "/runner.lua")
    write_suite({}, root .. "/nested/harness.lua")

    local suites = runner.discover(root)
    t.assert_false(has_path(suites, root .. "/bootstrap.lua"), "bootstrap should be excluded")
    t.assert_false(has_path(suites, root .. "/harness.lua"), "harness should be excluded")
    t.assert_false(has_path(suites, root .. "/run.lua"), "script entry should be excluded")
    t.assert_false(has_path(suites, root .. "/runner.lua"), "runner should be excluded")
    t.assert_true(has_path(suites, root .. "/nested/harness.lua"), "nested suite should be included")
  end)
end)

t:test("discover: filters temp suites by literal path", function()
  with_temp_root(function(root)
    write_suite({ "print('alpha')" }, root .. "/alpha.lua")
    write_suite({ "print('beta')" }, root .. "/nested/beta.lua")

    local suites = runner.discover(root, "nested")
    t.assert_eq(1, #suites, "filtered count")
    t.assert_eq(root .. "/nested/beta.lua", suites[1], "filtered path")
  end)
end)

t:test("run_all: returns zero for passing temp suites", function()
  with_temp_root(function(root)
    write_suite({}, root .. "/pass.lua")
    write_suite({}, root .. "/nested/pass.lua")

    io.write("\n")
    io.flush()
    local failed = runner.run_all({ root = root })
    t.assert_eq(0, failed, "failed suite count")
  end)
end)

t:run()
