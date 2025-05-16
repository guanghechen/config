---@class std.reporter.Levels
local Levels = {
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@class std.reporter.IOptions
---@field from string
---@field subject                       ?string
---@field message                       ?string
---@field details                       ?any
---@field anonymous                     ?boolean
---@field silent                        ?boolean

---@class std.reporter
local M = {}

---@param options                       std.reporter.IOptions
---@param level                         std.e.LogLevelEnum
---@return nil
local function log(options, level)
  local title = options.from ---@type string
  local text = options.message or "" ---@type string
  local anonymous = options.anonymous or false ---@type boolean
  local silent = options.silent or false ---@type boolean

  if options.subject ~= nil then
    title = title .. " │ " .. options.subject
  end

  if options.details ~= nil then
    local details = "```json\n" .. std.json.stringify_prettier(options.details) .. "\n```" ---@type string
    if #text > 0 then
      text = text .. "\n\n" .. details
    else
      text = details
    end
  end

  vim.notify(text, vim.log.levels[level], {
    group = nil,
    title = title,
    timeout = 3000,
    message = text,
    anonymous = anonymous,
    silent = silent,
  })
end

---@param options                       std.reporter.IOptions
function M.debug(options)
  log(options, "DEBUG")
end

---@param options                       std.reporter.IOptions
function M.info(options)
  log(options, "INFO")
end

---@param options                       std.reporter.IOptions
function M.warn(options)
  log(options, "WARN")
end

---@param options                       std.reporter.IOptions
function M.error(options)
  log(options, "ERROR")
end

return M
