local Subscriber = require("fc.collection.subscriber")
local constant = require("fml.constant")
local std_array = require("fc.std.array")
local oxi = require("fc.std.oxi")
local scheduler = require("fc.std.scheduler")
local util = require("fml.std.util")
local signcolumn = require("fml.ui.signcolumn")

---@class fml.ui.search.Input : fml.types.ui.search.IInput
---@field protected _autocmd_group      integer
---@field protected _bufnr              integer|nil
---@field protected _extmark_nr         integer|nil
---@field protected _input_scheduler    fc.std.scheduler.IScheduler
---@field protected _keymaps            fml.types.IKeymap[]
local M = {}
M.__index = M

local EDITING_PREFIX = constant.EDITING_INPUT_PREFIX ---@type string
local EXTMARK_NSNR = vim.api.nvim_create_namespace("fml.ui.search.input") ---@type integer

---@class fml.ui.search.input.IProps
---@field public state                  fml.types.ui.search.IState
---@field public keymaps                fml.types.IKeymap[]

---@param props                         fml.ui.search.input.IProps
---@return fml.ui.search.Input
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.search.IState
  local input_history = state.input_history ---@type fc.types.collection.IHistory|nil
  local autocmd_group = util.augroup(state.uuid .. ":search_input") ---@type integer

  local actions = {
    apply_prev_input = function()
      if input_history == nil then
        return
      end

      local text = input_history:backward() ---@type string|nil
      if text ~= nil then
        self:reset_input(text)
      end
    end,
    apply_next_input = function()
      if input_history == nil or input_history:is_top() then
        return
      end

      local text = input_history:forward() ---@type string|nil
      if text ~= nil then
        self:reset_input(text)
      end
    end,
  }

  ---@type fml.types.IKeymap[]
  local keymaps = input_history ~= nil
      and std_array.concat({
        { modes = { "i", "n", "v" }, key = "<C-j>", callback = actions.apply_next_input, desc = "search: next input" },
        { modes = { "i", "n", "v" }, key = "<C-k>", callback = actions.apply_prev_input, desc = "search: last input" },
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

  state.dirtier_preview:subscribe(Subscriber.new({
    on_next = function()
      local is_preview_dirty = state.dirtier_preview:is_dirty() ---@type boolean
      local visible = state.visible:snapshot() ---@type boolean
      if visible and is_preview_dirty then
        self:set_virtual_text()
      end
    end,
  }))

  state.input:subscribe(Subscriber.new({
    on_next = function()
      if input_history ~= nil then
        local input_cur = state.input:snapshot() ---@type string
        local input_present = input_history:present() ---@type string|nil, integer
        if input_present ~= input_cur then
          local input_top = input_history:top() ---@type string|nil
          if input_top ~= nil and util.is_editing_text(input_top) then
            input_history:update_top(EDITING_PREFIX .. input_cur)
          else
            input_history:go(math.huge)
            input_history:push(EDITING_PREFIX .. input_cur)
          end
        end
      end
    end,
  }))

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
    local total = #state.items or 0 ---@type integer
    local lnum = state:get_current_lnum() or 1 ---@type integer
    lnum = lnum > total and total or lnum

    if self._extmark_nr then
      vim.api.nvim_buf_del_extmark(bufnr, EXTMARK_NSNR, self._extmark_nr)
      self._extmark_nr = nil
    end

    ---! Set the extmark with the right-aligned virtual text
    self._extmark_nr = vim.api.nvim_buf_set_extmark(bufnr, EXTMARK_NSNR, 0, 0, {
      virt_text = { { "" .. lnum .. " / " .. total, "Comment" } },
      virt_text_pos = "right_align",
    })
  end
end

---@param text                          string|nil
---@return nil
function M:reset_input(text)
  local state = self.state ---@type fml.types.ui.search.IState
  local next_text = util.unwrap_editing_prefix(text or state.input:snapshot()) ---@type string
  state.input:next(next_text)

  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = oxi.parse_lines(next_text) ---@type string[]
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, state.enable_multiline_input and lines or { lines[1] })
  end
end

return M
