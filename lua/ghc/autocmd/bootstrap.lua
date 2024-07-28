local augroups = {
  toggle_relative = fml.util.augroup("toggle_relative"),
  redraw_when_mode_changes = fml.util.augroup("redraw_when_mode_changes"),
}

---! Auto toggle realtive linenumber.
vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  pattern = "*",
  group = augroups.toggle_relative,
  callback = function()
    if vim.o.nu and vim.api.nvim_get_mode().mode == "n" then
      if ghc.context.client.relativenumber:snapshot() then
        vim.opt.relativenumber = true
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  pattern = "*",
  group = augroups.toggle_relative,
  callback = function()
    if vim.o.nu then
      vim.opt.relativenumber = false
      vim.schedule(function()
        vim.cmd("redraw")
      end)
    end
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*",
  group = augroups.redraw_when_mode,
  callback = function()
    vim.schedule(function()
      vim.cmd("redrawstatus")
    end)
  end,
})
