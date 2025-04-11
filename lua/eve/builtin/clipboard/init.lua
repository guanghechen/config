---@class eve.builtin.clipboard
---@field public has_image              fun(): boolean
---@field public paste_image            fun(filepath: string): boolean
---@field public get_clipboard          fun(): table|nil
local M = {}

if eve.env.IS_MAC then
  M = require("eve.builtin.clipboard.mac")
elseif eve.env.IS_WSL then
  M = require("eve.builtin.clipboard.wsl")
elseif eve.env.IS_NIX then
  M = require("eve.builtin.clipboard.nix")
elseif eve.env.IS_WIN then
  M = require("eve.builtin.clipboard.win")
end

return M
