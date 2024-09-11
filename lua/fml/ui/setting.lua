local Textarea = require("fml.ui.textarea")
local json = require("eve.std.json")
local reporter = require("eve.std.reporter")

---@class fml.ui.Setting : fml.types.ui.ISetting, fml.ui.Textarea
local M = {}
M.__index = M
setmetatable(M, { __index = Textarea })

---@class fml.ui.setting.IProps
---@field public position               eve.enums.BoxPosition
---@field public width                  ?number
---@field public height                 ?number
---@field public title                  ?string
---@field public max_width              ?number
---@field public max_height             ?number
---@field public min_width              ?number
---@field public min_height             ?number
---@field public keymaps                ?eve.types.ux.IKeymap[]
---@field public win_opts               ?table<string, any>
---@field public validate               ?fun(value: eve.types.T): string|nil
---@field public on_close               ?fun(): nil
---@field public on_confirm             fun(value: eve.types.T): boolean

---@param props                         fml.ui.setting.IProps
---@return fml.ui.Setting
function M.new(props)
  local position = props.position ---@type eve.enums.BoxPosition
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
  local max_width = props.max_width ---@type number|nil
  local max_height = props.max_height ---@type number|nil
  local min_width = props.min_width ---@type number|nil
  local min_height = props.min_height ---@type number|nil
  local keymaps = props.keymaps or {} ---@type eve.types.ux.IKeymap[]
  local title = props.title ---@type string|nil
  local win_opts = props.win_opts or {} ---@type table<string, any>

  local validate_from_props = props.validate ---@type (fun(value: eve.types.T): string)|nil
  local on_close_from_props = props.on_close ---@type (fun(): nil)
  local on_confirm_from_props = props.on_confirm ---@type fun(text: eve.types.T): boolean

  ---@param lines                       string[]
  ---@return string|nil
  local function validate(lines)
    local text = table.concat(lines, "\n") ---@type string
    local ok, data = pcall(function()
      return json.parse(text)
    end)

    if not ok then
      return "Invalid json"
    end

    if type(validate_from_props) == "function" then
      return validate_from_props(data)
    end
  end

  ---@param lines                       string[]
  ---@return boolean
  local function on_confirm(lines)
    local text = table.concat(lines, "\n") ---@type string
    local ok, data = pcall(function()
      return json.parse(text)
    end)

    if not ok then
      reporter.error({
        from = "fml.ui.setting",
        subject = "on_confirm",
        message = "Failed to parse json string.",
        details = { text = text, data = data },
      })
      return false
    end

    return on_confirm_from_props(data)
  end

  local textarea = Textarea.new({
    position = position,
    width = width,
    height = height,
    max_width = max_width,
    max_height = max_height,
    min_width = min_width,
    min_height = min_height,
    title = title,
    filetype = "json",
    keymaps = keymaps,
    win_opts = win_opts,
    validate = validate,
    on_close = on_close_from_props,
    on_confirm = on_confirm,
  })

  local self = setmetatable(textarea, M)
  ---@cast self fml.ui.Setting

  return self
end

---@param params                        fml.types.ui.setting.IOpenParams
---@return nil
function M:open(params)
  local lines = json.stringify_prettier_lines(params.initial_value) ---@type string[]
  ---@type fml.types.ui.textarea.IOpenParams
  local opts = {
    initial_lines = lines,
    row = params.row,
    col = params.col,
    height = params.height or self.height or #lines + 1,
    width = params.width,
    win_cursor_col = params.win_cursor_col,
    win_cursor_row = params.win_cursor_row,
  }
  Textarea.open(self, opts)
end

return M
