if not std.env.IS_NIX then
  local augroup = eve.nvim.augroup("auto_toggle_im")
  std.timer.set_timeout(function()
    local previous_mode = "n" ---@type std.e.VimMode
    local previous_input_method = nil ---@type eve.builtin.im.InputMethod|nil
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
      group = augroup,
      callback = function()
        local enabled = eve.context.behavior.auto_im:snapshot() ---@type boolean
        if not enabled then
          return
        end

        local current_mode = vim.fn.mode() ---@type std.e.VimMode
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
