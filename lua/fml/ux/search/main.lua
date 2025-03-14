---@class fml.ux.search.IMain
---@field public context                fml.ux.search.IContext
---@field public create_buf_as_needed   fun(self: fml.ux.search.IMain): integer
---@field public destroy                fun(self: fml.ux.search.IMain): nil
---@field public render                 fun(self: fml.ux.search.IMain): nil

---@class fml.ux.search.Main : fml.ux.search.IMain
---@field protected _keymaps            eve.t.IKeymap[]
---@field protected _render_scheduler   eve.collection.IScheduler
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

      for lnum, item in ipairs(context.items) do
        for _, hl in ipairs(item.highlights) do
          vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, lnum - 1, hl.coll, hl.colr)
        end
      end
    end

    context:place_lnum_sign()
  end

  local render_scheduler = eve.col.Scheduler.new({
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
  self._keymaps = keymaps
  self._render_scheduler = render_scheduler

  context.dirtier_main:subscribe(
    eve.col.Subscriber.new({
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
  local context = self.context ---@type fml.ux.search.IContext
  if context.bufnr_main ~= nil and vim.api.nvim_buf_is_valid(context.bufnr_main) then
    return context.bufnr_main, false
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  context.bufnr_main = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = eve.filetype.SEARCH_MAIN
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
  return bufnr, true
end

---@return nil
function M:destroy()
  local context = self.context ---@type fml.ux.search.IContext
  local bufnr = context.bufnr_main ---@type integer|nil
  context.bufnr_main = nil

  self._render_scheduler:cancel()
  self.context.dirtier_main:mark_clean()
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M:render()
  self.context.dirtier_main:mark_dirty()
end

return M
