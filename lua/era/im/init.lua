---@alias era.im.InputMethod
---| "English"
---| "Chinese"

---@class era.im
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

return M

