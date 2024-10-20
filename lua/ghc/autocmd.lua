local winline = require("ghc.ux.winline")

local augroups = {
  toggle_relative = eve.nvim.augroup("toggle_relative"),
  redraw_when_mode_changes = eve.nvim.augroup("redraw_when_mode_changes"),
  refresh_winline = eve.nvim.augroup("refresh_winline"),
}

vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*",
  group = augroups.redraw_when_mode,
  callback = function()
    vim.schedule(function()
      vim.cmd.redrawstatus()
    end)
  end,
})

---! Show lsp progress.
vim.api.nvim_create_autocmd("LspProgress", {
  pattern = { "begin", "end" },
  callback = function(args)
    local data = args.data.params.value
    local progress = ""
    if data.percentage then
      local spinners = { "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" }
      local spinner_w = 100 / #spinners
      local icon = spinners[math.floor(data.percentage / spinner_w) + 1]
      progress = icon .. " " .. data.percentage .. "%% "
    end
    local str = progress .. (data.message or "") .. " " .. (data.title or "")
    local lsp_msg = data.kind == "end" and "" or str ---@type string
    eve.context.state.status.lsp_msg:next(lsp_msg)
    vim.cmd.redrawstatus()
  end,
})

-- ---! Auto toggle realtive linenumber.
-- vim.api.nvim_create_autocmd({ "InsertLeave" }, {
--   pattern = "*",
--   group = augroups.toggle_relative,
--   callback = function()
--     if vim.o.nu and vim.api.nvim_get_mode().mode == "n" then
--       if eve.context.state.theme.relativenumber:snapshot() then
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
--         vim.cmd.redraw()
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
