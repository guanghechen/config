---@class era.m.clipboard
---@field public get_image_as_base64    fun(): string|nil
---@field public has_image              fun(): boolean
---@field public paste_image_from_clipboard fun(filepath_target: string): boolean
local M = {}

if stl.env.IS_OSX then
  M = require("era.m.clipboard.osx")
elseif stl.env.IS_WSL then
  M = require("era.m.clipboard.wsl")
elseif stl.env.IS_NIX then
  M = require("era.m.clipboard.nix")
elseif stl.env.IS_WIN then
  M = require("era.m.clipboard.win")
end

return M
