local constant = require("fml.constant")
local std_array = require("fml.std.array")
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
  local actions = {
    apply_prev_input = function()
      local input_cur = state.input:snapshot() ---@type string
      local input_history = state.input_history ---@type fml.types.collection.IHistory|nil
      if input_history ~= nil then
        if input_history:is_top() then
          local present = input_history:present() ---@type string|nil
          local prefix = constant.EDITING_INPUT_PREFIX ---@type string
          local input_cur_with_prefix = prefix .. input_cur ---@type string
          if present == nil or #present < #prefix or string.sub(present, 1, #prefix) ~= prefix then
            input_history:push(input_cur_with_prefix)
          else
            input_history:update_top(input_cur_with_prefix)
          end
        end

        while true do
          local input_next = input_history:back() ---@type string|nil
          if input_next == nil then
            break
          end

          if input_next ~= input_cur then
            self:reset_input(input_next)
            return
          end

          if input_history:is_bottom() then
            break
          end
        end
      end
    end,
    apply_next_input = function()
      local input_cur = state.input:snapshot() ---@type string
      local input_history = state.input_history ---@type fml.types.collection.IHistory|nil
      if input_history ~= nil then
        local prefix = constant.EDITING_INPUT_PREFIX ---@type string
        local input_next = input_history:forward() ---@type string|nil
        if input_history:is_top() and input_next ~= nil then
          if #input_next >= #prefix and string.sub(input_next, 1, #prefix) == prefix then
            input_next = string.sub(input_next, #prefix + 1)
          end
        end

        if input_next ~= nil and input_next ~= input_cur then
          self:reset_input(input_next)
        end
      end
    end,
  }

  ---@type fml.types.IKeymap[]
  local keymaps = state.input_history ~= nil
      and std_array.concat({
        { modes = { "i", "n", "v" }, key = "<C-j>", callback = actions.apply_next_input, desc = "select: last input" },
        { modes = { "i", "n", "v" }, key = "<C-k>", callback = actions.apply_prev_input, desc = "select: next input" },
      }, props.keymaps)
    or props.keymaps

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

---@param input                         string
---@return nil
function M:reset_input(input)
  self.state.input:next(input)

  local bufnr = self.bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
    if #lines ~= 1 or lines[1] ~= input then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { input })
    end
  end
end

return M
