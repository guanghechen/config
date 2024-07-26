local state = require("fml.api.state")
local std_array = require("fml.std.array")

vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" then
      return
    end

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = vim.api.nvim_get_current_win() ---@type integer

    ---! The current bufnr of the window still be the old one, so use vim.schedule to refresh later.
    vim.schedule(function()
      state.refresh_buf(bufnr)
      state.refresh_tab(tabnr)
      local win = state.wins[winnr]
      if win ~= nil then
        win.buf_history:push(bufnr)
      end
    end)
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" then
      return
    end

    state.bufs[bufnr] = nil
    for _, tab in pairs(state.tabs) do
      if tab.bufnr_set[bufnr] then
        tab.bufnr_set[bufnr] = nil
        std_array.filter_inline(tab.bufnrs, function(nr)
          return nr ~= bufnr
        end)
      end
    end
  end,
})
