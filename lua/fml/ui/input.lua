local reporter = require("fml.core.reporter")

---@class fml.ui.Input
---@field public _nui_input             any|nil
---@field public title                  string
---@field public prompt                 string
---@field public position               "center"|"cursor"
---@field public cursor_col             integer
local M = {}
M.__index = M

---@class fml.ui.Input.IProps
---@field public title                  string
---@field public prompt                 string
---@field public position               "center"|"cursor"
---@field public cursor_col             integer

---@class fml.ui.Input.IOpenParams
---@field public value                  string
---@field public on_confirm             fun(next_value: string):nil

---@param props fml.ui.Input.IProps
---@return fml.ui.Input
function M.new(props)
  local self = setmetatable({}, M)

  self._nui_input = nil
  self.title = props.title
  self.prompt = props.prompt
  self.position = props.position
  self.cursor_col = props.cursor_col

  return self
end

function M:close()
  if self._nui_input ~= nil then
    local nui_input = self._nui_input
    self._nui_input = nil
    nui_input:unmount()
  end
end

---@param params fml.ui.Input.IOpenParams
---@return nil
function M:open(params)
  self:close()

  local title = self.title ---@type string
  local prompt = self.prompt ---@type string
  local cursor_col = self.cursor_col ---@type integer
  local initial_value = params.value ---@type string
  local on_confirm = params.on_confirm

  local ok_nui_input, Input = pcall(require, "nui.input")
  local ok_nui_autocmd, nui_autocmd = pcall(require, "nui.utils.autocmd")
  if not ok_nui_input then
    reporter.error({
      from = "fml.ui.input",
      subject = "open",
      message = "Cannot find nui.input",
      details = { title = title, value = initial_value, error = Input },
    })
    return nil
  end
  if not ok_nui_autocmd then
    reporter.error({
      from = "fml.ui.input",
      subject = "open",
      message = "Cannot find nui.utils.autocmd",
      details = { title = title, value = initial_value, error = nui_autocmd },
    })
    return nil
  end

  local event = nui_autocmd.event
  local relative = self.position == "center" and "win" or "cursor"
  local position = self.position == "center" and "50%" or { row = 1, col = 0 }
  local width_value = vim.api.nvim_strwidth(initial_value) ---@type integer
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
    default_value = initial_value,
    on_submit = on_confirm,
  })

  -- mount/open the component
  self._input = input
  input:mount()

  local function stopinsert()
    vim.cmd("stopinsert")
    vim.api.nvim_win_set_cursor(0, { 1, cursor_col })
  end

  local function on_quit()
    self:close()
  end

  vim.schedule(stopinsert)

  input:map("n", "<esc>", on_quit, { noremap = true, silent = true, desc = "input: discard changes" })
  input:map("n", "q", on_quit, { noremap = true, silent = true, desc = "input: discard changes" })
  input:on(event.BufLeave, on_quit, { once = true }) -- close when cursor leaves the buffer

  self._nui_input = input
end

---@return integer|nil
function M:get_bufnr()
  if self._nui_input == nil then
    return nil
  end
  return self._nui_input.bufnr
end

return M
