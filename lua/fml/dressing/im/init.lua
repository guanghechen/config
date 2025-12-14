if ark.env.IS_NIX then
  return
end

---@alias fml.dressing.im.InputMethod
---| "English"
---| "Chinese"

---@class fml.dressing.im
---@field public get_input_method       fun(): fml.dressing.im.InputMethod|nil
---@field public set_input_method       fun(input_method: fml.dressing.im.InputMethod): nil

---@type fml.dressing.im|nil
local im = ark.env.IS_MAC and require("fml.dressing.im.mac")
  or ark.env.IS_WSL and require("fml.dressing.im.wsl")
  or ark.env.IS_WIN and require("fml.dressing.im.win")
  or nil

if im then
  local augroup = ark.nvim.augroup("auto_toggle_im")
  ark.timer.set_timeout(function()
    local previous_mode = "n" ---@type ark.e.VimMode
    local previous_input_method = nil ---@type fml.dressing.im.InputMethod|nil
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
end
