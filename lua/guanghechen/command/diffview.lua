local path = require("eve.lib.path")
local constant = require("eve.builtin.constant")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.explorer_filesystem_cwd,
    tabtype = constant.TT_DIFFVIEW,
    desc = "diffview: explorer",
    action = function()
      local bufnr = vim.api.nvim_get_current_buf() ---@type integer
      local filetype = vim.bo[bufnr].filetype ---@type string
      if filetype == constant.FT_DIFFVIEW_FILES or filetype == constant.FT_DIFFVIEW_FILE_HISTORY then
        vim.cmd("DiffviewToggleFiles")
      else
        vim.cmd("DiffviewFocusFiles")
      end
    end,
  })
  .register({
    uuid = uuids.git_diffview,
    desc = "git: open diffview",
    action = function()
      local diffview = require("diffview") ---@type any
      diffview.open()
    end,
  })
  .register({
    uuid = uuids.git_file_history,
    desc = "git: open file history",
    action = function()
      local diffview = require("diffview") ---@type any
      local filepath = path.current_filepath()
      diffview.file_history(nil, filepath)
    end,
  })
  .register({
    uuid = uuids.git_history,
    desc = "git: open history",
    action = function()
      local diffview = require("diffview") ---@type any
      diffview.file_history()
    end,
  })
