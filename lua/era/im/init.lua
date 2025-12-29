---@alias era.im.InputMethod
---| "English"
---| "Chinese"

---@class era.im
---@field public dressing               fun(): nil
---@field public get_input_method       fun(): era.im.InputMethod|nil
---@field public set_input_method       fun(input_method: era.im.InputMethod): nil
local M = {}

if stl.env.IS_MAC then
  M = require("era.im.mac")
elseif stl.env.IS_WSL then
  M = require("era.im.wsl")
elseif stl.env.IS_WIN then
  M = require("era.im.win")
end

---@return nil
function M.dressing()
  if stl.env.IS_NIX then
    return
  end

  if not M.get_input_method or not M.set_input_method then
    return
  end

  local augroup = stl.nvim.fn.augroup("era.im_auto_toggle")
  stl.timer.delay(function()
    local previous_mode = "n" ---@type stl.e.VimMode
    local previous_input_method = nil ---@type era.im.InputMethod|nil
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
      group = augroup,
      callback = function()
        if not dot.context.behavior.auto_im:snapshot() then
          return
        end

        local current_mode = vim.fn.mode() ---@type stl.e.VimMode
        if current_mode ~= previous_mode then
          if previous_mode == "i" then
            previous_input_method = M.get_input_method()
            M.set_input_method("English")
          elseif current_mode == "i" then
            M.set_input_method(previous_input_method or "English")
          end
        end
        previous_mode = current_mode
      end,
    })
  end, 200)
end

return M

