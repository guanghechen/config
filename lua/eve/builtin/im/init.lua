---@alias eve.builtin.im.InputMethod
---|"English"
---|"Chinese"

---@class eve.builtin.im
---@field public get_input_method   fun(): eve.builtin.im.InputMethod|nil
---@field public set_input_method   fun(input_method: eve.builtin.im.InputMethod): nil
local M = {}

if eve.env.IS_MAC then
  M = require("eve.builtin.im.mac")
elseif eve.env.IS_WSL then
elseif eve.env.IS_NIX then
elseif eve.env.IS_WIN then
end

return M
