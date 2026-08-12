---@diagnostic disable: undefined-global
--- Test for ark workspace setup
--- Run with: nvim -l lua/__test__/ark/workspace.lua

local harness = require("__test__.harness")

local t = harness.new("ark.workspace")

---@class ark.workspace.test.IOpts
---@field initial_cwd                   string
---@field filedir                      string
---@field gitroots                     table<string, string>
---@field rejected_dir                 string|nil

---@class ark.workspace.test.IRuntime
---@field cwd                           string
---@field cwd_updates                   string[]

---@param opts                          ark.workspace.test.IOpts
---@return ark.workspace.test.IRuntime
local function setup(opts)
  local runtime = {
    cwd = opts.initial_cwd,
    cwd_updates = {},
  } ---@type ark.workspace.test.IRuntime

  t:patch_global("stl", {
    env = {
      locate_gitroot = function(dirpath)
        return opts.gitroots[dirpath]
      end,
    },
  })
  t:patch_global("yoz", {
    path = {
      set_cwd = function(cwd)
        runtime.cwd_updates[#runtime.cwd_updates + 1] = cwd
      end,
    },
  })
  t:patch_table(vim.fn, "expand", function(expr)
    if expr == "%" then
      return opts.filedir .. "/file.lua"
    end
    if expr == "%:p:h" then
      return opts.filedir
    end
    error("unexpected expand expression: " .. expr)
  end)
  t:patch_table(vim.fn, "getcwd", function()
    return runtime.cwd
  end)
  t:patch_table(vim.uv, "cwd", function()
    return opts.initial_cwd
  end)
  t:patch_table(vim.api, "nvim_set_current_dir", function(dirpath)
    if dirpath == opts.rejected_dir then
      error("directory change failed")
    end
    runtime.cwd = dirpath
  end)
  t:patch_table(vim, "schedule", function() end)

  return runtime
end

local function setup_workspace()
  local bootstrap = assert(loadfile("lua/ark/bootstrap.lua"))()
  bootstrap.setup_workspace()
end

t:test("snapshots the selected ordinary directory", function()
  local runtime = setup({
    initial_cwd = "/shell",
    filedir = "/workspace/src",
    gitroots = {},
  })

  setup_workspace()

  t.assert_eq("/workspace/src", runtime.cwd, "effective CWD")
  t.assert_eq(1, #runtime.cwd_updates, "native CWD updates")
  t.assert_eq(runtime.cwd, runtime.cwd_updates[1], "native CWD")
end)

t:test("snapshots the selected Git root", function()
  local runtime = setup({
    initial_cwd = "/shell",
    filedir = "/repo/src",
    gitroots = { ["/repo/src"] = "/repo" },
  })

  setup_workspace()

  t.assert_eq("/repo", runtime.cwd, "effective CWD")
  t.assert_eq(1, #runtime.cwd_updates, "native CWD updates")
  t.assert_eq(runtime.cwd, runtime.cwd_updates[1], "native CWD")
end)

t:test("snapshots the existing CWD after a failed directory change", function()
  local runtime = setup({
    initial_cwd = "/shell",
    filedir = "/missing",
    gitroots = {},
    rejected_dir = "/missing",
  })

  setup_workspace()

  t.assert_eq("/shell", runtime.cwd, "effective CWD")
  t.assert_eq(1, #runtime.cwd_updates, "native CWD updates")
  t.assert_eq(runtime.cwd, runtime.cwd_updates[1], "native CWD")
end)

t:run()
