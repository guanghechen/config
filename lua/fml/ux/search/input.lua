local fts = require("eve.constant.filetype")
local constant = require("eve.lib.constant")
local functional = require("eve.lib.functional")
local augroup = require("eve.lib.nvim").augroup
local bindkeys = require("eve.lib.nvim").bindkeys
local oxi = require("eve.lib.oxi")
local signcolumn = require("eve.lib.signcolumn")
local Subscriber = require("eve.lib.collection.subscriber")
local Scheduler = require("eve.lib.collection.scheduler")

---@class fml.ux.search.IInput
---@field public context                fml.ux.search.IContext
---@field public create_buf_as_needed   fun(self: fml.ux.search.IInput): integer
---@field public destroy                fun(self: fml.ux.search.IInput): nil
---@field public reset_input            fun(self: fml.ux.search.IInput, input?: string): nil
---@field public set_virtual_text       fun(self: fml.ux.search.IInput): nil

---@class fml.ux.search.Input : fml.ux.search.IInput
---@field protected _autocmd_group      integer
---@field protected _bufnr              integer|nil
---@field protected _extmark_nr         integer|nil
---@field protected _input_scheduler    eve.lib.collection.IScheduler
---@field protected _keymaps            eve.t.IKeymap[]
local M = {}
M.__index = M

local EDITING_PREFIX = constant.EDITING_INPUT_PREFIX ---@type string
local EXTMARK_NSNR = vim.api.nvim_create_namespace("fml.ux.search.input") ---@type integer

---@class fml.ux.search.input.IProps
---@field public state                  fml.ux.search.IContext
---@field public keymaps                eve.t.IKeymap[]

---@param props                         fml.ux.search.input.IProps
---@return fml.ux.search.Input
function M.new(props)
  local self = setmetatable({}, M)

  local search_state = props.state ---@type fml.ux.search.IContext
  local input_history = search_state.input_history ---@type eve.lib.collection.IHistory|nil
  local autocmd_group = augroup(search_state.uuid .. ":search_input") ---@type integer

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

  local keymaps = vim.list_slice(props.keymaps) ---@type eve.t.IKeymap[]
  if input_history ~= nil then
    vim.list_extend(keymaps, {
      { modes = { "i", "n", "v" }, key = "<C-j>", callback = actions.apply_next_input, desc = "search: next input" },
      { modes = { "i", "n", "v" }, key = "<C-k>", callback = actions.apply_prev_input, desc = "search: last input" },
    })
  end

  local input_scheduler = Scheduler.new({
    name = "fml.ux.search.input.on_change",
    delay = 32,
    task = function(callback)
      ---@diagnostic disable-next-line: invisible
      local bufnr = self._bufnr ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        if vim.api.nvim_buf_is_valid(bufnr) then
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
          local next_input = table.concat(lines, "\n") ---@type string
          self.context.input:next(next_input)
        end
      end
      callback("fulfilled")
    end,
  })

  self.context = search_state
  self._autocmd_group = autocmd_group
  self._bufnr = nil
  self._extmark_nr = nil
  self._input_scheduler = input_scheduler
  self._keymaps = keymaps

  search_state.dirtier_preview:subscribe(
    Subscriber.new({
      on_next = function()
        local is_preview_dirty = search_state.dirtier_preview:is_dirty() ---@type boolean
        local status = search_state.status:snapshot() ---@type eve.e.WidgetStatus
        local visible = status == "visible" ---@type boolean
        if visible and is_preview_dirty then
          self:set_virtual_text()
        end
      end,
    }),
    true
  )

  search_state.input:subscribe(
    Subscriber.new({
      on_next = function()
        if input_history ~= nil then
          local input_cur = search_state.input:snapshot() ---@type string
          local input_present = input_history:present() ---@type string|nil, integer
          if input_present ~= input_cur then
            local input_top = input_history:top() ---@type string|nil
            if input_top ~= nil and functional.is_editing_text(input_top) then
              input_history:update_top(EDITING_PREFIX .. input_cur)
            else
              input_history:go(math.huge)
              input_history:push(EDITING_PREFIX .. input_cur)
            end
          end
        end
      end,
    }),
    true
  )

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
  vim.bo[bufnr].filetype = fts.SEARCH_INPUT
  vim.bo[bufnr].swapfile = false

  bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  local search_state = self.context ---@type fml.ux.search.IContext
  local input = search_state.input:snapshot() ---@type string
  local lines = oxi.parse_lines(input) ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, search_state.enable_multiline_input and lines or { lines[1] })
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
  self._input_scheduler:cancel()

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M:set_virtual_text()
  local search_state = self.context ---@type fml.ux.search.IContext
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local total = #search_state.items or 0 ---@type integer
    local lnum = search_state:get_current_lnum() or 1 ---@type integer
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
  local search_state = self.context ---@type fml.ux.search.IContext
  local next_text = functional.unwrap_editing_prefix(text or search_state.input:snapshot()) ---@type string
  search_state.input:next(next_text)

  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = oxi.parse_lines(next_text) ---@type string[]
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, search_state.enable_multiline_input and lines or { lines[1] })
  end
end

return M
