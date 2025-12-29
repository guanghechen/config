---@class dot.module.clipboard
---@field public get_image_as_base64    fun(): string|nil
---@field public has_image              fun(): boolean
---@field public paste_image_from_clipboard fun(filepath_target: string): boolean
local M = {}

if stl.env.IS_MAC then
  M = require("dot.module.clipboard.mac")
elseif stl.env.IS_WSL then
  M = require("dot.module.clipboard.wsl")
elseif stl.env.IS_NIX then
  M = require("dot.module.clipboard.nix")
elseif stl.env.IS_WIN then
  M = require("dot.module.clipboard.win")
end

return M
