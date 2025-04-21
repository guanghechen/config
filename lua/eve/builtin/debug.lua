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

---@param value any|nil
local function better_stringify(value)
  if value == nil then
    return "nil"
  end

  if type(value) == "string" then
    return value
  end

  return vim.inspect(value)
end

function M.log(...)
  local elements = { ... } ---@type any[]
  if #elements <= 0 then
    return
  end

  local text = "" ---@type string
  if #elements == 1 then
    text = better_stringify(elements[1])
  else
    for _, element in ipairs(elements) do
      text = text .. " " .. better_stringify(element) ---@type string
    end
    text = #text > 0 and text:sub(1) or "" ---@type string
  end
  eve.notifier.debug(nil, "Debug", text, 5000)
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
      local level = eve.notifier.resolve_level(opts.level or vim.log.levels.INFO)
      local title = opts.title or id or "Cmd Debug"
      eve.notifier.notify(level, id, title, msg, 5000)
    end)
  end
  return msg
end

return M
