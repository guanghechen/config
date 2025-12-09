---@class ark.reporter.Levels
local Levels = {
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@class ark.reporter.IOptions
---@field public from                   string
---@field public group                  ?string
---@field public subject                ?string
---@field public message                ?string
---@field public details                ?any
---@field public anonymous              ?boolean
---@field public silent                 ?boolean
---@field public title                  ?string
---@field public timeout                ?integer
---@field public highlights             ?ark.t.IHighlight[]

---@class ark.reporter
local M = {}

---@param level                         ark.e.LogLevelEnum|integer
---@param options                       ark.reporter.IOptions
---@return nil
function M.log(level, options)
  local group = options.group ---@type string|nil
  local text = options.message or "" ---@type string
  local anonymous = options.anonymous or false ---@type boolean
  local silent = options.silent or false ---@type boolean
  local timeout = options.timeout or 3000 ---@type integer
  local highlights = options.highlights ---@type ark.t.IHighlight[]|nil

  local title = options.title or options.from ---@type string
  if options.title == nil and options.subject ~= nil then
    title = title .. " │ " .. options.subject
  end

  if options.details ~= nil then
    local details = vim.json.encode(options.details, { indent = "  ", sort_keys = false }) ---@type string
    local content = "```json\n" .. details .. "\n```" ---@type string
    if #text > 0 then
      text = text .. "\n\n" .. content
    else
      text = content
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

---@param options                       ark.reporter.IOptions
function M.debug(options)
  M.log(vim.log.levels.DEBUG, options)
end

---@param options                       ark.reporter.IOptions
function M.info(options)
  M.log(vim.log.levels.INFO, options)
end

---@param options                       ark.reporter.IOptions
function M.warn(options)
  M.log(vim.log.levels.WARN, options)
end

---@param options                       ark.reporter.IOptions
function M.error(options)
  M.log(vim.log.levels.ERROR, options)
end

return M
