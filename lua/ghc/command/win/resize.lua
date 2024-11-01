local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
  .register({
    uuid = uuids.win_resize_horizontal_minus,
    desc = "win: resize horizontal (minus)",
    action = function()
      local step = vim.v.count1 or 1
      vim.cmd("resize -" .. step)
    end,
  })
  .register({
    uuid = uuids.win_resize_horizontal_plus,
    desc = "win: resize horizontal (plus)",
    action = function()
      local step = vim.v.count1 or 1
      vim.cmd("resize +" .. step)
    end,
  })
  .register({
    uuid = uuids.win_resize_vertical_minus,
    desc = "win: resize vertical (minus)",
    action = function()
      local step = vim.v.count1 or 1
      vim.cmd("vertical resize -" .. step)
    end,
  })
  .register({
    uuid = uuids.win_resize_vertical_plus,
    desc = "win: resize vertical (plus)",
    action = function()
      local step = vim.v.count1 or 1
      vim.cmd("vertical resize +" .. step)
    end,
  })
