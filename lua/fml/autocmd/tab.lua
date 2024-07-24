local state = require("fml.api.state")
local std_object = require("fml.std.object")

vim.api.nvim_create_autocmd({ "TabClosed" }, {
  callback = function()
    std_object.filter_inline(state.tabs, function(_, tabnr)
      return state.validate_tab(tabnr)
    end)

    vim.schedule(function()
      local tabnr_last = state.tab_history:present() ---@type integer|nil
      if tabnr_last ~= nil then
        vim.api.nvim_set_current_tabpage(tabnr_last)
      end
      state.refresh_tabs()
      state.remove_unrefereced_bufs()
    end)
  end,
})
