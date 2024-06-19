---@class kyokuya.component.ITextareaOptions
---@field public icon string
---@field public title string
---@field public value string[]
---@field public cursor_row integer
---@field public cursor_col integer
---@field public on_confirm fun(next_value: string[]):nil

---@class kyokuya.component.Textarea
---@field popup any|nil
local M = {}
M.__index = M

---@return kyokuya.component.Textarea
function M.new()
  local self = setmetatable({}, M)

  self.popup = nil

  return self
end

---@param opts kyokuya.component.ITextareaOptions
---@return nil
function M:open(opts)
  local icon = opts.icon
  local title = icon .. " " .. opts.title .. " "
  local value = opts.value
  local cursor_row = opts.cursor_row ---@type integer
  local cursor_col = opts.cursor_col ---@type integer

  local Popup = require("nui.popup")
  local event = require("nui.utils.autocmd").event
  local popup = Popup({
    enter = true,
    focusable = true,
    relative = "cursor",
    position = {
      row = 1,
      col = 0,
    },
    size = {
      width = 72,
      height = #value + 2,
    },
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
      },
      padding = {
        top = 0,
        bottom = 0,
        left = 1,
        right = 1,
      },
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal",
    },
  })

  -- mount/open the component
  popup:mount()

  local function stopinsert()
    vim.cmd("stopinsert")
    vim.api.nvim_win_set_cursor(0, { cursor_row, cursor_col })
  end

  local function on_quit()
    popup:unmount()
    self.popup = nil
  end

  local function on_confirm()
    local next_value = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false) ---@type string[]
    on_quit()
    opts.on_confirm(next_value)
  end

  vim.schedule(stopinsert)

  popup:map("n", "<esc>", on_quit, { noremap = true, silent = true, desc = "popup: discard changes" })
  popup:map("n", "q", on_quit, { noremap = true, silent = true, desc = "popup: discard changes" })
  popup:map("n", "<cr>", on_confirm, { noremap = true, silent = true, desc = "popup: save changes" })

  ---close when cursor leaves the buffer
  popup:on(event.BufDelete, on_quit, { once = true })

  ---Insert the initial value
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, value)

  self.popup = popup
end

---@return integer|nil
function M:get_bufnr()
  if self.popup == nil then
    return nil
  end
  return self.popup.bufnr
end

return M
