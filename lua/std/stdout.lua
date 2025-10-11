local colors = {
  reset = "\27[0m",
  green = "\27[32m",
  red = "\27[31m",
  yellow = "\27[33m",
  blue = "\27[34m",
  cyan = "\27[36m",
  magenta = "\27[35m",
  white = "\27[37m",
  bold = "\27[1m",
}

---@class std.stdout
local M = {}

---Log a message with color and prefix
---@param color                         string ANSI color code
---@param prefix                        string Icon or prefix text
---@param message                       string Message to log
function M.log(color, prefix, message)
  io.write(colors.bold .. color .. prefix .. colors.reset .. " " .. message .. "\n")
  io.flush()
end

---Log an info message
---@param prefix                        string Icon or prefix text
---@param message                       string Message to log
function M.info(prefix, message)
  M.log(colors.cyan, prefix, message)
end

---Log a success message
---@param prefix                        string Icon or prefix text
---@param message                       string Message to log
function M.success(prefix, message)
  M.log(colors.green, prefix, message)
end

---Log a warning message
---@param prefix                        string Icon or prefix text
---@param message                       string Message to log
function M.warn(prefix, message)
  M.log(colors.yellow, prefix, message)
end

---Log an error message
---@param prefix                        string Icon or prefix text
---@param message                       string Message to log
function M.error(prefix, message)
  M.log(colors.red, prefix, message)
end

M.colors = colors

return M
