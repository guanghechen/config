---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.image.env" ---@type string

local terminal_name = nil ---@type string|nil
if stl.env.IS_KITTY then
  terminal_name = "kitty"
elseif stl.env.IS_WEZTERM then
  terminal_name = "wezterm"
elseif stl.env.IS_GHOSTTY then
  terminal_name = "ghostty"
end

---@class era.m.image.env
---@field public name                    string
---@field public placeholders            boolean
---@field public remote                  boolean
---@field public supported               boolean
---@field public transform               ?fun(data: string): string
local M = {
  name = terminal_name or "",
  placeholders = terminal_name == "kitty" or terminal_name == "ghostty",
  remote = false,
  supported = terminal_name ~= nil,
}

if stl.env.IS_TMUX then
  M.name = M.name ~= "" and (M.name .. "/tmux") or "tmux"
  M.transform = function(data)
    return ("\027Ptmux;" .. data:gsub("\027", "\027\027")) .. "\027\\"
  end
end

return M
