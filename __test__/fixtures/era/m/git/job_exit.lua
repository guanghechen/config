---@diagnostic disable: undefined-global
local root, workspace, marker = assert(arg[1]), assert(arg[2]), assert(arg[3])
local kind = arg[4] or "status"
vim.opt.runtimepath:prepend(root)
_G.stl = { c = { Future = require("stl.c.future") } }
_G.yoz = require("yoz")
_G.dot = {
  path = {
    workspace = function()
      return workspace
    end,
    is_git_repo = function()
      return true
    end,
  },
}

local acknowledged = false
local factory = "start_" .. kind
local start = assert(yoz.git[factory])
yoz.git[factory] = function(options)
  local job = start(options)
  return {
    poll = function()
      local state, result, err = job:poll()
      acknowledged = acknowledged or state == "cancelled"
      return state, result, err
    end,
    cancel = function()
      job:cancel()
    end,
    dispose = function()
      job:dispose()
    end,
  }
end

local jobs = require("era.m.git.job")
jobs.setup()
local future
if kind == "blame" then
  future = jobs.run(function()
    return yoz.git.start_blame({ cwd = workspace, path = "file", contents = "base\n" })
  end)
else
  future = require("era.m.git.status").collect()
end
assert(
  vim.wait(5000, function()
    return vim.uv.fs_stat(marker) ~= nil
  end, 1),
  "Git hook did not start"
)
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if not acknowledged or not future:is_done() or not future:is_failed() then
      io.stderr:write("Native Git cancellation was not acknowledged before exit\n")
      os.exit(1)
    end
    io.stdout:write("native-exit-acknowledged\n")
  end,
})
vim.cmd("qa!")
