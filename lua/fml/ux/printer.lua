---@class eve.ux.IPrinter
---@field public name                   string
---@field public count_lines            fun(self: eve.ux.IPrinter): integer
---@field public lines                  fun(self: eve.ux.IPrinter, lines: string[], highlights?: eve.t.IHighlight[]): eve.ux.IPrinter
---@field public line                   fun(self: eve.ux.IPrinter, content: string, highlights?: eve.t.IHighlightInline[]): eve.ux.IPrinter
---@field public inline                 fun(self: eve.ux.IPrinter, content: string, highlights?: eve.t.IHighlightInline[]): eve.ux.IPrinter
---@field public lf                     fun(self: eve.ux.IPrinter): eve.ux.IPrinter
---@field public render                 fun(self: eve.ux.IPrinter, bufnr: integer): nil

---@class fml.ux.printer.IProps
---@field public name                   string
---@field public indent                 ?string

---@class fml.ux.printer : eve.ux.IPrinter
---@field protected _indent              string
---@field protected _lines               string[]
---@field protected _highlights          eve.t.IHighlight[]
---@field protected _offset_indent       integer
---@field protected _offset_lnum         integer
---@field protected _offset_col          integer
local M = {}
M.__index = M

---@param props                        fml.ux.printer.IProps
---@return fml.ux.printer
function M.new(props)
  local name = props.name ---@type string
  local indent = props.indent or ""

  local self = setmetatable({}, M)

  self.name = name
  self._indent = indent
  self._lines = {}
  self._highlights = {}
  self._offset_indent = #indent
  self._offset_lnum = 1
  self._offset_col = #indent

  return self
end

---@return integer
function M:count_lines()
  return #self._lines
end

---@param lines                         string[]
---@param highlights                    ?eve.t.IHighlight[]
---@return fml.ux.printer
function M:lines(lines, highlights)
  if #lines < 1 then
    return self
  end

  if highlights ~= nil and #highlights > 0 then
    local offset_lnum = #self._lines ---@type integer
    local offset_col = self._offset_indent ---@type integer
    for _, raw in ipairs(highlights) do
      if raw.lnum < 0 then
        for i = 1, #lines, 1 do
          ---@type eve.t.IHighlight
          local highlight = {
            lnum = offset_lnum + i,
            coll = raw.coll < 0 and raw.coll or offset_col + raw.coll,
            colr = raw.colr < 0 and raw.colr or offset_col + raw.colr,
            hlname = raw.hlname,
          }
          table.insert(self._highlights, highlight)
        end
      else
        ---@type eve.t.IHighlight
        local highlight = {
          lnum = offset_lnum + raw.lnum,
          coll = raw.coll < 0 and raw.coll or offset_col + raw.coll,
          colr = raw.colr < 0 and raw.colr or offset_col + raw.colr,
          hlname = raw.hlname,
        }
        table.insert(self._highlights, highlight)
      end
    end
  end

  local indent = self._indent ---@type string
  for _, line in ipairs(lines) do
    table.insert(self._lines, indent .. line)
  end

  self._offset_lnum = #self._lines + 1
  self._offset_col = self._offset_indent

  return self
end

---@param content                       string
---@param highlights                    ?eve.t.IHighlightInline[]
---@return fml.ux.printer
function M:line(content, highlights)
  if highlights ~= nil and #highlights > 0 then
    local lnum = #self._lines + 1 ---@type integer
    local offset_col = self._offset_indent ---@type integer
    for _, raw in ipairs(highlights) do
      ---@type eve.t.IHighlight
      local highlight = {
        lnum = lnum,
        coll = raw.coll < 0 and raw.coll or offset_col + raw.coll,
        colr = raw.colr < 0 and raw.colr or offset_col + raw.colr,
        hlname = raw.hlname,
      }
      table.insert(self._highlights, highlight)
    end
  end

  self._lines[#self._lines + 1] = self._indent .. content
  self._offset_lnum = #self._lines + 1 ---@type integer
  self._offset_col = self._offset_indent ---@type integer
  return self
end

---@param content                       string
---@param highlights                    ?eve.t.IHighlightInline[]
---@return fml.ux.printer
function M:inline(content, highlights)
  local lnum = self._offset_lnum ---@type integer
  local offset_col = self._offset_col ---@type integer

  if highlights ~= nil and #highlights > 0 then
    for _, raw in ipairs(highlights) do
      ---@type eve.t.IHighlight
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
  self._offset_col = offset_col + #content
  return self
end

---@return fml.ux.printer
function M:lf()
  self._lines[#self._lines + 1] = self._indent
  self._offset_lnum = #self._lines + 1
  self._offset_col = self._offset_indent
  return self
end

---@param bufnr                         integer
---@return nil
function M:render(bufnr)
  local lines = self._lines ---@type string[]
  local highlights = self._highlights ---@type eve.t.IHighlight[]

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, hl.lnum - 1, hl.coll, hl.colr)
  end
end

return M
