---@class kyokuya.component.ITextareaOptions
---@field public title string
---@field public value string[]
---@field public position "center"|"cursor"
---@field public cursor_row integer
---@field public cursor_col integer
---@field public width? integer
---@field public height? integer
---@field public win_options? table<string, any>
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
  local title = opts.title ---@type string
  local value = opts.value ---@type string[]
  local cursor_row = opts.cursor_row ---@type integer
  local cursor_col = opts.cursor_col ---@type integer

  local Popup = require("nui.popup")
  local event = require("nui.utils.autocmd").event

  local relative = opts.position == "center" and "win" or "cursor"
  local position = opts.position == "center" and "50%" or { row = 1, col = 0 }
  local popup = Popup({
    enter = true,
    focusable = true,
    relative = relative,
    position = position,
    size = {
      width = opts.width or "80%",
      height = opts.height or #value,
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
    win_options = vim.tbl_extend("force", {
      cursorline = true,
      number = true,
      relativenumber = true,
      wrap = false,
      winblend = 10,
      winhighlight = "Normal:Normal",
    }, opts.win_options or {}),
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