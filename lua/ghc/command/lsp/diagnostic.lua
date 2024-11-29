local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.goto_next_diagnostic,
    desc = "diagnostic: goto next",
    action = function()
      vim.diagnostic.goto_next()
    end,
  })
  .register({
    uuid = uuids.goto_next_error,
    desc = "diagnostic: goto next error",
    action = function()
      vim.diagnostic.goto_next({ sererity = vim.diagnostic.severity.ERROR })
    end,
  })
  .register({
    uuid = uuids.goto_next_hint,
    desc = "diagnostic: goto next hint",
    action = function()
      vim.diagnostic.goto_next({ sererity = vim.diagnostic.severity.HINT })
    end,
  })
  .register({
    uuid = uuids.goto_next_quickfix_item,
    desc = "diagnostic: goto next quickfix item",
    action = function()
      vim.cmd.cnext()
    end,
  })
  .register({
    uuid = uuids.goto_next_warn,
    desc = "diagnostic: goto next warning",
    action = function()
      vim.diagnostic.goto_next({ sererity = vim.diagnostic.severity.WARN })
    end,
  })
  .register({
    uuid = uuids.goto_prev_diagnostic,
    desc = "diagnostic: goto prev",
    action = function()
      vim.diagnostic.goto_prev()
    end,
  })
  .register({
    uuid = uuids.goto_prev_error,
    desc = "diagnostic: goto prev error",
    action = function()
      vim.diagnostic.goto_prev({ sererity = vim.diagnostic.severity.ERROR })
    end,
  })
  .register({
    uuid = uuids.goto_prev_hint,
    desc = "diagnostic: goto prev hint",
    action = function()
      vim.diagnostic.goto_prev({ sererity = vim.diagnostic.severity.HINT })
    end,
  })
  .register({
    uuid = uuids.goto_prev_quickfix_item,
    desc = "diagnostic: goto prev quickfix item",
    action = function()
      vim.cmd.cprev()
    end,
  })
  .register({
    uuid = uuids.goto_prev_warn,
    desc = "diagnostic: goto prev warning",
    action = function()
      vim.diagnostic.goto_prev({ sererity = vim.diagnostic.severity.WARN })
    end,
  })
  .register({
    uuid = uuids.open_line_diagnostic,
    desc = "diagnostic: open float window (line)",
    action = function()
      vim.diagnostic.open_float()
    end,
  })
