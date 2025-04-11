if not eve.env.IS_NIX then
  vim.defer_fn(function()
    local previous_mode = "n" ---@type eve.e.VimMode
    local previous_input_method = nil ---@type eve.builtin.im.InputMethod|nil
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
      group = eve.nvim.augroup("auto_toggle_im"),
      callback = function()
        local enabled = eve.state.behavior.auto_im:snapshot() ---@type boolean
        if not enabled then
          return
        end

        local current_mode = vim.fn.mode() ---@type eve.e.VimMode
        if current_mode ~= previous_mode then
          if previous_mode == "i" then
            previous_input_method = eve.im.get_input_method() ---@type eve.builtin.im.InputMethod|nil
            eve.im.set_input_method("English")
          elseif current_mode == "i" then
            eve.im.set_input_method(previous_input_method or "English")
          end
        end
        previous_mode = current_mode
      end,
    })
  end, 200)
end
