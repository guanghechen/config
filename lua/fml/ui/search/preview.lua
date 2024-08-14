local constant = require("fml.constant")
local watch_observables = require("fml.fn.watch_observables")
local reporter = require("fml.std.reporter")
local util = require("fml.std.util")

---@class fml.ui.search.Preview : fml.types.ui.search.IPreview
---@field protected _bufnr              integer|nil
---@field protected _keymaps            fml.types.IKeymap[]
---@field protected _last_data          fml.ui.search.preview.IData|nil
---@field protected _last_item          fml.types.ui.search.IItem|nil
---@field protected _rendering          boolean
---@field protected _on_rendered        fml.types.ui.search.preview.IOnRendered|nil
---@field protected _fetch_data         fml.types.ui.search.preview.IFetchData
---@field protected _patch_data         fml.types.ui.search.preview.IPatchData|nil
---@field protected _update_win_config  fun(opts: fml.ui.search.preview.IWinOpts): nil
local M = {}
M.__index = M

---@class fml.ui.search.preview.IProps
---@field public state                  fml.types.ui.search.IState
---@field public keymaps                fml.types.IKeymap[]
---@field public fetch_data             fml.types.ui.search.preview.IFetchData
---@field public patch_data             ?fml.types.ui.search.preview.IPatchData
---@field public on_rendered            ?fml.types.ui.search.preview.IOnRendered
---@field public update_win_config      fun(opts: fml.ui.search.preview.IWinOpts): nil

---@param props                         fml.ui.search.preview.IProps
---@return fml.ui.search.Preview
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.search.IState
  local keymaps = props.keymaps ---@type fml.types.IKeymap[]
  local fetch_data = props.fetch_data ---@type fml.types.ui.search.preview.IFetchData
  local patch_data = props.patch_data ---@type fml.types.ui.search.preview.IPatchData|nil
  local on_rendered = props.on_rendered ---@type fml.types.ui.search.main.IOnRendered|nil
  local update_win_config = props.update_win_config ---@type fun(new_title: string): nil

  self.state = state
  self._bufnr = nil
  self._keymaps = keymaps
  self._last_data = nil
  self._last_item = nil
  self._rendering = false
  self._on_rendered = on_rendered
  self._fetch_data = fetch_data
  self._patch_data = patch_data
  self._update_win_config = update_win_config

  watch_observables({ state.dirty_preview }, function()
    vim.schedule(function()
      local is_dirty_preview = state.dirty_preview:snapshot() ---@type boolean|nil
      if is_dirty_preview then
        self:render()
      end
    end)
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
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].filetype = constant.FT_SEARCH_PREVIEW
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  util.bind_keys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.schedule(function()
    vim.cmd("stopinsert")
  end)

  self._last_item = nil
  self._last_data = nil
  return bufnr
end

---@return nil
function M:destroy()
  local bufnr = self._bufnr ---@type integer|nil
  self._bufnr = nil

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param force                         ?boolean
---@return nil
function M:render(force)
  local state = self.state ---@type fml.types.ui.search.IState

  if force then
    state.dirty_preview:next(true)
  end

  if self._bufnr == nil or not vim.api.nvim_buf_is_valid(self._bufnr) then
    self._bufnr = nil
    state.dirty_preview:next(true)
  end

  local dirty = state.dirty_preview:snapshot() ---@type boolean
  local visible = state.visible:snapshot() ---@type boolean
  if self._rendering or not visible or not dirty then
    return
  end

  self._rendering = true
  vim.defer_fn(function()
    util.run_async("fml.ui.search.preview:render", function()
      state.dirty_preview:next(false)

      local item = state:get_current() ---@type fml.types.ui.search.IItem|nil
      local ok, error = pcall(function()
        local last_data = self._last_data ---@type fml.ui.search.preview.IData|nil
        local data = self:fetch_data(item) ---@type fml.ui.search.preview.IData|nil
        local bufnr = self:create_buf_as_needed() ---@type integer

        self._last_item = item
        self._last_data = data

        ---@type boolean
        local has_content_changed = data == nil or last_data == nil or data.lines ~= last_data.lines

        ---@type boolean
        local has_highlights_changed = has_content_changed
          or data == nil
          or last_data == nil
          or data.filetype ~= last_data.filetype
          or data.highlights ~= last_data.highlights

        if has_content_changed then
          vim.bo[bufnr].modifiable = true
          vim.bo[bufnr].readonly = false

          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
          if data ~= nil then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data.lines)
          end

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
            if hl.hlname ~= nil then
              vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, hl.lnum - 1, hl.coll, hl.colr)
            end
          end
        end

        local title = data and data.title or "preview" ---@type string
        local show_numbers = data and data.show_numbers or false ---@type boolean
        local lnum = data and data.lnum or nil ---@type integer|nil
        local col = data and data.col or nil ---@type integer|nil
        self._update_win_config({
          title = title,
          show_numbers = show_numbers,
          lnum = lnum,
          col = col,
        })
      end)

      if not ok then
        reporter.error({
          from = "fml.ui.search.preview",
          subject = "render",
          message = "Failed to render preview.",
          details = { error = error, item = item },
        })
      end

      self._rendering = false
      vim.schedule(function()
        if self._on_rendered ~= nil then
          self._on_rendered()
        end
        self:render()
      end)
    end)
  end, 50)
end

---@param item                          fml.types.ui.search.IItem|nil
---@return fml.ui.search.preview.IData|nil
function M:fetch_data(item)
  if item == nil then
    return nil
  end

  local last_item = self._last_item ---@type fml.types.ui.search.IItem|nil
  local last_data = self._last_data ---@type fml.ui.search.preview.IData|nil
  if
    self._patch_data ~= nil
    and last_item ~= nil
    and last_data ~= nil
    and item.group ~= nil
    and last_item.group == item.group
  then
    return self._patch_data(item, last_item, last_data)
  end
  return self._fetch_data(item)
end

return M
