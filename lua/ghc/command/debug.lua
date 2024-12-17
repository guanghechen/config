local __module_name__ = "ghc.command.debug" ---@type string

local reporter = require("eve.lib.reporter")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.debug_inspect,
    desc = "debug: inspect",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local buftype = vim.bo[bufnr].buftype ---@type string

      local meta_tab = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      local meta_win = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
      local meta_buf = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil

      local winnr_cur = eve.tab.get_current_winnr() ---@type integer
      local bufnr_cur = winnr_cur > 0 and vim.api.nvim_win_get_buf(winnr_cur) or 0 ---@type integer

      local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
      local bufs = {} ---@type { bufnr: integer, filetype: string, filepath: string }[]
      for _, nr in ipairs(bufnrs) do
        bufs[#bufs + 1] = { bufnr = nr, filetype = vim.bo[nr].filetype, filepath = vim.api.nvim_buf_get_name(nr) }
      end

      reporter.info({
        from = __module_name__,
        subject = "inspect",
        details = {
          bufnr = bufnr,
          bufnr_cur = bufnr_cur,
          buftype = buftype or "nil",
          tabnr = tabnr,
          winnr = winnr,
          winnr_cur = winnr_cur,
          z_details = {
            bufs = bufs,
            meta_buf = meta_buf,
            meta_tab = meta_tab,
            meta_win = meta_win,
          },
        },
      })
    end,
  })
  .register({
    uuid = uuids.debug_inspect_pos,
    desc = "debug: inspect pos",
    action = function()
      vim.show_pos()
    end,
  })
  .register({
    uuid = uuids.debug_inspect_state,
    desc = "debug: inspect state",
    action = function()
      local data = state.dump() ---@type eve.t.state.data
      reporter.info({
        from = __module_name__,
        subject = "inspect_state",
        details = { data = data },
      })
    end,
  })
  .register({
    uuid = uuids.debug_inspect_tree,
    desc = "debug: inspect tree",
    action = function()
      vim.cmd.InspectTree()
    end,
  })
