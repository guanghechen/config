---@class dot.module.clipboard
---@field public get_image_as_base64    fun(): string|nil
---@field public has_image              fun(): boolean
---@field public paste_image_from_clipboard fun(filepath_target: string): boolean
local M = {}

if ark.env.IS_MAC then
  M = require("dot.module.clipboard.mac")
elseif ark.env.IS_WSL then
  M = require("dot.module.clipboard.wsl")
elseif ark.env.IS_NIX then
  M = require("dot.module.clipboard.nix")
elseif ark.env.IS_WIN then
  M = require("dot.module.clipboard.win")
end

return M
