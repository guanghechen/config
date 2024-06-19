---@class kyokuya.component.IInputOptions
---@field public icon string
---@field public title string
---@field public value string
---@field public on_confirm fun(next_value: string):nil

---@class kyokuya.component.Input
---@field input any|nil
local M = {}
M.__index = M

---@return kyokuya.component.Input
function M.new()
  local self = setmetatable({}, M)

  self.input = nil

  return self
end

---@param opts kyokuya.component.IInputOptions
---@return nil
function M:open(opts)
  local icon = opts.icon
  local title = "[" .. opts.title .. "]"
  local value = opts.value
  local on_confirm = opts.on_confirm

  local Input = require("nui.input")
  local event = require("nui.utils.autocmd").event
  local input = Input({
    relative = "cursor",
    position = {
      row = 1,
      col = 0,
    },
    size = {
      width = (#value < #title and #title or #value) + 5,
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
    prompt = icon .. " ",
    default_value = value,
    on_submit = on_confirm,
  })

  -- mount/open the component
  input:mount()

  local function stopinsert()
    vim.cmd("stopinsert")
  end

  local function on_quit()
    input:unmount()
    self.input = nil
  end

  vim.schedule(stopinsert)

  -- close on <esc> in normal mode
  input:map("n", "<esc>", on_quit, { noremap = true, silent = true, desc = "input: discard changes" })

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
