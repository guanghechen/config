local state = require("fml.api.state")
local std_object = require("fml.std.object")

vim.api.nvim_create_autocmd({ "TabNew" }, {
  callback = function(args)
    vim.notify("tab new: " .. vim.inspect(args))
  end,
})

vim.api.nvim_create_autocmd({ "TabClosed" }, {
  callback = function(args)
    std_object.filter_inline(state.tabs, function(_, tabnr)
      return state.validate_tab(tabnr)
    end)

    local tabnr_last = state.tab_history:present() ---@type integer|nil
    if tabnr_last ~= nil then
      vim.api.nvim_set_current_tabpage(tabnr_last)
    end
    vim.schedule(function()
      state.refresh_tabs()
      state.remove_unrefereced_bufs()
    end)
  end,
})

