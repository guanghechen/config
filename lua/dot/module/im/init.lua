---@alias dot.module.im.InputMethod
---| "English"
---| "Chinese"

---@class dot.module.im
---@field public get_input_method       fun(): dot.module.im.InputMethod|nil
---@field public set_input_method       fun(input_method: dot.module.im.InputMethod): nil
local M = {}

if ark.env.IS_MAC then
  M = require("dot.module.im.mac")
elseif ark.env.IS_WSL then
  M = require("dot.module.im.wsl")
elseif ark.env.IS_WIN then
  M = require("dot.module.im.win")
end

return M

