local __module_name__ = "ghc.command.tab.close" ---@type string

local reporter = require("eve.lib.reporter")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.tab_close,
    desc = "tab: close current",
    action = function()
      local N = vim.fn.tabpagenr("$") ---@type integer
      if N <= 1 then
        reporter.warn({
          from = __module_name__,
          subject = "close_current",
          message = "This is the last tab, cannot close it.",
        })
        return
      end
      vim.cmd.tabclose()
    end,
  })
  .register({
    uuid = uuids.tab_close_to_leftest,
    desc = "tab: close to leftest",
    action = function()
      local tabid = vim.fn.tabpagenr() ---@type integer
      for _ = 1, tabid - 1, 1 do
        vim.cmd("-tabclose")
      end
    end,
  })
  .register({
    uuid = uuids.tab_close_to_rightest,
    desc = "tab: close to rightest",
    action = function()
      local N = vim.fn.tabpagenr("$") ---@type integer
      local tabid = vim.fn.tabpagenr() ---@type integer
      for _ = tabid + 1, N, 1 do
        vim.cmd("+tabclose")
      end
    end,
  })
  .register({
    uuid = uuids.tab_close_others,
    desc = "tab: close others",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      vim.cmd("tabonly")
      state.tab.tab_history:clear()
      state.tab.tab_history:push(tabnr)
    end,
  })
