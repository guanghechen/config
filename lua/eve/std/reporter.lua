local std_json = require("eve.std.json")

---@class eve.std.reporter
local M = {}

---@class eve.std.reporter.IReporterOptions
---@field from string
---@field subject                       ?string
---@field message                       ?string
---@field details                       ?any

---@class eve.std.reporter.ReporterLevelEnum
local ReporterLevelEnum = {
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@param level                         eve.enums.ReportLevel|nil
---@return number
local function resolve_level(level)
  if level == nil then
    return ReporterLevelEnum.INFO
  end

  local result = ReporterLevelEnum[level]
  if result == nil then
    return ReporterLevelEnum.INFO
  end
  return result
end

---@param options                       eve.std.reporter.IReporterOptions
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
    local details = std_json.stringify_prettier(options.details) or "" ---@type string
    text = text .. "\n\n" .. details
  end

  vim.schedule(function()
    vim.notify(text, level)
  end)
end

---@param options                       eve.std.reporter.IReporterOptions
---@param level                         ?eve.enums.ReportLevel
function M.log(options, level)
  local level_value = resolve_level(level) ---@type number
  log(options, level_value)
end

---@param options                       eve.std.reporter.IReporterOptions
function M.debug(options)
  log(options, ReporterLevelEnum.DEBUG)
end

---@param options                       eve.std.reporter.IReporterOptions
function M.info(options)
  log(options, ReporterLevelEnum.INFO)
end

---@param options                       eve.std.reporter.IReporterOptions
function M.warn(options)
  log(options, ReporterLevelEnum.WARN)
end

---@param options                       eve.std.reporter.IReporterOptions
function M.error(options)
  log(options, ReporterLevelEnum.ERROR)
end

return M
