local constant = require("fml.constant")
local scheduler = require("fml.std.scheduler")
local util = require("fml.std.util")
local watch_observables = require("fml.fn.watch_observables")

---@class fml.ui.search.Preview : fml.types.ui.search.IPreview
---@field protected _bufnr              integer|nil
---@field protected _keymaps            fml.types.IKeymap[]
---@field protected _render_scheduler   fml.std.scheduler.IScheduler
local M = {}
M.__index = M

---@class fml.ui.search.preview.IProps
---@field public state                  fml.types.ui.search.IState
---@field public keymaps                fml.types.IKeymap[]
---@field public fetch_data             fml.types.ui.search.preview.IFetchData
---@field public patch_data             ?fml.types.ui.search.preview.IPatchData
---@field public on_rendered            ?fml.types.ui.search.preview.IOnRendered
---@field public render_delay           integer
---@field public update_win_config      fun(opts: fml.ui.search.preview.IWinOpts): nil

---@param props                         fml.ui.search.preview.IProps
---@return fml.ui.search.Preview
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.search.IState
  local _keymaps = props.keymaps ---@type fml.types.IKeymap[]
  local _fetch_data = props.fetch_data ---@type fml.types.ui.search.preview.IFetchData
  local _patch_data = props.patch_data ---@type fml.types.ui.search.preview.IPatchData|nil
  local _on_rendered = props.on_rendered ---@type fml.types.ui.search.main.IOnRendered|nil
  local _render_delay = props.render_delay ---@type integer
  local _update_win_config = props.update_win_config ---@type fun(opts: fml.ui.search.preview.IWinOpts): nil

  local _last_item = nil ---@type fml.types.ui.search.IItem|nil
  local _last_data = nil ---@type fml.ui.search.preview.IData|nil

  ---@param item                          fml.types.ui.search.IItem|nil
  ---@return fml.ui.search.preview.IData|nil
  function M:fetch_data(item)
    if item == nil then
      return nil
    end

    if
      _patch_data ~= nil
      and _last_item ~= nil
      and _last_data ~= nil
      and _last_item.group == item.group
      and item.group ~= nil
    then
      return _patch_data(item, _last_item, _last_data)
    end
    return _fetch_data(item)
  end

  ---@type fml.std.scheduler.IScheduler
  local _render_scheduler = scheduler.debounce({
    name = "fml.ui.search.preview.render",
    delay = _render_delay,
    fn = function(callback)
      local ok, error = pcall(function()
        local last_data = _last_data ---@type fml.ui.search.preview.IData|nil
        local item = state:get_current() ---@type fml.types.ui.search.IItem|nil
        local data = self:fetch_data(item) ---@type fml.ui.search.preview.IData|nil

        _last_item = item
        _last_data = data

        local has_content_changed = data == nil or last_data == nil or data.lines ~= last_data.lines
        local has_highlights_changed = has_content_changed
          or data == nil
          or last_data == nil
          or data.filetype ~= last_data.filetype
          or data.highlights ~= last_data.highlights

        local bufnr = self:create_buf_as_needed() ---@type integer
        if has_content_changed then
          vim.bo[bufnr].modifiable = true
          vim.bo[bufnr].readonly = false

          local lines = data and data.lines or {} ---@type string[]
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

          vim.bo[bufnr].modifiable = false
          vim.bo[bufnr].readonly = true
        elseif has_highlights_changed then
          vim.api.nvim_buf_clear_namespace(bufnr, 0, 0, -1)
        end

        if has_highlights_changed and data ~= nil then
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
        local show_numbers = data and data.show_numbers or false ---@type boolean
        local lnum = data and data.lnum or nil ---@type integer|nil
        local col = data and data.col or nil ---@type integer|nil
        _update_win_config({
          title = title,
          show_numbers = show_numbers,
          lnum = lnum,
          col = col,
        })
      end)
      callback(ok, error)
    end,
    callback = function()
      state.dirty_preview:next(false)
      if _on_rendered then
        _on_rendered()
      end
    end,
  })

  self.state = state
  self._bufnr = nil
  self._keymaps = _keymaps
  self._render_scheduler = _render_scheduler

  watch_observables({ state.dirty_preview }, function()
    local dirty = state.dirty_preview:snapshot() ---@type boolean|nil
    local visible = state.visible:snapshot() ---@type boolean
    if visible and dirty then
      _render_scheduler.schedule()
    end
  end, true)

  return self
end

---@return integer
function M:create_buf_as_needed()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._bufnr = bufnr

    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nowrite"
    vim.bo[bufnr].filetype = constant.FT_SEARCH_PREVIEW
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].readonly = true
    util.bind_keys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end
  return bufnr
end

---@return nil
function M:destroy()
  local bufnr = self._bufnr ---@type integer|nil
  self._bufnr = nil
  self._render_scheduler.cancel()

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param force                         ?boolean
---@return nil
function M:render(force)
  local state = self.state ---@type fml.types.ui.search.IState
  if self._bufnr ~= nil and not vim.api.nvim_buf_is_valid(self._bufnr) then
    self._bufnr = nil
  end

  if force or self._bufnr == nil then
    state.dirty_preview:next(true, { force = true })
  end
end

return M
