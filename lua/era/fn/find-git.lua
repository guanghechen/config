---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.find_git" ---@type string

local GitFiles = require("era.m.git_files")
local widget ---@type era.m.git_files.Widget|nil

---@return nil
local function find_git()
  if not widget or widget:isdisposed() then
    widget = GitFiles.new()
  end
  widget:toggle()
end

return find_git
