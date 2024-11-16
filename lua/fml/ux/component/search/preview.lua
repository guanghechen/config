local constants = require("eve.std.constants")
local Scheduler = require("eve.collection.scheduler")
local Subscriber = require("eve.collection.subscriber")

---@class fml.ux.search.Preview : t.fml.ux.search.IPreview
---@field protected _bufnr              integer|nil
---@field protected _keymaps            t.eve.IKeymap[]
---@field protected _render_scheduler   t.eve.collection.IScheduler
local M = {}
M.__index = M

---@class fml.ux.search.preview.IProps
---@field public delay_render           integer
---@field public fetch_data             t.fml.ux.search.IFetchPreviewData
---@field public keymaps                t.eve.IKeymap[]
---@field public patch_data             ?t.fml.ux.search.IPatchPreviewData
---@field public state                  t.fml.ux.search.IState
---@field public on_rendered            ?t.fml.ux.search.IOnPreviewRendered
---@field public update_win_config      fun(opts: t.fml.ux.search.preview.IWinOpts): nil

---@param props                         fml.ux.search.preview.IProps
---@return fml.ux.search.Preview
function M.new(props)
  local self = setmetatable({}, M)

  local delay_render = props.delay_render ---@type integer
  local _fetch_data = props.fetch_data ---@type t.fml.ux.search.IFetchPreviewData
  local _patch_data = props.patch_data ---@type t.fml.ux.search.IPatchPreviewData|nil
  local keymaps = props.keymaps ---@type t.eve.IKeymap[]
  local state = props.state ---@type t.fml.ux.search.IState
  local on_rendered = props.on_rendered ---@type t.fml.ux.search.IOnMainRendered|nil
  local _update_win_config = props.update_win_config ---@type fun(opts: t.fml.ux.search.preview.IWinOpts): nil

  local _last_item = nil ---@type t.fml.ux.search.IItem|nil
  local _last_data = nil ---@type t.fml.ux.search.preview.IData|nil
  local _last_drawed_bufnr = nil ---@type integer|nil

  ---@param item                          t.fml.ux.search.IItem|nil
  ---@return t.fml.ux.search.preview.IData|nil
  local function fetch_data(item)
    if item == nil then
      return nil
    end

    if
      _patch_data ~= nil
      and _last_item ~= nil
      and _last_data ~= nil
      and _last_item.group == item.group
      and not state:has_item_deleted(_last_item.uuid)
      and item.group ~= nil
    then
      return _patch_data(item, _last_item, _last_data)
    end
    return _fetch_data(item)
  end

  ---@return nil
  local function render()
    local bufnr = self:create_buf_as_needed() ---@type integer

    local last_data = _last_data ---@type t.fml.ux.search.preview.IData|nil
    local item = state:get_current() ---@type t.fml.ux.search.IItem|nil
    local data = fetch_data(item) ---@type t.fml.ux.search.preview.IData|nil
    _last_item = item
    _last_data = data

    ---@type boolean
    local has_content_changed = bufnr ~= _last_drawed_bufnr
      or data == nil
      or last_data == nil
      or data.lines ~= last_data.lines

    ---@type boolean
    local has_highlights_changed = has_content_changed
      or data == nil
      or last_data == nil
      or bufnr ~= _last_drawed_bufnr
      or data.filetype ~= last_data.filetype
      or data.highlights ~= last_data.highlights

    if has_content_changed then
      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].readonly = false

      local lines = data and data.lines or {} ---@type string[]
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      _last_drawed_bufnr = bufnr

      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true
    end

    if has_highlights_changed and data ~= nil then
      vim.api.nvim_buf_clear_namespace(bufnr, 0, 0, -1)
      local filetype = data and data.filetype or nil ---@type string|nil
      if filetype ~= nil and vim.treesitter ~= nil and vim.treesitter.language ~= nil then
        local lang = vim.treesitter.language.get_lang(filetype) or filetype
        if lang then
          local has_ts_parser = pcall(vim.treesitter.language.add, lang)
          if has_ts_parser then
            vim.treesitter.start(bufnr, lang)
          end
        end
      end

      for _, hl in ipairs(data.highlights) do
        vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, hl.lnum - 1, hl.coll, hl.colr)
      end
    end

    local title = data and data.title or "preview" ---@type string
    local lnum = data and data.lnum or nil ---@type integer|nil
    local col = data and data.col or nil ---@type integer|nil
    _update_win_config({ title = title, lnum = lnum, col = col })
  end

  local _render_scheduler = Scheduler.new({
    name = "fml.ux.search.preview.render",
    delay = delay_render,
    task = function(callback)
      render()
      callback("fulfilled")

      state.dirtier_preview:mark_clean()
      if on_rendered then
        on_rendered()
      end
    end,
  })

  self.state = state
  self._bufnr = nil
  self._keymaps = keymaps
  self._render_scheduler = _render_scheduler

  ---@return integer|nil
  ---@return integer|nil
  self.get_current_location = function()
    if _last_data == nil then
      return nil
    end
    return _last_data.lnum, _last_data.col
  end

  state.dirtier_preview:subscribe(
    Subscriber.new({
      on_next = function()
        local is_preview_dirty = state.dirtier_preview:is_dirty() ---@type boolean
        local status = state.status:snapshot() ---@type t.eve.e.WidgetStatus
        local visible = status == "visible" ---@type boolean
        if visible and is_preview_dirty then
          _render_scheduler:schedule()
        end
      end,
    }),
    true
  )
  return self
end

---@return integer
function M:create_buf_as_needed()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].filetype = constants.FT_SEARCH_PREVIEW
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
  return bufnr
end

---@return nil
function M:destroy()
  local bufnr = self._bufnr ---@type integer|nil
  self._bufnr = nil
  self._render_scheduler:cancel()

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M:render()
  self.state.dirtier_preview:mark_dirty()
end

return M
