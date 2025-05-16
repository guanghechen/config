---@alias eve.builtin.im.InputMethod
---|"English"
---|"Chinese"

---@class eve.builtin.im
---@field public get_input_method   fun(): eve.builtin.im.InputMethod|nil
---@field public set_input_method   fun(input_method: eve.builtin.im.InputMethod): nil
local M = {}

if std.env.IS_MAC then
  M = require("eve.builtin.im.mac")
elseif std.env.IS_WSL then
  M = require("eve.builtin.im.wsl")
elseif std.env.IS_NIX then
  function M.get_input_method()
    return nil
  end

  function M.set_input_method()
    return nil
  end
elseif std.env.IS_WIN then
  M = require("eve.builtin.im.win")
end

return M
