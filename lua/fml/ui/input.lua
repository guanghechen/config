---@class fml.ui.Input
---@field input any|nil
local M = {}
M.__index = M

---@class fml.ui.Input.IProps
---@field public title                  string
---@field public prompt                 string
---@field public value                  string
---@field public position               "center"|"cursor"
---@field public cursor_col             integer
---@field public on_confirm             fun(next_value: string):nil

---@return fml.ui.Input
function M.new()
  local self = setmetatable({}, M)

  self.input = nil

  return self
end

---@param props fml.ui.Input.IProps
---@return nil
function M:open(props)
  local title = props.title ---@type string
  local prompt = props.prompt ---@type string
  local value = props.value ---@type string
  local cursor_col = props.cursor_col ---@type integer
  local on_confirm = props.on_confirm

  local Input = require("nui.input")
  local event = require("nui.utils.autocmd").event

  local relative = props.position == "center" and "win" or "cursor"
  local position = props.position == "center" and "50%" or { row = 1, col = 0 }
  local width_value = vim.api.nvim_strwidth(value) ---@type integer
  local width_title = vim.api.nvim_strwidth(title) ---@type integer
  local input = Input({
    relative = relative,
    position = position,
    size = {
      width = (width_value < width_title and width_title or width_value) + 2,
      height = 1,
    },
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
      },
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal",
    },
  }, {
    prompt = prompt,
    default_value = value,
    on_submit = on_confirm,
  })

  -- mount/open the component
  input:mount()

  local function stopinsert()
    vim.cmd("stopinsert")
    vim.api.nvim_win_set_cursor(0, { 1, cursor_col })
  end

  local function on_quit()
    input:unmount()
    self.input = nil
  end

  vim.schedule(stopinsert)

  -- close on <esc> in normal mode
  input:map("n", "<esc>", on_quit, { noremap = true, silent = true, desc = "input: discard changes" })
  input:map("n", "q", on_quit, { noremap = true, silent = true, desc = "input: discard changes" })

  -- close when cursor leaves the buffer
  input:on(event.BufLeave, on_quit, { once = true })

  self.input = input
end

---@return integer|nil
function M:get_bufnr()
  if self.input == nil then
    return nil
  end
  return self.input.bufnr
end

return M
