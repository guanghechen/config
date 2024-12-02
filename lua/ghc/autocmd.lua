local tmux = require("eve.lib.tmux")
local state = require("eve.state")
local winline = require("ghc.nvimbar.winline")

---! Watch the zen mode change on tmux.
if vim.env.TMUX then
  vim.api.nvim_create_autocmd({ "VimResized" }, {
    callback = function()
      local is_tmux_pane_zoomed = tmux.is_tmux_pane_zoomed() ---@type boolean
      state.state.status.tmux_zen_mode:next(is_tmux_pane_zoomed)
    end,
  })
end

local lsp_progress_spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" }
vim.api.nvim_create_autocmd("LspProgress", {
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
    state.state.status.lsp_msg:next(lsp_msg)
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
