local util_json = require("fml.core.json")

-- https://github.com/folke/lazy.nvim/blob/3f13f080434ac942b150679223d54f5ca91e0d52/lua/lazy/core/util.lua#L1

---@class guanghechen.util.reporter.ReporterLevelEnum
local ReporterLevelEnum = {
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@param level guanghechen.types.IReporterLevelEnum|nil
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

---@param options guanghechen.types.IReporterOptions
---@param level integer
---@return nil
local function log(options, level)
  vim.schedule(function()
    local text = "[" .. options.from .. "]"
    if options.subject ~= nil then
      text = text .. " " .. options.subject
    end
    if options.message ~= nil then
      text = text .. ": " .. options.message
    end
    if options.details ~= nil then
      local details = util_json.stringify_prettier(options.details) or "" ---@type string
      text = text .. "\n\n" .. details
    end
    vim.notify(text, level)
  end)
end

---@class guanghechen.util.reporter
local M = {}

---@param options guanghechen.types.IReporterOptions
---@param level? guanghechen.types.IReporterLevelEnum
function M.log(options, level)
  local level_value = resolve_level(level) ---@type number
  log(options, level_value)
end

---@param options guanghechen.types.IReporterOptions
function M.debug(options)
  log(options, ReporterLevelEnum.DEBUG)
end

---@param options guanghechen.types.IReporterOptions
function M.info(options)
  log(options, ReporterLevelEnum.INFO)
end

---@param options guanghechen.types.IReporterOptions
function M.warn(options)
  log(options, ReporterLevelEnum.WARN)
end

---@param options guanghechen.types.IReporterOptions
function M.error(options)
  log(options, ReporterLevelEnum.ERROR)
end

return M
