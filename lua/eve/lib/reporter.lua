---@class eve.lib.reporter.Levels
local Levels = {
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@class eve.lib.reporter.IOptions
---@field from string
---@field subject                       ?string
---@field message                       ?string
---@field details                       ?any

---@class eve.lib.reporter
local M = {}

---@param level                         eve.e.ReportLevel|nil
---@return integer
local function resolve_level(level)
  if level == nil then
    return Levels.INFO
  end

  local result = Levels[level]
  if result == nil then
    return Levels.INFO
  end
  return result
end

---@param options                       eve.lib.reporter.IOptions
---@param level                         integer
---@return nil
local function log(options, level)
  local text = "[" .. options.from .. "]"
  if options.subject ~= nil then
    text = text .. " " .. options.subject
  end
  if options.message ~= nil then
    text = text .. ": " .. options.message
  end
  if options.details ~= nil then
    local details = vim.inspect(options.details) ---@type string
    text = text .. "\n\n" .. details
  end

  vim.schedule(function()
    vim.notify(text, level)
  end)
end

---@param options                       eve.lib.reporter.IOptions
---@param level                         ?eve.e.ReportLevel
function M.log(options, level)
  local level_value = resolve_level(level) ---@type integer
  log(options, level_value)
end

---@param options                       eve.lib.reporter.IOptions
function M.debug(options)
  log(options, Levels.DEBUG)
end

---@param options                       eve.lib.reporter.IOptions
function M.info(options)
  log(options, Levels.INFO)
end

---@param options                       eve.lib.reporter.IOptions
function M.warn(options)
  log(options, Levels.WARN)
end

---@param options                       eve.lib.reporter.IOptions
function M.error(options)
  log(options, Levels.ERROR)
end

return M
