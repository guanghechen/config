---@class eve.ux.IPickerProps
---@field public name                   string
---@field public nsnr                   ?integer
---@field public finder_input           eve.std.collection.Observable
---@field public finder_multiline       ?boolean
---@field public result_lnum            eve.std.collection.Observable
---@field public preview_visible        ?boolean

---@class eve.ux.Picker
---@field protected _finder_bufnr       integer|nil
---@field protected _finder_winnr       integer|nil
---@field protected _finder_input       eve.std.collection.Observable
---@field protected _finder_multiline   boolean
---
---@field protected _result_bufnr       integer|nil
---@field protected _result_winnr       integer|nil
---@field protected _result_lnum        eve.std.collection.Observable
---
---@field protected _preview_bufnr      integer|nil
---@field protected _preview_winnr      integer|nil
---
---@field public name                   string
---@field public nsnr                   integer
---@field public preview_visible        boolean
local M = {}
M.__index = M

local NSNR_DEFAULT = vim.api.nvim_create_namespace("ux_view_picker") ---@type integer

---@param props                         eve.ux.IPickerProps
---@return eve.ux.Picker
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer
  local finder_input = props.finder_input ---@type eve.std.collection.Observable
  local finder_multiline = not not props.finder_multiline ---@type boolean
  local result_lnum = props.result_lnum ---@type eve.std.collection.Observable
  local preview_visible = not not props.preview_visible ---@type boolean

  local self = setmetatable({}, M)
  self.name = name
  self.nsnr = nsnr
  self.preview_visible = preview_visible
  self._finder_bufnr = nil
  self._finder_winnr = nil
  self._finder_input = finder_input
  self._finder_multiline = finder_multiline
  self._result_bufnr = nil
  self._result_winnr = nil
  self._result_lnum = result_lnum
  self._preview_bufnr = nil
  self._preview_winnr = nil
  return self
end

---@return nil
function M:open()
  local finder_winnr = self._finder_winnr ---@type integer|nil
  local result_winnr = self._result_winnr ---@type integer|nil
  local preview_winnr = self._preview_winnr ---@type integer|nil

  local finder_bufnr, result_bufnr, preview_bufnr = self:create_bufs() ---@type integer, integer, integer|nil
  if finder_winnr == nil or not vim.api.nvim_win_is_valid(finder_winnr) then
  end
end

---@return vim.api.keyset.win_config
---@return vim.api.keyset.win_config
---@return vim.api.keyset.win_config|nil
---@return nil
function M:resize()
  local finder_bufnr, result_bufnr, preview_bufnr = self:create_bufs() ---@type integer, integer, integer|nil

  local has_preview = self.preview_visible and vim.o.columns > 140 ---@type boolean
  local max_width = math.max(vim.o.columns * 0.9, vim.o.columns - 20) ---@type integer
  local max_height = math.max(vim.o.lines * 0.9, vim.o.lines - 10) ---@type integer
  local width = math.min(200, max_width) ---@type integer
  local height = math.min(56, max_height) ---@type integer
  local row = math.floor((vim.o.columns - width) / 2) ---@type integer
  local col = math.floor((vim.o.lines - height) / 2) ---@type integer

  local finder_width = has_preview and math.floor(width / 2) or width ---@type integer
  local preview_width = width - finder_width ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg_finder = {
    relative = "editor",
    row = row,
    col = col,
  }

  ---@type vim.api.keyset.win_config
  local wincfg_result = {
    relative = "win",
  }

  ---@type vim.api.keyset.win_config|nil
  local wincfg_preview = nil
  if has_preview then
    ---@type vim.api.keyset.win_config
    wincfg_preview = {}
  end

  return wincfg_finder, wincfg_result, wincfg_preview
end

---@return integer
---@return integer
---@return integer|nil
function M:create_bufs()
  local finder_bufnr = self._finder_bufnr ---@type integer|nil
  local result_bufnr = self._result_bufnr ---@type integer|nil
  local preview_bufnr = self._preview_bufnr ---@type integer|nil
  local has_preview = self.preview_visible ---@type boolean

  if finder_bufnr == nil or not vim.api.nvim_buf_is_valid(finder_bufnr) then
    finder_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._finder_bufnr = finder_bufnr

    vim.bo[finder_bufnr].buflisted = false
    vim.bo[finder_bufnr].buftype = "nofile"
    vim.bo[finder_bufnr].filetype = eve.filetype.UX_PICKER_FINDER
    vim.bo[finder_bufnr].swapfile = false
    vim.bo[finder_bufnr].modifiable = false
    vim.bo[finder_bufnr].readonly = true

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = finder_bufnr,
      callback = function()
        vim.fn.sign_place(finder_bufnr, "", eve.var.sign.SEARCH_INPUT_CURSOR, finder_bufnr, { lnum = 1, priority = 10 })
        local lines = vim.api.nvim_buf_get_lines(finder_bufnr, 0, -1, false) ---@type string[]
        local content = table.concat(lines, "\n") ---@type string
        self._finder_input:next(content)
      end,
    })
  end

  if result_bufnr == nil or not vim.api.nvim_buf_is_valid(result_bufnr) then
    result_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._result_bufnr = result_bufnr

    vim.bo[result_bufnr].buflisted = false
    vim.bo[result_bufnr].buftype = "nofile"
    vim.bo[result_bufnr].filetype = eve.filetype.UX_PICKER_RESULT
    vim.bo[result_bufnr].swapfile = false
    vim.bo[result_bufnr].modifiable = false
    vim.bo[result_bufnr].readonly = true
  end

  if has_preview then
    if preview_bufnr == nil or not vim.api.nvim_buf_is_valid(preview_bufnr) then
      preview_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      self._preview_bufnr = preview_bufnr

      vim.bo[preview_bufnr].buflisted = false
      vim.bo[preview_bufnr].buftype = "nofile"
      vim.bo[preview_bufnr].filetype = eve.filetype.UX_PICKER_PREVIEW
      vim.bo[preview_bufnr].swapfile = false
      vim.bo[preview_bufnr].modifiable = false
      vim.bo[preview_bufnr].readonly = true
    end
  else
    self._preview_bufnr = nil
    if preview_bufnr ~= nil and vim.api.nvim_buf_is_valid(preview_bufnr) then
      vim.api.nvim_buf_delete(preview_bufnr, { force = true })
    end
  end

  return finder_bufnr, result_bufnr, preview_bufnr
end

---@return integer|nil
function M:get_finder_bufnr()
  local bufnr = self._finder_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._finder_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_finder_winnr()
  local winnr = self._finder_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._finder_winnr = nil
    return nil
  end
  return winnr
end

---@return integer|nil
function M:get_result_bufnr()
  local bufnr = self._result_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._result_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_result_winnr()
  local winnr = self._result_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._result_winnr = nil
    return nil
  end
  return winnr
end

---@return integer|nil
function M:get_preview_bufnr()
  local bufnr = self._preview_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._preview_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_preview_winnr()
  local winnr = self._preview_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._preview_winnr = nil
    return nil
  end
  return winnr
end

---@protected
---@param content                       string
---@return nil
function M:set_finder_content(content)
  local bufnr = self._finder_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._finder_bufnr = nil
    return nil
  end

  local multiline = self._finder_multiline ---@type boolean
  local lines = multiline and { content } or vim.split(content, "\n", { plain = true }) ---@type  string[]
  if #lines < 1 then
    lines = { "" } ---@type string[]
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

---@protected
---@return nil
function M:set_finder_virtual()
  local bufnr = self._finder_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._finder_bufnr = nil
    return nil
  end

  local total = vim.api.nvim_buf_line_count(0) ---@type integer
  local lnum = self._result_lnum:snapshot() ---@type integer
  lnum = lnum > total and total or lnum

  local nsnr = eve.var.nsnr.picker_finder ---@type integer
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

return M
