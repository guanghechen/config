---@class eve.ux.ISearchPreview
---@field public context                eve.ux.ISearchContext
---@field public create_buf_as_needed   fun(self: eve.ux.ISearchPreview): integer
---@field public destroy                fun(self: eve.ux.ISearchPreview): nil
---@field public get_current_location   fun(self: eve.ux.ISearchPreview): integer|nil, integer|nil
---@field public render                 fun(self: eve.ux.ISearchPreview): nil

---@class eve.ux.ISearchPreviewData
---@field public lines                  string[]
---@field public highlights             eve.t.IHighlight[]
---@field public filetype               string|nil
---@field public title                  string
---@field public lnum                   integer|nil
---@field public col                    integer|nil

---@class eve.ux.ISearchPreviewWinOpts
---@field public title                  string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class eve.ux.SearchPreview : eve.ux.ISearchPreview
---@field protected _keymaps            eve.t.IKeymap[]
---@field protected _render_scheduler   eve.std.collection.IScheduler
local M = {}
M.__index = M

---@class eve.ux.ISearchPreviewProps
---@field public delay_render           integer
---@field public fetch_data             eve.ux.search.IFetchPreviewData
---@field public keymaps                eve.t.IKeymap[]
---@field public patch_data             ?eve.ux.search.IPatchPreviewData
---@field public context                eve.ux.ISearchContext
---@field public on_rendered            ?eve.ux.search.IOnPreviewRendered
---@field public update_win_config      fun(opts: eve.ux.ISearchPreviewWinOpts): nil

---@param props                         eve.ux.ISearchPreviewProps
---@return eve.ux.SearchPreview
function M.new(props)
  local self = setmetatable({}, M)

  local delay_render = props.delay_render ---@type integer
  local _fetch_data = props.fetch_data ---@type eve.ux.search.IFetchPreviewData
  local _patch_data = props.patch_data ---@type eve.ux.search.IPatchPreviewData|nil
  local keymaps = props.keymaps ---@type eve.t.IKeymap[]
  local context = props.context ---@type eve.ux.ISearchContext
  local on_rendered = props.on_rendered ---@type eve.ux.search.IOnMainRendered|nil
  local _update_win_config = props.update_win_config ---@type fun(opts: eve.ux.ISearchPreviewWinOpts): nil

  local _last_item = nil ---@type eve.ux.search.IItem|nil
  local _last_data = nil ---@type eve.ux.ISearchPreviewData|nil
  local _last_drawed_bufnr = nil ---@type integer|nil

  ---@param item                          eve.ux.search.IItem|nil
  ---@return eve.ux.ISearchPreviewData|nil
  local function fetch_data(item)
    if item == nil then
      return nil
    end

    if
      _patch_data ~= nil
      and _last_item ~= nil
      and _last_data ~= nil
      and _last_item.group == item.group
      and not context:has_item_deleted(_last_item.uuid)
      and item.group ~= nil
    then
      return _patch_data(item, _last_item, _last_data)
    end
    return _fetch_data(item)
  end

  ---@return nil
  local function render()
    local bufnr = self:create_buf_as_needed() ---@type integer

    local last_data = _last_data ---@type eve.ux.ISearchPreviewData|nil
    local item = context:get_current() ---@type eve.ux.search.IItem|nil
    local data = fetch_data(item) ---@type eve.ux.ISearchPreviewData|nil
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
      local handled = false ---@type boolean
      if filetype == "markdown" then
        local ok, render_markdown_state = pcall(require, "render-markdown.state")
        if ok and render_markdown_state then
          handled = true
          render_markdown_state.on.attach({ buf = bufnr })
          require("render-markdown.manager").update(bufnr, "Initial")
        end
      end

      if not handled then
        require("nvim-treesitter") --- load nvim-treesitter if not loaded
        if filetype ~= nil and vim.treesitter ~= nil and vim.treesitter.language ~= nil then
          local lang = vim.treesitter.language.get_lang(filetype) or filetype
          local loaded = vim.treesitter.language.add(lang)
          if loaded then
            vim.treesitter.start(bufnr, lang)
          end
        end
      end

      local nsnr = eve.var.Namespaces.search_preview ---@type integer
      for _, hl in ipairs(data.highlights) do
        local row = hl.lnum - 1 ---@type integer
        vim.hl.range(bufnr, nsnr, hl.hlname, { row, hl.coll }, { row, hl.colr })
      end
    end

    local title = data and data.title or "preview" ---@type string
    local lnum = data and data.lnum or nil ---@type integer|nil
    local col = data and data.col or nil ---@type integer|nil
    _update_win_config({ title = title, lnum = lnum, col = col })
  end

  local _render_scheduler = eve.std.Scheduler.new({
    name = "eve.ux.search.preview.render",
    delay = delay_render,
    task = function(callback)
      render()
      callback("fulfilled")

      context.dirtier_preview:mark_clean()
      if on_rendered then
        on_rendered()
      end
    end,
  })

  self.context = context
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

  context.dirtier_preview:subscribe(
    eve.std.Subscriber.new({
      on_next = function()
        local is_preview_dirty = context.dirtier_preview:is_dirty() ---@type boolean
        local status = context.status:snapshot() ---@type eve.e.WidgetStatus
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
  local context = self.context ---@type eve.ux.ISearchContext
  if context.bufnr_preview ~= nil and vim.api.nvim_buf_is_valid(context.bufnr_preview) then
    return context.bufnr_preview
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  context.bufnr_preview = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = eve.filetype.SEARCH_PREVIEW
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })
  return bufnr
end

---@return nil
function M:destroy()
  local context = self.context ---@type eve.ux.ISearchContext
  local bufnr = context.bufnr_preview ---@type integer|nil
  context.bufnr_preview = nil

  self._render_scheduler:cancel()
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M:render()
  self.context.dirtier_preview:mark_dirty()
end

return M
