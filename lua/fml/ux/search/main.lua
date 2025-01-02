local fts = require("eve.constant.filetype")
local constant = require("eve.lib.constant")
local bindkeys = require("eve.lib.nvim").bindkeys
local signcolumn = require("eve.lib.signcolumn")
local Subscriber = require("eve.lib.collection.subscriber")
local Scheduler = require("eve.lib.collection.scheduler")

---@class fml.ux.search.IMain
---@field public context                fml.ux.search.IContext
---@field public create_buf_as_needed   fun(self: fml.ux.search.IMain): integer
---@field public destroy                fun(self: fml.ux.search.IMain): nil
---@field public place_lnum_sign        fun(self: fml.ux.search.IMain): integer|nil
---@field public render                 fun(self: fml.ux.search.IMain): nil

---@class fml.ux.search.Main : fml.ux.search.IMain
---@field protected _bufnr              integer|nil
---@field protected _keymaps            eve.t.IKeymap[]
---@field protected _render_scheduler   eve.lib.collection.IScheduler
local M = {}
M.__index = M

---@class fml.ux.search.main.IProps
---@field public delay_render           integer
---@field public keymaps                eve.t.IKeymap[]
---@field public context                fml.ux.search.IContext
---@field public on_rendered            ?fml.ux.search.IOnMainRendered

---@param props                         fml.ux.search.main.IProps
---@return fml.ux.search.Main
function M.new(props)
  local self = setmetatable({}, M)

  local delay_render = props.delay_render ---@type integer
  local keymaps = props.keymaps ---@type eve.t.IKeymap[]
  local context = props.context ---@type fml.ux.search.IContext
  local on_rendered = props.on_rendered ---@type fml.ux.search.IOnMainRendered|nil

  local _last_items = nil ---@type fml.ux.search.IItem[]|nil
  local _last_items_count = 0 ---@type integer
  local _last_drawed_bufnr = nil ---@type integer|nil

  ---@return nil
  local function render()
    local bufnr = self:create_buf_as_needed() ---@type integer
    local last_items = _last_items ---@type fml.ux.search.IItem[]|nil
    local last_items_count = _last_items_count ---@type integer
    _last_items = context.items
    _last_items_count = #context.items

    ---@type boolean
    local has_content_changed = bufnr ~= _last_drawed_bufnr
      or last_items == nil
      or last_items ~= context.items
      or last_items_count ~= #context.items

    if has_content_changed then
      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].readonly = false

      local lines = {} ---@type string[]
      for i, item in ipairs(context.items) do
        lines[i] = item.text
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      _last_drawed_bufnr = bufnr

      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true

      local items = context.items ---@type fml.ux.search.IItem[]
      for lnum, item in ipairs(items) do
        local highlights = item.highlights ---@type eve.t.IHighlightInline[]
        for _, hl in ipairs(highlights) do
          vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, lnum - 1, hl.coll, hl.colr)
        end
      end
    end

    self:place_lnum_sign()
  end

  local render_scheduler = Scheduler.new({
    name = "fml.ux.search.main.render",
    delay = delay_render,
    task = function(callback)
      local ok, reason = pcall(render)
      if ok then
        callback("fulfilled")
      else
        callback("rejected", nil, reason)
      end

      context.dirtier_main:mark_clean()
      if on_rendered then
        on_rendered()
      end
    end,
  })

  self.context = context
  self._bufnr = nil
  self._keymaps = keymaps
  self._render_scheduler = render_scheduler

  context.dirtier_main:subscribe(
    Subscriber.new({
      on_next = function()
        local is_main_dirty = context.dirtier_main:is_dirty() ---@type boolean
        local status = context.status:snapshot() ---@type eve.e.WidgetStatus
        local visible = status == "visible" ---@type boolean
        if visible and is_main_dirty then
          render_scheduler:schedule()
        end
      end,
    }),
    true
  )

  return self
end

---@return integer
---@return boolean
function M:create_buf_as_needed()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].filetype = fts.SEARCH_MAIN
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
  return bufnr, true
end

---@return nil
function M:destroy()
  local bufnr = self._bufnr ---@type integer|nil
  self._bufnr = nil
  self._render_scheduler:cancel()
  self.context.dirtier_main:mark_clean()

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return integer|nil
function M:place_lnum_sign()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.sign_unplace("", { buffer = bufnr, id = constant.SIGN_NR_SEARCH_MAIN_CURRENT })
    vim.fn.sign_unplace("", { buffer = bufnr, id = constant.SIGN_NR_SEARCH_MAIN_PRESENT })

    local present_lnum = 0 ---@type integer
    do
      local item_present_uuid = self.context.item_present_uuid ---@type string|nil
      if item_present_uuid ~= nil then
        for lnum, item in ipairs(self.context.items) do
          if item.uuid == item_present_uuid then
            present_lnum = lnum
            break
          end
        end
      end
    end

    local current_lnum = 0 ---@type integer
    do
      local _, lnum, uuid = self.context:get_current()
      local linecount = vim.api.nvim_buf_line_count(bufnr) ---@type integer
      if uuid ~= nil and linecount > 0 and lnum > 0 and lnum <= linecount then
        current_lnum = lnum
      end
    end

    if present_lnum > 0 then
      vim.fn.sign_place(
        constant.SIGN_NR_SEARCH_MAIN_PRESENT,
        "",
        present_lnum == current_lnum and signcolumn.names.search_main_present_cur
          or signcolumn.names.search_main_present,
        bufnr,
        { lnum = present_lnum }
      )
    end

    if current_lnum > 0 then
      if current_lnum ~= present_lnum then
        vim.fn.sign_place(
          constant.SIGN_NR_SEARCH_MAIN_CURRENT,
          "",
          signcolumn.names.search_main_current,
          bufnr,
          { lnum = current_lnum }
        )
      end
      return current_lnum
    end
  end
  return nil
end

---@return nil
function M:render()
  self.context.dirtier_main:mark_dirty()
end

return M
