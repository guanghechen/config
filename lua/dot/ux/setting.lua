local __module_name__ = "dot.ux.setting" ---@type string

---@class dot.ux.ISetting
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil
---@field public open                   fun(self: dot.ux.ISetting, params: dot.ux.setting.IOpenParams): nil
---@field public close                  fun(self: dot.ux.ISetting): nil

---@class dot.ux.setting.IOpenParams
---@field public initial_value          dot.t.T
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public height                 ?number
---@field public win_cursor_row         ?integer
---@field public win_cursor_col         ?integer

---@class dot.ux.Setting : dot.ux.ISetting, dot.ux.Textarea
local M = {}
M.__index = M
setmetatable(M, dot.ux.Textarea)

---@class dot.ux.setting.IProps
---@field public position               ark.e.BoxPosition
---@field public width                  ?number
---@field public height                 ?number
---@field public title                  ?string
---@field public max_width              ?number
---@field public max_height             ?number
---@field public min_width              ?number
---@field public min_height             ?number
---@field public keymaps                ?ark.t.IKeymap[]
---@field public win_opts               ?table<string, any>
---@field public validate               ?fun(value: dot.t.T): string|nil
---@field public on_close               ?fun(): nil
---@field public on_confirm             fun(value: dot.t.T): boolean

---@param props                         dot.ux.setting.IProps
---@return dot.ux.Setting
function M.new(props)
  local position = props.position ---@type ark.e.BoxPosition
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
  local max_width = props.max_width ---@type number|nil
  local max_height = props.max_height ---@type number|nil
  local min_width = props.min_width ---@type number|nil
  local min_height = props.min_height ---@type number|nil
  local keymaps = props.keymaps or {} ---@type ark.t.IKeymap[]
  local title = props.title ---@type string|nil
  local win_opts = props.win_opts or {} ---@type table<string, any>

  local validate_from_props = props.validate ---@type (fun(value: dot.t.T): string)|nil
  local on_close_from_props = props.on_close ---@type (fun(): nil)
  local on_confirm_from_props = props.on_confirm ---@type fun(text: dot.t.T): boolean

  ---@param lines                       string[]
  ---@return string|nil
  local function validate(lines)
    local text = table.concat(lines, "\n") ---@type string
    local ok, data = pcall(function()
      return vim.json.decode(text, {
        luanil = {
          object = true,
          array = true,
        },
      })
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
      return vim.json.decode(text, {
        luanil = {
          object = true,
          array = true,
        },
      })
    end)

    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "on_confirm",
        message = "Failed to parse json string.",
        details = { text = text, data = data },
      })
      return false
    end

    return on_confirm_from_props(data)
  end

  local textarea = dot.ux.Textarea.new({
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
  ---@cast self                         dot.ux.Setting

  return self
end

---@param params                        dot.ux.setting.IOpenParams
---@return nil
function M:open(params)
  local text = vim.json.encode(params.initial_value, { indent = "  ", sort_keys = false }) ---@type string
  local lines = vim.split(text, "\n", { plain = true }) ---@type string[]

  ---@type dot.ux.textarea.IOpenParams
  local opts = {
    initial_lines = lines,
    row = params.row,
    col = params.col,
    height = params.height or self.height or #lines + 1,
    width = params.width,
    win_cursor_col = params.win_cursor_col,
    win_cursor_row = params.win_cursor_row,
  }
  dot.ux.Textarea.open(self, opts)
end

return M
