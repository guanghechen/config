local constant = require("fml.constant")
local std_array = require("fml.std.array")
local util = require("fml.std.util")
local signcolumn = require("fml.ui.signcolumn")

---@class fml.ui.search.Input : fml.types.ui.search.IInput
---@field protected _input              fml.types.collection.IObservable
---@field protected _autocmd_group      integer
---@field protected _bufnr              integer|nil
---@field protected _rendering          boolean
---@field protected _keymaps            fml.types.IKeymap[]
local M = {}
M.__index = M

---@class fml.ui.search.input.IProps
---@field public uuid                   string
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public keymaps                fml.types.IKeymap[]

---@param props                         fml.ui.search.input.IProps
---@return fml.ui.search.Input
function M.new(props)
  local self = setmetatable({}, M)

  local uuid = props.uuid ---@type string
  local input = props.input ---@type fml.types.collection.IObservable
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local autocmd_group = util.augroup(uuid .. ":search_input") ---@type integer

  local actions = {
    apply_prev_input = function()
      local input_cur = input:snapshot() ---@type string
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
      local input_cur = input:snapshot() ---@type string
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
  local keymaps = input_history ~= nil
      and std_array.concat({
        { modes = { "i", "n", "v" }, key = "<C-j>", callback = actions.apply_next_input, desc = "search: last input" },
        { modes = { "i", "n", "v" }, key = "<C-k>", callback = actions.apply_prev_input, desc = "search: next input" },
      }, props.keymaps)
    or props.keymaps

  self._input = input
  self._autocmd_group = autocmd_group
  self._bufnr = nil
  self._rendering = false
  self._keymaps = keymaps
  return self
end

---@return integer
function M:create_buf_as_needed()
  if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
    return self._bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = constant.FT_SEARCH_INPUT
  vim.bo[bufnr].swapfile = false

  util.bind_keys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  local queued = false ---@type boolean
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = self._autocmd_group,
    buffer = bufnr,
    callback = function()
      vim.fn.sign_place(bufnr, "", signcolumn.names.search_input_cursor, bufnr, { lnum = 1 })
      if not queued then
        queued = true
        vim.defer_fn(function()
          queued = false
          if vim.api.nvim_buf_is_valid(bufnr) then
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
            local next_input = table.concat(lines, "\n", 1, 1) ---@type string
            self._input:next(next_input)
          end
        end, 20)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete" }, {
    group = self._autocmd_group,
    buffer = bufnr,
    once = true,
    callback = function()
      self._bufnr = nil
      vim.api.nvim_del_augroup_by_id(self._autocmd_group)
    end,
  })

  local input = self._input:snapshot() ---@type string
  vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { input })
  vim.fn.sign_place(bufnr, "", signcolumn.names.search_input_cursor, bufnr, { lnum = 1 })
  return bufnr
end

---@return nil
function M:destroy()
  local bufnr = self._bufnr ---@type integer|nil
  self._bufnr = nil

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param input                         string|nil
---@return nil
function M:reset_input(input)
  local next_input = input or self._input:snapshot() ---@type string
  self._input:next(next_input)

  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
    if #lines ~= 1 or lines[1] ~= next_input then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { next_input })
    end
  end
end

return M
