---@class era.clipboard
---@field public get_image_as_base64    fun(): string|nil
---@field public has_image              fun(): boolean
---@field public paste_image_from_clipboard fun(filepath_target: string): boolean
local M = {}

if stl.env.IS_MAC then
  M = require("era.clipboard.mac")
elseif stl.env.IS_WSL then
  M = require("era.clipboard.wsl")
elseif stl.env.IS_NIX then
  M = require("era.clipboard.nix")
elseif stl.env.IS_WIN then
  M = require("era.clipboard.win")
end

return M
