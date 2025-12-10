---@class ark.t.IDebugCmdParams
---@field public cmd                    string|string[]
---@field public level                  ?integer|nil
---@field public title                  ?string
---@field public args                   ?string[]
---@field public cwd                    ?string
---@field public group                  ?boolean
---@field public notify                 ?boolean
---@field public footer                 ?string
---@field public header                 ?string
---@field public props                  ?table<string, string>

---@class ark.debug
local M = {}
setmetatable(M, {
  ---@param title                       string|unknown
  ---@param message                     unknown|nil
  ---@return nil
  __call = function(self, title, message)
    self.log(title, message)
  end,
})

---@param message                       unknown|nil
---@return string
local function format_message(message)
  if message == nil then
    return "nil"
  end

  if type(message) == "string" then
    return message
  end

  if type(message) == "boolean" then
    return message and "true" or "false"
  end

  if type(message) == "number" then
    return tostring(message)
  end

  return string.format("```json\n%s\n```", vim.inspect(message))
end

---@param title                         string|unknown
---@param message                       unknown|nil
function M.log(title, message)
  local text_title, text_content = "", "" ---@type string, string
  if type(title) == "string" then
    text_title = title
    text_content = format_message(message)
  else
    text_title = "debug"
    text_content = format_message(title)
  end

  vim.notify(text_content, vim.log.levels.DEBUG, {
    group = nil,
    title = text_title,
    message = text_content,
    timeout = 5000,
    anonymous = false,
    silent = false,
  })
end

---@param title                         string|unknown
---@param message                       unknown|nil
function M.log_silent(title, message)
  local text_title, text_content = "", "" ---@type string, string
  if type(title) == "string" then
    text_title = title
    text_content = format_message(message)
  else
    text_title = "debug"
    text_content = format_message(title)
  end

  vim.notify(text_content, vim.log.levels.DEBUG, {
    group = nil,
    title = text_title,
    message = text_content,
    timeout = 5000,
    anonymous = false,
    silent = true,
  })
end

---@param title                         string|unknown
---@param message                       unknown|nil
---@param filepath                      string
function M.log_to_file(title, message, filepath)
  local text_title, text_content = "", "" ---@type string, string
  if type(title) == "string" then
    text_title = title
    text_content = format_message(message)
  else
    text_title = "debug"
    text_content = format_message(title)
  end

  local timestamp = tostring(os.date("%Y-%m-%d %H:%M:%S")) ---@type string
  local log_line = string.format("[%s] [%s] %s\n", timestamp, text_title, text_content:gsub("\n", " "))
  local file = io.open(filepath, "a")
  if file then
    file:write(log_line)
    file:close()
  end
end

return M
