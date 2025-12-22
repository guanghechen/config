if ark.env.IS_NIX then
  return
end

local im = require("dot.module.im") ---@type dot.module.im
if not im.get_input_method or not im.set_input_method then
  return
end

local augroup = ark.nvim.augroup("auto_toggle_im")
ark.timer.delay(function()
  local previous_mode = "n" ---@type ark.e.VimMode
  local previous_input_method = nil ---@type dot.module.im.InputMethod|nil
  vim.api.nvim_create_autocmd({ "ModeChanged" }, {
    group = augroup,
    callback = function()
      if not dot.context.behavior.auto_im:snapshot() then
        return
      end

      local current_mode = vim.fn.mode() ---@type ark.e.VimMode
      if current_mode ~= previous_mode then
        if previous_mode == "i" then
          previous_input_method = im.get_input_method()
          im.set_input_method("English")
        elseif current_mode == "i" then
          im.set_input_method(previous_input_method or "English")
        end
      end
      previous_mode = current_mode
    end,
  })
end, 200)
