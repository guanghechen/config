---@class std.reporter.Levels
local Levels = {
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@class std.reporter.IOptions
---@field from                          string
---@field group                         ?string
---@field subject                       ?string
---@field message                       ?string
---@field details                       ?any
---@field anonymous                     ?boolean
---@field silent                        ?boolean
---@field title                         ?string
---@field timeout                       ?integer
---@field highlights                    ?std.t.IHighlight[]

---@class std.reporter
local M = {}

---@param level                         std.e.LogLevelEnum|integer
---@param options                       std.reporter.IOptions
---@return nil
function M.log(level, options)
  local group = options.group ---@type string|nil
  local text = options.message or "" ---@type string
  local anonymous = options.anonymous or false ---@type boolean
  local silent = options.silent or false ---@type boolean
  local timeout = options.timeout or 3000 ---@type integer
  local highlights = options.highlights ---@type std.t.IHighlight[]|nil

  local title = options.title or options.from ---@type string
  if options.title == nil and options.subject ~= nil then
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

  local LEVEL = type(level) == "integer" and level or Levels[level] or vim.log.levels.INFO ---@type integer
  vim.notify(text, LEVEL, {
    group = group,
    title = title,
    timeout = timeout,
    message = text,
    anonymous = anonymous,
    silent = silent,
    highlights = highlights,
  })
end

---@param options                       std.reporter.IOptions
function M.debug(options)
  M.log("DEBUG", options)
end

---@param options                       std.reporter.IOptions
function M.info(options)
  M.log("INFO", options)
end

---@param options                       std.reporter.IOptions
function M.warn(options)
  M.log("WARN", options)
end

---@param options                       std.reporter.IOptions
function M.error(options)
  M.log("ERROR", options)
end

return M
