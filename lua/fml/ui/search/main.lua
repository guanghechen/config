local constant = require("fml.constant")
local scheduler = require("fml.std.scheduler")
local util = require("fml.std.util")
local watch_observables = require("fml.fn.watch_observables")
local signcolumn = require("fml.ui.signcolumn")

---@class fml.ui.search.Main : fml.types.ui.search.IMain
---@field protected _bufnr              integer|nil
---@field protected _keymaps            fml.types.IKeymap[]
---@field protected _render_scheduler   fml.std.scheduler.IScheduler
local M = {}
M.__index = M

---@class fml.ui.search.main.IProps
---@field public state                  fml.types.ui.search.IState
---@field public keymaps                fml.types.IKeymap[]
---@field public on_rendered            fml.types.ui.search.main.IOnRendered

---@param props                         fml.ui.search.main.IProps
---@return fml.ui.search.Main
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.search.IState
  local _keymaps = props.keymaps ---@type fml.types.IKeymap[]
  local _on_rendered = props.on_rendered ---@type fml.types.ui.search.main.IOnRendered

  ---@type fml.std.scheduler.IScheduler
  local _render_scheduler = scheduler.debounce({
    delay = 48,
    fn = function(callback)
      local ok, error = pcall(function()
        local bufnr = self:create_buf_as_needed() ---@type integer
        vim.bo[bufnr].modifiable = true
        vim.bo[bufnr].readonly = false

        local lines = {} ---@type string[]
        for i, item in ipairs(state.items) do
          lines[i] = item.text
        end
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        self:place_lnum_sign()

        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].readonly = true

        local items = state.items ---@type fml.types.ui.search.IItem[]
        for lnum, item in ipairs(items) do
          local highlights = item.highlights ---@type fml.types.ui.IInlineHighlight[]
          for _, hl in ipairs(highlights) do
            vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, lnum - 1, hl.coll, hl.colr)
          end
        end
      end)
      callback(ok, error)
    end,
    callback = function()
      state.dirty_main:next(false)
      _on_rendered()
    end,
  })

  self.state = state
  self._bufnr = nil
  self._keymaps = _keymaps
  self._render_scheduler = _render_scheduler

  watch_observables({ state.dirty_main }, function()
    local dirty = state.dirty_main:snapshot() ---@type boolean|nil
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
    vim.bo[bufnr].filetype = constant.FT_SEARCH_MAIN
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

---@return integer|nil
function M:place_lnum_sign()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.sign_unplace("", { buffer = bufnr, id = constant.SIGN_NR_SEARCH_MAIN_CURRENT })
    local _, lnum, uuid = self.state:get_current()
    local linecount = vim.api.nvim_buf_line_count(bufnr) ---@type integer
    if uuid ~= nil and linecount > 0 and lnum > 0 and lnum <= linecount then
      vim.fn.sign_place(
        constant.SIGN_NR_SEARCH_MAIN_CURRENT,
        "",
        signcolumn.names.search_main_current,
        bufnr,
        { lnum = lnum }
      )
      return lnum
    end
  end
  return nil
end

---@param force                         ?boolean
---@return nil
function M:render(force)
  local state = self.state ---@type fml.types.ui.search.IState
  if self._bufnr ~= nil and not vim.api.nvim_buf_is_valid(self._bufnr) then
    self._bufnr = nil
  end

  if force or self._bufnr == nil then
    state.dirty_main:next(true, { force = true })
  end
end

return M
