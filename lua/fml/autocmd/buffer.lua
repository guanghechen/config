local state = require("fml.api.state")
local std_array = require("fml.std.array")

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  callback = function(args)
    local bufnr = args.buf
    if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) or vim.fn.buflisted(bufnr) ~= 1 then
      return
    end

    state.refresh_buf(bufnr)

    local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
    if tab == nil then
      return
    end

    if not std_array.contains(tab.bufnrs, bufnr) then
      table.insert(tab.bufnrs, bufnr)
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local win = tab.wins[winnr]
      if win ~= nil then
        win.buf_history:push(bufnr)
      end
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})
