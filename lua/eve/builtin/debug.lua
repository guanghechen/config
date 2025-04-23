---@class eve.builtin.debug.ICmdParams
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

---@class eve.builtin.debug
local M = {}

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

---@param title                         string
---@param message                       unknown
function M.log(title, message)
  local text = format_message(message)
  vim.notify(text, vim.log.levels.DEBUG, {
    group = nil,
    title = title,
    message = text,
    timeout = 5000,
    anonymous = false,
    silent = false,
  })
end

---@param title                         string
---@param message                       unknown
function M.log_silent(title, message)
  local text = format_message(message)
  vim.notify(text, vim.log.levels.DEBUG, {
    group = nil,
    title = title,
    message = text,
    timeout = 5000,
    anonymous = false,
    silent = true,
  })
end

---@param opts                          eve.builtin.debug.ICmdParams
---@return string
function M.cmd(opts)
  local args = vim.deepcopy(opts.args or {})
  local cmd = "" ---@type string
  do
    local _cmd = opts.cmd ---@type string|string[]
    if type(_cmd) == "string" then
      cmd = _cmd
    elseif type(_cmd) == "table" then
      vim.list_extend(args, _cmd, 2)
      cmd = _cmd[1]
    end
    args = vim.tbl_map(tostring, args)
  end

  local lines = { cmd } ---@type string[]
  for _, arg in ipairs(args or {}) do
    arg = arg:find("[%$%s%?]") and vim.fn.shellescape(arg) or arg
    if #arg + #lines[#lines] > 40 then
      lines[#lines] = lines[#lines] .. " \\"
      table.insert(lines, "  " .. arg)
    else
      lines[#lines] = lines[#lines] .. " " .. arg
    end
  end
  local props = vim.deepcopy(opts.props or {})
  props.cwd = props.cwd or vim.fn.fnamemodify(opts.cwd or vim.uv.cwd() or ".", ":~")
  local prop_keys = vim.tbl_keys(props) ---@type string[]
  table.sort(prop_keys)
  local prop_lines = {} ---@type string[]
  for _, key in ipairs(prop_keys) do
    table.insert(prop_lines, ("- **%s**: %s"):format(key, props[key]))
  end

  lines = {
    opts.header or "",
    table.concat(prop_lines, "\n"),
    "```sh",
    table.concat(lines, " \n"),
    "```",
    opts.footer or "",
  }
  if opts.title and not opts.notify then
    table.insert(lines, 1, ("# %s\n"):format(opts.title))
  end

  local msg = vim.trim(table.concat(lines, "\n")):gsub("\n\n+", "\n\n") ---@type string

  if opts.notify ~= false then
    vim.schedule(function()
      local id = opts.group and ("eve.builtin.debug.cmd." .. cmd) or nil
      local level = opts.level or vim.log.levels.INFO
      local title = opts.title or id or "Cmd Debug"
      vim.notify(msg, level, {
        group = id,
        title = title,
        message = msg,
        timeout = 5000,
        anonymous = false,
      })
    end)
  end
  return msg
end

return M
