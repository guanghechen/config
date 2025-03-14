local setting = require("eve.constant.setting")
local signs = require("eve.constant.sign")

---@class fml.ux.search.IInput
---@field public context                fml.ux.search.IContext
---@field public create_buf_as_needed   fun(self: fml.ux.search.IInput): integer
---@field public destroy                fun(self: fml.ux.search.IInput): nil
---@field public reset_input            fun(self: fml.ux.search.IInput, input?: string): nil
---@field public set_virtual_text       fun(self: fml.ux.search.IInput): nil

---@class fml.ux.search.Input : fml.ux.search.IInput
---@field protected _autocmd_group      integer
---@field protected _extmark_nr         integer|nil
---@field protected _input_scheduler    eve.collection.IScheduler
---@field protected _keymaps            eve.t.IKeymap[]
local M = {}
M.__index = M

local EDITING_PREFIX = setting.EDITING_INPUT_PREFIX ---@type string
local EXTMARK_NSNR = vim.api.nvim_create_namespace("fml.ux.search.input") ---@type integer

---@class fml.ux.search.input.IProps
---@field public context                fml.ux.search.IContext
---@field public keymaps                eve.t.IKeymap[]

---@param props                         fml.ux.search.input.IProps
---@return fml.ux.search.Input
function M.new(props)
  local self = setmetatable({}, M)

  local context = props.context ---@type fml.ux.search.IContext
  local input_history = context.input_history ---@type eve.collection.IHistory|nil
  local autocmd_group = eve.nvim.augroup(context.uuid .. ":search_input") ---@type integer

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

  local input_scheduler = eve.col.Scheduler.new({
    name = "fml.ux.search.input.on_change",
    delay = 32,
    task = function(callback)
      local bufnr = context.bufnr_input ---@type integer|nil
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

  self.context = context
  self._autocmd_group = autocmd_group
  self._extmark_nr = nil
  self._input_scheduler = input_scheduler
  self._keymaps = keymaps

  context.dirtier_preview:subscribe(
    eve.col.Subscriber.new({
      on_next = function()
        local is_preview_dirty = context.dirtier_preview:is_dirty() ---@type boolean
        local status = context.status:snapshot() ---@type eve.e.WidgetStatus
        local visible = status == "visible" ---@type boolean
        if visible and is_preview_dirty then
          self:set_virtual_text()
        end
      end,
    }),
    true
  )

  context.input:subscribe(
    eve.col.Subscriber.new({
      on_next = function()
        if input_history ~= nil then
          local input_cur = context.input:snapshot() ---@type string
          local input_present = input_history:present() ---@type string|nil, integer
          if input_present ~= input_cur then
            local input_top = input_history:top() ---@type string|nil
            if input_top ~= nil and eve.string.starts_with(input_top, EDITING_PREFIX) then
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
  local context = self.context ---@type fml.ux.search.IContext
  if context.bufnr_input ~= nil and vim.api.nvim_buf_is_valid(context.bufnr_input) then
    return context.bufnr_input
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  context.bufnr_input = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = eve.filetype.SEARCH_INPUT
  vim.bo[bufnr].swapfile = false

  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  local input = context.input:snapshot() ---@type string
  local lines = eve.oxi.parse_lines(input) ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, context.enable_multiline_input and lines or { lines[1] })
  vim.fn.sign_place(bufnr, "", signs.SEARCH_INPUT_CURSOR, bufnr, { lnum = 1, priority = 10 })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = self._autocmd_group,
    buffer = bufnr,
    callback = function()
      vim.fn.sign_place(bufnr, "", signs.SEARCH_INPUT_CURSOR, bufnr, { lnum = 1, priority = 10 })
      self._input_scheduler:schedule()
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete" }, {
    group = self._autocmd_group,
    buffer = bufnr,
    once = true,
    callback = function()
      context.bufnr_input = nil
      vim.api.nvim_del_augroup_by_id(self._autocmd_group)
    end,
  })
  return bufnr
end

---@return nil
function M:destroy()
  local context = self.context ---@type fml.ux.search.IContext
  local bufnr = context.bufnr_input ---@type integer|nil
  context.bufnr_input = nil

  self._input_scheduler:cancel()
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M:set_virtual_text()
  local context = self.context ---@type fml.ux.search.IContext
  local bufnr = context.bufnr_input ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local total = #context.items or 0 ---@type integer
    local lnum = context:get_current_lnum() or 1 ---@type integer
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
  local context = self.context ---@type fml.ux.search.IContext
  local next_text = text or context.input:snapshot() ---@type string
  next_text = eve.string.starts_with(next_text, EDITING_PREFIX) and next_text:sub(#EDITING_PREFIX + 1) or next_text ---@type string
  context.input:next(next_text)

  local bufnr = context.bufnr_input ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = eve.oxi.parse_lines(next_text) ---@type string[]
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, context.enable_multiline_input and lines or { lines[1] })
  end
end

return M
