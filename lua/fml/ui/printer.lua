---@class fml.ui.Printer : fml.types.ui.IPrinter
---@field protected bufnr               integer
---@field protected lnum                integer
---@field protected line_metas          table<integer, any|nil>
local M = {}
M.__index = M

---@class fml.ui.printer.IProps
---@field public nsnr                   integer
---@field public bufnr                  integer

---@param props fml.ui.printer.IProps
---@return fml.ui.Printer
function M.new(props)
  local self = setmetatable({}, M)

  self.nsnr = props.nsnr
  self.bufnr = props.bufnr
  self.lnum = 0
  self.line_metas = {}

  return self
end

---@return nil
function M:clear()
  self.lnum = 0
  self.line_metas = {}
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
end

---@param params                        fml.types.ui.printer.IResetParams
---@return nil
function M:reset(params)
  self.nsnr = params.nsnr
  self.bufnr = params.bufnr
  self:clear()
end

---@return any|nil
function M:get_meta(lnum)
  return self.line_metas[lnum]
end

---@return integer
function M:get_current_lnum()
  return self.lnum
end

---@param line                          string
---@param highlights                    ?fml.types.ui.printer.ILineHighlight
---@param meta                          ?any
---@return nil
function M:print(line, highlights, meta)
  local nsnr = self.nsnr ---@type integer
  local bufnr = self.bufnr ---@type integer
  local lnum = self.lnum ---@type integer

  vim.api.nvim_buf_set_lines(bufnr, lnum, lnum, false, { line })
  if highlights ~= nil and #highlights > 0 then
    for _, hl in ipairs(highlights) do
      if hl.hlname ~= nil then
        vim.api.nvim_buf_add_highlight(bufnr, nsnr, hl.hlname, lnum, hl.cstart, hl.cend)
      end
    end
  end

  self.lnum = self.lnum + 1
  self.line_metas[self.lnum] = meta
end

return M
