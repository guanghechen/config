---@class ghc.ui.Textarea
---@field private _nui_popup            any|nil
---@field public title                  string
---@field public position               "center"|"cursor"
---@field public default_width          integer
---@field public default_height         integer
---@field public default_win_options    table<string, any>
local M = {}
M.__index = M

---@class ghc.ui.textarea.IProps
---@field public title                  string
---@field public position               "center"|"cursor"
---@field public width                  ?integer
---@field public height                 ?integer
---@field public win_options            ?table<string, any>

---@class ghc.ui.textarea.IOpenParams
---@field public title                  ?string
---@field public position               ?"center"|"cursor"
---@field public value                  string[]
---@field public cursor_row             integer
---@field public cursor_col             integer
---@field public width                  ?integer
---@field public height                 ?integer
---@field public win_options            ?table<string, any>
---@field public on_confirm              fun(next_value: string[]): nil

---@param props ghc.ui.textarea.IProps
---@return ghc.ui.Textarea
function M.new(props)
  local self = setmetatable({}, M)

  self._nui_popup = nil
  self.title = props.title
  self.position = props.position
  self.default_width = props.width or 80
  self.default_height = props.height or 5
  self.default_win_options = props.win_options or {}

  return self
end

---@param params ghc.ui.textarea.IOpenParams
---@return nil
function M:open(params)
  local title = params.title or self.title ---@type string
  local position = params.position or self.position ---@type "center"|"cursor"
  local cursor_row = params.cursor_row ---@type integer
  local cursor_col = params.cursor_col ---@type integer
  local initial_value = params.value ---@type string[]

  local ok_nui_popup, Popup = pcall(require, "nui.popup")
  local ok_nui_autocmd, nui_autocmd = pcall(require, "nui.utils.autocmd")
  if not ok_nui_popup then
    fml.reporter.error({
      from = "ghc.ui.popup",
      subject = "open",
      message = "Cannot find nui.popup",
      details = { title = title, value = initial_value, error = Popup },
    })
    return nil
  end
  if not ok_nui_autocmd then
    fml.reporter.error({
      from = "ghc.ui.popup",
      subject = "open",
      message = "Cannot find nui.utils.autocmd",
      details = { title = title, value = initial_value, error = nui_autocmd },
    })
    return nil
  end

  local event = nui_autocmd.event
  local cfg_relative = position == "center" and "win" or "cursor"
  local cfg_position = position == "center" and "50%" or { row = 1, col = 0 }
  local popup = Popup({
    enter = true,
    focusable = true,
    relative = cfg_relative,
    position = cfg_position,
    size = {
      width = params.width or self.default_width,
      height = params.height or self.default_height,
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
    }, params.win_options or self.default_win_options),
  })

  -- mount/open the component
  self._nui_popup = popup
  popup:mount()

  local function stopinsert()
    vim.cmd("stopinsert")
    vim.api.nvim_win_set_cursor(0, { cursor_row, cursor_col })
  end

  local function on_quit()
    self:close()
  end

  local function on_confirm()
    local next_value = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false) ---@type string[]
    on_quit()
    params.on_confirm(next_value)
  end

  vim.schedule(stopinsert)

  popup:map("n", "<esc>", on_quit, { noremap = true, silent = true, desc = "popup: discard changes" })
  popup:map("n", "q", on_quit, { noremap = true, silent = true, desc = "popup: discard changes" })
  popup:map("n", "<cr>", on_confirm, { noremap = true, silent = true, desc = "popup: save changes" })
  popup:on(event.BufDelete, on_quit, { once = true })

  ---Insert the initial value
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, initial_value)

  self._nui_popup = popup
end

---@return integer|nil
function M:get_bufnr()
  if self._nui_popup == nil then
    return nil
  end
  return self._nui_popup.bufnr
end

function M:close()
  if self._nui_popup ~= nil then
    local nui_popup = self._nui_popup
    self._nui_popup = nil
    nui_popup:unmount()
  end
end

return M
