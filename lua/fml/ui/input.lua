local std_array = require("fml.std.array")
local Textarea = require("fml.ui.textarea")

---@class fml.ui.Input : fml.types.ui.IInput, fml.ui.Textarea
local M = {}
M.__index = M
setmetatable(M, { __index = Textarea })

---@class fml.ui.input.IProps
---@field public position               fml.enums.BoxPosition
---@field public width                  ?number
---@field public title                  ?string
---@field public max_width              ?number
---@field public min_width              ?number
---@field public keymaps                ?fml.types.IKeymap[]
---@field public win_opts               ?table<string, any>
---@field public validate               ?fun(value: string): string|nil
---@field public on_close               ?fun(): nil
---@field public on_confirm             fun(value: string): nil

---@param props                         fml.ui.input.IProps
---@return fml.ui.Input
function M.new(props)
  local position = props.position ---@type fml.enums.BoxPosition
  local width = props.width ---@type number|nil
  local max_width = props.max_width ---@type number|nil
  local min_width = props.min_width ---@type number|nil
  local title = props.title ---@type string|nil

  ---@type table<string, any>
  local win_opts = vim.tbl_extend("force", {
    cursorline = false,
    number = false,
    relativenumber = false,
    signcolumn = "yes",
  }, props.win_opts or {})

  local validate_from_props = props.validate ---@type (fun(value: string): string)|nil
  local on_close_from_props = props.on_close ---@type (fun(): nil)
  local on_confirm_from_props = props.on_confirm ---@type fun(text: string): nil

  local self
  ---@cast self fml.ui.Input

  ---@return nil
  local handle_close = function()
    self.on_close()
  end

  ---@return nil
  local handle_confirm = function()
    self.on_confirm()
  end

  ---@type fml.types.IKeymap[]
  local builtin_keymaps = {
    { modes = { "n" }, key = "<esc>", desc = "input: quit", callback = handle_close },
    { modes = { "i" }, key = "<cr>", desc = "input: confirm", callback = handle_confirm },
  }
  local keymaps = std_array.concat(builtin_keymaps, props.keymaps) ---@type fml.types.IKeymap[]

  ---@param lines                       string[]
  ---@return string|nil
  local function validate(lines)
    local text = lines[1] ---@type string
    if type(validate_from_props) == "function" then
      return validate_from_props(text)
    end
  end

  ---@param lines                       string[]
  local function on_confirm(lines)
    local text = lines[1] ---@type string
    on_confirm_from_props(text)
  end

  local textarea = Textarea.new({
    position = position,
    width = width,
    height = 1,
    max_width = max_width,
    max_height = 1,
    min_width = min_width,
    min_height = 1,
    title = title,
    filetype = "text",
    keymaps = keymaps,
    win_opts = win_opts,
    validate = validate,
    on_close = on_close_from_props,
    on_confirm = on_confirm,
  })

  self = setmetatable(textarea, M)
  ---@cast self fml.ui.Input

  return self
end

---@param params                        fml.types.ui.input.IOpenParams
---@return nil
function M:open(params)
  local text = params.initial_value ---@type string

  ---@type fml.types.ui.textarea.IOpenParams
  local opts = {
    initial_lines = { text },
    row = params.row,
    col = params.col,
    width = params.width or vim.fn.strwidth(text) + 10,
    win_cursor_col = params.win_cursor_col,
    win_cursor_row = params.win_cursor_row,
  }
  Textarea.open(self, opts)
end

return M
