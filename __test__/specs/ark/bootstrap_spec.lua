local harness = require("__test__.support.harness")

local t = harness.new()

---@class ark.bootstrap.test.IOpts
---@field initial_cwd                   string
---@field filedir                      string
---@field gitroots                     table<string, string>
---@field rejected_dir                 string|nil

---@class ark.bootstrap.test.IRuntime
---@field cwd                           string
---@field cwd_updates                   string[]

---@param opts                          ark.bootstrap.test.IOpts
---@return ark.bootstrap.test.IRuntime
local function setup(opts)
  local runtime = {
    cwd = opts.initial_cwd,
    cwd_updates = {},
  } ---@type ark.bootstrap.test.IRuntime

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

for _, case in ipairs({
  {
    name = "snapshots the selected ordinary directory",
    opts = { initial_cwd = "/shell", filedir = "/workspace/src", gitroots = {} },
    cwd = "/workspace/src",
  },
  {
    name = "snapshots the selected Git root",
    opts = { initial_cwd = "/shell", filedir = "/repo/src", gitroots = { ["/repo/src"] = "/repo" } },
    cwd = "/repo",
  },
  {
    name = "snapshots the existing CWD after a failed directory change",
    opts = { initial_cwd = "/shell", filedir = "/missing", gitroots = {}, rejected_dir = "/missing" },
    cwd = "/shell",
  },
}) do
  t:test(case.name, function()
    local runtime = setup(case.opts)

    setup_workspace()

    t.assert_eq(case.cwd, runtime.cwd, "effective CWD")
    t.assert_eq(1, #runtime.cwd_updates, "native CWD updates")
    t.assert_eq(runtime.cwd, runtime.cwd_updates[1], "native CWD")
  end)
end

t:run()
