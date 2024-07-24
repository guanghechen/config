local constant = require("fml.constant")
local util = require("fml.std.util")
local signcolumn = require("fml.ui.signcolumn")

---@class fml.ui.select.Input : fml.types.ui.select.IInput
---@field protected bufnr               integer|nil
---@field protected state               fml.types.ui.select.IState
---@field protected rendering           boolean
---@field protected keymaps             fml.types.IKeymap[]
local M = {}
M.__index = M

---@class fml.ui.select.input.IProps
---@field public state                  fml.types.ui.select.IState
---@field public keymaps                fml.types.IKeymap[]

---@param props                         fml.ui.select.input.IProps
---@return fml.ui.select.Input
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.select.IState
  local keymaps = props.keymaps ---@type fml.types.IKeymap[]

  self.bufnr = nil
  self.state = state
  self.rendering = false
  self.keymaps = keymaps
  return self
end

---@return integer
function M:create_buf_as_needed()
  if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
    return self.bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = constant.FT_SELECT_INPUT
  vim.bo[bufnr].swapfile = false

  local state = self.state ---@type fml.types.ui.select.IState
  local group = util.augroup(state.uuid .. ":select_input")
  local queued = false ---@type boolean
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      vim.fn.sign_place(bufnr, "", signcolumn.names.select_input_cursor, bufnr, { lnum = 1 })
      if not queued then
        queued = true
        vim.defer_fn(function()
          queued = false
          if vim.api.nvim_buf_is_valid(bufnr) then
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
            local next_input = table.concat(lines, "\n", 1, 1) ---@type string
            state.input:next(next_input)
          end
        end, 20)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete" }, {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      self.bufnr = nil
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })

  local input = state.input:snapshot() ---@type string
  vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { input })
  util.bind_keys(self.keymaps, { bufnr = bufnr, noremap = true, silent = true })

  self.bufnr = bufnr
  vim.fn.sign_place(bufnr, "", signcolumn.names.select_input_cursor, bufnr, { lnum = 1 })
  return bufnr
end

return M
