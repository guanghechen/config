---@class eve.ux.view.IPrinterProps
---@field public name                   string
---@field public nsnr                   ?integer
---@field public indent                 ?string

---@class eve.ux.view.Printer : eve.ux.view.IView
---@field protected _disposed           boolean
---@field protected _highlights         std.t.IHighlight[]
---@field protected _indent             string
---@field protected _lines              string[]
---@field protected _max_width          integer
---@field protected _offset_indent      integer
---@field protected _offset_lnum        integer
---@field protected _offset_col         integer
local M = {}
M.__index = M

local NSNR_DEFAULT = eve.var.nsnr.view_printer ---@type integer

---@param props                        eve.ux.view.IPrinterProps
---@return eve.ux.view.Printer
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer
  local indent = props.indent or ""

  local self = setmetatable({}, M)

  self.name = name
  self.nsnr = nsnr
  self._disposed = false
  self._highlights = {}
  self._indent = indent
  self._lines = {}
  self._max_width = vim.api.nvim_strwidth(indent)
  self._offset_indent = #indent
  self._offset_lnum = 1
  self._offset_col = #indent
  return self
end

---@return eve.ux.view.Printer
function M:clear()
  self:health()

  local indent = self._indent ---@type string
  self._highlights = {}
  self._lines = {}
  self._max_width = vim.api.nvim_strwidth(indent)
  self._offset_indent = #indent
  self._offset_lnum = 1
  self._offset_col = #indent
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  self._disposed = true ---@type boolean
  self._highlights = nil
  self._indent = nil
  self._lines = nil
  self._max_width = nil
  self._offset_indent = nil
  self._offset_lnum = nil
  self._offset_col = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:health()
  if self._disposed then
    local message = string.format("Printer (%s) has been disposed.", self.name) ---@type string
    error(message)
  end
end

---@return integer
---@return integer
function M:measure()
  self:health()

  local height = #self._lines ---@type integer
  local max_width = self._max_width ---@type integer
  return height, max_width
end

---@param bufnr                         integer
---@return eve.ux.view.Printer
function M:render(bufnr)
  self:health()

  local lines = self._lines ---@type string[]
  local highlights = self._highlights ---@type std.t.IHighlight[]
  local nsnr = self.nsnr ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  for _, hl in ipairs(highlights) do
    local row = hl.lnum - 1 ---@type integer
    vim.hl.range(bufnr, nsnr, hl.hlname, { row, hl.coll }, { row, hl.colr })
  end
  return self
end

----------------------------------------------------------------------------------------------------

---@param lines                         string[]
---@param highlights                    ?std.t.IHighlight[]
---@return eve.ux.view.Printer
function M:lines(lines, highlights)
  self:health()

  if #lines < 1 then
    return self
  end

  if highlights ~= nil and #highlights > 0 then
    local _highlights = self._highlights ---@type std.t.IHighlight[]
    local offset_lnum = #self._lines ---@type integer
    local offset_col = self._offset_indent ---@type integer
    for _, raw in ipairs(highlights) do
      if raw.lnum < 0 then
        for i = 1, #lines, 1 do
          ---@type std.t.IHighlight
          local highlight = {
            lnum = offset_lnum + i,
            coll = raw.coll < 0 and raw.coll or offset_col + raw.coll,
            colr = raw.colr < 0 and raw.colr or offset_col + raw.colr,
            hlname = raw.hlname,
          }
          _highlights[#_highlights + 1] = highlight
        end
      else
        ---@type std.t.IHighlight
        local highlight = {
          lnum = offset_lnum + raw.lnum,
          coll = raw.coll < 0 and raw.coll or offset_col + raw.coll,
          colr = raw.colr < 0 and raw.colr or offset_col + raw.colr,
          hlname = raw.hlname,
        }
        _highlights[#_highlights + 1] = highlight
      end
    end
  end

  local indent = self._indent ---@type string
  local _lines = self._lines ---@type string[]
  local _max_width = self._max_width ---@type integer
  for _, content in ipairs(lines) do
    local line = indent .. content ---@type string
    local width = vim.api.nvim_strwidth(line) ---@type integer
    _max_width = _max_width < width and width or _max_width ---@type integer
    _lines[#_lines + 1] = line
  end
  self._max_width = _max_width
  self._offset_lnum = #self._lines + 1
  self._offset_col = self._offset_indent

  return self
end

---@param content                       string
---@param highlights                    ?std.t.IHighlightInline[]
---@return eve.ux.view.Printer
function M:line(content, highlights)
  self:health()

  if highlights ~= nil and #highlights > 0 then
    local lnum = #self._lines + 1 ---@type integer
    local offset_col = self._offset_indent ---@type integer
    for _, raw in ipairs(highlights) do
      ---@type std.t.IHighlight
      local highlight = {
        lnum = lnum,
        coll = raw.coll < 0 and raw.coll or offset_col + raw.coll,
        colr = raw.colr < 0 and raw.colr or offset_col + raw.colr,
        hlname = raw.hlname,
      }
      table.insert(self._highlights, highlight)
    end
  end

  local line = self._indent .. content ---@type string
  self._lines[#self._lines + 1] = line ---@type string
  self._max_width = math.max(self._max_width, vim.api.nvim_strwidth(line)) ---@type integer
  self._offset_lnum = #self._lines + 1 ---@type integer
  self._offset_col = self._offset_indent ---@type integer
  return self
end

---@param content                       string
---@param highlights                    ?std.t.IHighlightInline[]
---@return eve.ux.view.Printer
function M:inline(content, highlights)
  self:health()

  local lnum = self._offset_lnum ---@type integer
  local offset_col = self._offset_col ---@type integer

  if highlights ~= nil and #highlights > 0 then
    for _, raw in ipairs(highlights) do
      ---@type std.t.IHighlight
      local highlight = {
        lnum = lnum,
        coll = raw.coll < 0 and raw.coll or offset_col + raw.coll,
        colr = raw.colr < 0 and raw.colr or offset_col + raw.colr,
        hlname = raw.hlname,
      }
      table.insert(self._highlights, highlight)
    end
  end

  self._lines[lnum] = (self._lines[lnum] or self._indent) .. content
  self._max_width = math.max(self._max_width, vim.api.nvim_strwidth(self._lines[lnum]))
  self._offset_col = offset_col + #content
  return self
end

---@return eve.ux.view.Printer
function M:lf()
  self:health()

  self._lines[#self._lines + 1] = self._indent
  self._offset_lnum = #self._lines + 1
  self._offset_col = self._offset_indent
  return self
end

return M
