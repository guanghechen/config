local state = require("fml.api.state")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")

vim.api.nvim_create_autocmd({ "BufAdd", "BufEnter" }, {
  callback = function(args)
    local bufnr = args.buf
    if type(bufnr) ~= "number" then
      return
    end

    ---! The current bufnr of the window still be the old one, so use vim.schedule to refresh later.
    vim.schedule(function()
      if state.validate_buf(bufnr) then
        state.refresh_buf(bufnr)
      else
        state.bufs[bufnr] = nil
      end

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      state.refresh_tab(tabnr)

      local winnr = vim.api.nvim_get_current_win() ---@type integer
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
    if type(bufnr) ~= "number" or state.bufs[bufnr] == nil then
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

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.opt_local.buflisted = false
  end,
})
