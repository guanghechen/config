local winline = require("ghc.ui.winline")

local augroups = {
  toggle_relative = fml.util.augroup("toggle_relative"),
  redraw_when_mode_changes = fml.util.augroup("redraw_when_mode_changes"),
  refresh_winline = fml.util.augroup("refresh_winline"),
}

eve.mvc.add_disposable(eve.c.Disposable.new({
  on_dispose = function()
    if vim.fn.argc() < 1 and eve.path.is_git_repo() then
      ghc.command.session.autosave()
    end
  end,
}))

vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*",
  group = augroups.redraw_when_mode,
  callback = function()
    vim.schedule(function()
      vim.cmd.redrawstatus()
    end)
  end,
})

-- ---! Auto toggle realtive linenumber.
-- vim.api.nvim_create_autocmd({ "InsertLeave" }, {
--   pattern = "*",
--   group = augroups.toggle_relative,
--   callback = function()
--     if vim.o.nu and vim.api.nvim_get_mode().mode == "n" then
--       if ghc.context.client.relativenumber:snapshot() then
--         vim.opt.relativenumber = true
--       end
--     end
--   end,
-- })
--
-- vim.api.nvim_create_autocmd({ "InsertEnter" }, {
--   pattern = "*",
--   group = augroups.toggle_relative,
--   callback = function()
--     if vim.o.nu then
--       vim.opt.relativenumber = false
--       vim.schedule(function()
--         vim.cmd("redraw")
--       end)
--     end
--   end,
-- })
--

vim.api.nvim_create_autocmd({ "WinResized" }, {
  group = augroups.refresh_winline,
  callback = function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      vim.schedule(function()
        winline.update(winnr, true)
      end)
    end
  end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "BufWinEnter" }, {
  group = augroups.refresh_winline,
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.schedule(function()
      winline.update(winnr, true)
    end)
  end,
})
