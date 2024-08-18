local constant = require("fml.constant")
local std_array = require("fml.std.array")
local oxi = require("fml.std.oxi")
local scheduler = require("fml.std.scheduler")
local util = require("fml.std.util")
local watch_observables = require("fml.fn.watch_observables")
local signcolumn = require("fml.ui.signcolumn")

---@class fml.ui.search.Input : fml.types.ui.search.IInput
---@field protected _autocmd_group      integer
---@field protected _bufnr              integer|nil
---@field protected _extmark_nr         integer|nil
---@field protected _input_scheduler    fml.std.scheduler.IScheduler
---@field protected _keymaps            fml.types.IKeymap[]
local M = {}
M.__index = M

local extmark_nsnr = vim.api.nvim_create_namespace("fml.ui.search.input") ---@type integer

---@class fml.ui.search.input.IProps
---@field public state                  fml.types.ui.search.IState
---@field public keymaps                fml.types.IKeymap[]

---@param props                         fml.ui.search.input.IProps
---@return fml.ui.search.Input
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.search.IState
  local input_history = state.input_history ---@type fml.types.collection.IHistory|nil
  local autocmd_group = util.augroup(state.uuid .. ":search_input") ---@type integer

  local actions = {
    apply_prev_input = function()
      local input_cur = state.input:snapshot() ---@type string
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
        { modes = { "i", "n", "v" }, key = "<C-j>", callback = actions.apply_prev_input, desc = "search: next input" },
        { modes = { "i", "n", "v" }, key = "<C-k>", callback = actions.apply_next_input, desc = "search: last input" },
      }, props.keymaps)
    or props.keymaps

  local input_scheduler = scheduler.throttle({
    name = "fml.ui.search.input.on_change",
    delay = 32,
    fn = function(callback)
      ---@diagnostic disable-next-line: invisible
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        if vim.api.nvim_buf_is_valid(bufnr) then
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
          local next_input = table.concat(lines, "\n") ---@type string
          self.state.input:next(next_input)
        end
      end
      callback(true)
    end,
  })

  self.state = state
  self._autocmd_group = autocmd_group
  self._bufnr = nil
  self._extmark_nr = nil
  self._input_scheduler = input_scheduler
  self._keymaps = keymaps

  watch_observables({ state.dirty_preview }, function()
    local dirty = state.dirty_preview:snapshot() ---@type boolean|nil
    local visible = state.visible:snapshot() ---@type boolean
    if visible and dirty then
      self:set_virtual_text()
    end
  end, true)

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

  local state = self.state ---@type fml.types.ui.search.IState
  local input = state.input:snapshot() ---@type string
  local lines = oxi.parse_lines(input) ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, state.enable_multiline_input and lines or { lines[1] })
  vim.fn.sign_place(bufnr, "", signcolumn.names.search_input_cursor, bufnr, { lnum = 1 })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = self._autocmd_group,
    buffer = bufnr,
    callback = function()
      vim.fn.sign_place(bufnr, "", signcolumn.names.search_input_cursor, bufnr, { lnum = 1 })
      self._input_scheduler:schedule()
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
  return bufnr
end

---@return nil
function M:destroy()
  local bufnr = self._bufnr ---@type integer|nil
  self._bufnr = nil
  self._input_scheduler.cancel()

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M:set_virtual_text()
  local state = self.state ---@type fml.types.ui.search.IState
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local total = #state.items ---@type integer
    local lnum = state:get_current_lnum() ---@type integer
    lnum = lnum > total and total or lnum

    if self._extmark_nr then
      vim.api.nvim_buf_del_extmark(bufnr, extmark_nsnr, self._extmark_nr)
      self._extmark_nr = nil
    end

    ---! Set the extmark with the right-aligned virtual text
    self._extmark_nr = vim.api.nvim_buf_set_extmark(bufnr, extmark_nsnr, 0, 0, {
      virt_text = { { "" .. lnum .. " / " .. total, "Comment" } },
      virt_text_pos = "right_align",
    })
  end
end

---@param input                         string|nil
---@return nil
function M:reset_input(input)
  local state = self.state ---@type fml.types.ui.search.IState
  local next_input = input or state.input:snapshot() ---@type string
  state.input:next(next_input)

  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = oxi.parse_lines(next_input) ---@type string[]
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, state.enable_multiline_input and lines or { lines[1] })
  end
end

return M
