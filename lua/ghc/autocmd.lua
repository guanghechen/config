local winline = require("ghc.ux.winline")

local lsp_progress_spinners = { "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" }
vim.api.nvim_create_autocmd("LspProgress", {
  pattern = { "begin", "end" },
  callback = function(args)
    local data = args.data.params.value
    local progress = ""

    if data.percentage then
      local idx = math.max(1, math.floor(data.percentage / 10))
      local icon = lsp_progress_spinners[idx]
      progress = icon .. " " .. data.percentage .. "%% "
    end

    local str = progress .. (data.message or "") .. " " .. (data.title or "")
    local lsp_msg = data.kind == "end" and "" or str ---@type string
    eve.context.state.status.lsp_msg:next(lsp_msg)
    vim.cmd.redrawstatus()
  end,
})

vim.api.nvim_create_autocmd({ "WinResized" }, {
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
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.schedule(function()
      winline.update(winnr, true)
    end)
  end,
})
