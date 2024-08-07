local constant = require("fml.constant")
local util = require("fml.std.util")
local signcolumn = require("fml.ui.signcolumn")

---@class fml.ui.search.Main : fml.types.ui.search.IMain
---@field protected _bufnr              integer|nil
---@field protected _keymaps            fml.types.IKeymap[]
---@field protected _rendering          boolean
---@field protected _on_rendered        fml.types.ui.search.main.IOnRendered
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
  local keymaps = props.keymaps ---@type fml.types.IKeymap[]
  local on_rendered = props.on_rendered ---@type fml.types.ui.search.main.IOnRendered

  self.state = state
  self._bufnr = nil
  self._keymaps = keymaps
  self._rendering = false
  self._on_rendered = on_rendered
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
  vim.bo[bufnr].filetype = constant.FT_SEARCH_MAIN
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  util.bind_keys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })

  vim.schedule(function()
    vim.cmd("stopinsert")
  end)

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

---@return integer|nil
function M:place_lnum_sign()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.sign_unplace("", { buffer = bufnr, id = bufnr })
    local _, lnum, uuid = self.state:get_current()
    local linecount = vim.api.nvim_buf_line_count(bufnr) ---@type integer
    if uuid ~= nil and linecount > 0 and lnum > 0 and lnum <= linecount then
      vim.fn.sign_place(bufnr, "", signcolumn.names.search_main_current, bufnr, { lnum = lnum })
      return lnum
    end
  end
  return nil
end

---@param force                         ?boolean
---@return nil
function M:render(force)
  local state = self.state ---@type fml.types.ui.search.IState

  if force then
    state.dirty_main:next(true)
  end

  if self._bufnr == nil or not vim.api.nvim_buf_is_valid(self._bufnr) then
    self._bufnr = nil
    state.dirty_main:next(true)
  end

  local dirty = state.dirty_main:snapshot() ---@type boolean
  local visible = state.visible:snapshot() ---@type boolean
  if self._rendering or not visible or not dirty then
    return
  end

  self._rendering = true
  vim.defer_fn(function()
    util.run_async("fml.ui.search.main:render", function()
      state.dirty_main:next(false)
      local bufnr = self:create_buf_as_needed() ---@type integer
      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].readonly = false

      vim.api.nvim_buf_set_lines(self._bufnr, 0, -1, false, {})
      local items = state.items ---@type fml.types.ui.search.IItem[]
      for i, item in ipairs(items) do
        local row = i - 1 ---@type integer
        local highlights = item.highlights ---@type fml.types.ui.printer.ILineHighlight[]
        vim.api.nvim_buf_set_lines(bufnr, row, row, false, { item.text })
        if highlights ~= nil and #highlights > 0 then
          for _, hl in ipairs(highlights) do
            if hl.hlname ~= nil then
              vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, row, hl.cstart, hl.cend)
            end
          end
        end
      end
      self:place_lnum_sign()

      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true

      self._on_rendered()
      self._rendering = false
      self:render()
    end)
  end, 50)
end

return M
