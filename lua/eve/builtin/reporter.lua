local json = require("eve.builtin.json")

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

---@param options                       eve.builtin.reporter.IOptions
---@param level                         integer
---@return nil
local function log(options, level)
  local title = options.from ---@type string
  local text = options.message or "" ---@type string

  if options.subject ~= nil then
    title = title .. " │ " .. options.subject
  end

  if options.details ~= nil then
    local details = "```json\n" .. json.stringify_prettier(options.details) .. "\n```" ---@type string
    if #text > 0 then
      text = text .. "\n\n" .. details
    else
      text = details
    end
  end

  vim.schedule(function()
    vim.notify(text, level, {
      title = title,
      on_open = function(winnr)
        vim.wo[winnr].conceallevel = 2
        vim.wo[winnr].concealcursor = "n"
        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        if vim.treesitter ~= nil and vim.treesitter.language ~= nil then
          local lang = vim.treesitter.language.get_lang("markdown") or "markdown" ---@type string
          local has_ts_parser = pcall(vim.treesitter.language.add, lang)
          if has_ts_parser then
            vim.treesitter.start(bufnr, lang)
          end
        end
      end,
    })
  end)
end

---@param options                       eve.builtin.reporter.IOptions
---@param level                         ?eve.e.ReportLevel
function M.log(options, level)
  local level_value = resolve_level(level) ---@type integer
  log(options, level_value)
end

---@param options                       eve.builtin.reporter.IOptions
function M.debug(options)
  log(options, Levels.DEBUG)
end

---@param options                       eve.builtin.reporter.IOptions
function M.info(options)
  log(options, Levels.INFO)
end

---@param options                       eve.builtin.reporter.IOptions
function M.warn(options)
  log(options, Levels.WARN)
end

---@param options                       eve.builtin.reporter.IOptions
function M.error(options)
  log(options, Levels.ERROR)
end

return M
