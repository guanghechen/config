local __module_name__ = "eve.ux.search.input" ---@type string

---@class eve.ux.SearchInput
---@field public context                eve.ux.SearchContext
---@field protected _autocmd_group      integer
---@field protected _extmark_nr         integer|nil
---@field protected _scheduler          std.collection.Scheduler
---@field protected _keymaps            std.t.IKeymap[]
local M = {}
M.__index = M

local EDITING_PREFIX = eve.setting.EDITING_INPUT_PREFIX ---@type string

---@class eve.ux.ISearchInputProps
---@field public context                eve.ux.SearchContext
---@field public keymaps                std.t.IKeymap[]

---@param props                         eve.ux.ISearchInputProps
---@return eve.ux.SearchInput
function M.new(props)
  local self = setmetatable({}, M)

  local context = props.context ---@type eve.ux.SearchContext
  local input_history = context.input_history ---@type std.collection.IHistory|nil
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

  local keymaps = vim.list_slice(props.keymaps) ---@type std.t.IKeymap[]
  if input_history ~= nil then
    vim.list_extend(keymaps, {
      { modes = { "i", "n", "v" }, key = "<C-j>", callback = actions.apply_next_input, desc = "search: next input" },
      { modes = { "i", "n", "v" }, key = "<C-k>", callback = actions.apply_prev_input, desc = "search: last input" },
    })
  end

  local scheduler = std.Scheduler.new({
    name = string.format("%s | %s", context.uuid, __module_name__),
    mode = "throttle",
    delay = 32,
    timeout = 3000,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      local bufnr = context.bufnr_input ---@type integer|nil
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        if vim.api.nvim_buf_is_valid(bufnr) then
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
          local next_input = table.concat(lines, "\n") ---@type string
          self.context.input:next(next_input)
        end
      end
      return true
    end,
  })

  self.context = context
  self._extmark_nr = nil
  self._keymaps = keymaps
  self._scheduler = scheduler

  context.dirtier_preview:subscribe(
    std.Subscriber.new({
      on_next = function()
        local is_preview_dirty = context.dirtier_preview:is_dirty() ---@type boolean
        local visible = context:isvisible() ---@type boolean
        if visible and is_preview_dirty then
          self:set_virtual_text()
        end
      end,
    }),
    true
  )

  context.input:subscribe(
    std.Subscriber.new({
      on_next = function()
        if input_history ~= nil then
          local input_cur = context.input:snapshot() ---@type string
          local input_present = input_history:present() ---@type string|nil, integer
          if input_present ~= input_cur then
            local input_top = input_history:top() ---@type string|nil
            if input_top ~= nil and std.string.starts_with(input_top, EDITING_PREFIX) then
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
  local context = self.context ---@type eve.ux.SearchContext
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
  lines = #lines < 1 and { "" } or (#lines > 1 and not context.enable_multiline_input) and { lines[1] } or lines ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.fn.sign_place(bufnr, "", eve.var.sign.SEARCH_INPUT_CURSOR, bufnr, { lnum = 1, priority = 10 })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      vim.fn.sign_place(bufnr, "", eve.var.sign.SEARCH_INPUT_CURSOR, bufnr, { lnum = 1, priority = 10 })
      self._scheduler:schedule()
    end,
  })
  return bufnr
end

---@return nil
function M:dispose()
  local context = self.context ---@type eve.ux.SearchContext
  local bufnr = context.bufnr_input ---@type integer|nil
  context.bufnr_input = nil

  self._scheduler:dispose()
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M:set_virtual_text()
  local context = self.context ---@type eve.ux.SearchContext
  local bufnr = context.bufnr_input ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local total = #context.items or 0 ---@type integer
    local lnum = context:get_current_lnum() or 1 ---@type integer
    lnum = lnum > total and total or lnum

    local nsnr = eve.var.nsnr.search_input ---@type integer
    if self._extmark_nr then
      vim.api.nvim_buf_del_extmark(bufnr, nsnr, self._extmark_nr)
      self._extmark_nr = nil
    end

    ---! Set the extmark with the right-aligned virtual text
    self._extmark_nr = vim.api.nvim_buf_set_extmark(bufnr, nsnr, 0, 0, {
      virt_text = { { "" .. lnum .. " / " .. total, "Comment" } },
      virt_text_pos = "right_align",
    })
  end
end

---@param text                          string|nil
---@return nil
function M:reset_input(text)
  local context = self.context ---@type eve.ux.SearchContext
  local bufnr = context.bufnr_input ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local next_text = text or context.input:snapshot() ---@type string
  next_text = std.string.starts_with(next_text, EDITING_PREFIX) and next_text:sub(#EDITING_PREFIX + 1) or next_text ---@type string
  context.input:next(next_text)

  local old_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local old_text = table.concat(old_lines, "\n") ---@type string
  if next_text == old_text then
    return
  end

  local lines = eve.oxi.parse_lines(next_text) ---@type string[]
  lines = #lines < 1 and { "" } or (#lines > 1 and not context.enable_multiline_input) and { lines[1] } or lines ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

return M
