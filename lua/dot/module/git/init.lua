---@class dot.module.git
local M = {
  blame = require("dot.module.git.blame"),
  browse = require("dot.module.git.browse"),
  buffer = require("dot.module.git.buffer"),
  cmd = require("dot.module.git.cmd"),
  diff = require("dot.module.git.diff"),
  hunk = require("dot.module.git.hunk"),
  repo = require("dot.module.git.repo"),
  sign = require("dot.module.git.sign"),
  state = require("dot.module.git.state"),
  status = require("dot.module.git.status"),
  watcher = require("dot.module.git.watcher"),
}

M.browse.setup()
M.cmd.setup()
M.diff.setup()
M.hunk.setup()
M.repo.setup()
M.sign.setup()
M.state.setup()
M.status.setup()
M.buffer.setup()
M.blame.setup()
M.watcher.setup()

return M
