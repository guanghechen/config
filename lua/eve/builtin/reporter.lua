---@class eve.builtin.reporter.Levels
local Levels = {
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@class eve.builtin.reporter.IOptions
---@field from string
---@field subject                       ?string
---@field message                       ?string
---@field details                       ?any

---@class eve.builtin.reporter
local M = {}

---@param options                       eve.builtin.reporter.IOptions
---@param level                         eve.builtin.notifier.LevelEnum
---@return nil
local function log(options, level)
  local title = options.from ---@type string
  local text = options.message or "" ---@type string

  if options.subject ~= nil then
    title = title .. " │ " .. options.subject
  end

  if options.details ~= nil then
    local details = "```json\n" .. eve.json.stringify_prettier(options.details) .. "\n```" ---@type string
    if #text > 0 then
      text = text .. "\n\n" .. details
    else
      text = details
    end
  end

  eve.notifier.notify(level, nil, title, text, 3000)
end

---@param options                       eve.builtin.reporter.IOptions
function M.debug(options)
  log(options, "DEBUG")
end

---@param options                       eve.builtin.reporter.IOptions
function M.info(options)
  log(options, "INFO")
end

---@param options                       eve.builtin.reporter.IOptions
function M.warn(options)
  log(options, "WARN")
end

---@param options                       eve.builtin.reporter.IOptions
function M.error(options)
  log(options, "ERROR")
end

return M
