local constant = require("fml.constant")
local Subscriber = require("fml.collection.subscriber")
local bind_keys = require("fml.fn.bind_keys")
local run_async = require("fml.fn.run_async")
local signcolumn = require("fml.ui.signcolumn")

---@class fml.ui.select.Main : fml.types.ui.select.IMain
---@field protected bufnr               integer|nil
---@field protected state               fml.types.ui.select.IState
---@field protected keymaps             fml.types.ui.IKeymap[]
---@field protected dirty               boolean
---@field protected rendering           boolean
---@field protected on_rendered         fun(): nil
---@field protected render_line            fun(params: fml.types.ui.select.main.IRenderLineParams): string
local M = {}
M.__index = M

---@class fml.ui.select.main.IProps
---@field public state                  fml.types.ui.select.IState
---@field public keymaps                fml.types.ui.IKeymap[]
---@field public on_rendered            fun(): nil
---@field public render_line            ?fun(params: fml.types.ui.select.main.IRenderLineParams): string, fml.types.ui.printer.ILineHighlight[]

---@param params                        fml.types.ui.select.main.IRenderLineParams
---@return string
---@return fml.types.ui.printer.ILineHighlight[]
local function default_render_line(params)
  local match = params.match ---@type fml.types.ui.select.ILineMatch
  local item = params.item ---@type fml.types.ui.select.IItem
  local highlights = {} ---@type fml.types.ui.printer.ILineHighlight[]
  for _, piece in ipairs(match.pieces) do
    table.insert(highlights, { cstart = piece.l - 1, cend = piece.r, hlname = "Search" })
  end
  return item.display, highlights
end

---@param props                         fml.ui.select.main.IProps
---@return fml.ui.select.Main
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.select.IState
  local keymaps = props.keymaps ---@type fml.types.ui.IKeymap[]
  local on_rendered = props.on_rendered ---@type fun(): nil
  local render_line = props.render_line or default_render_line ---@type fun(params: fml.types.ui.select.main.IRenderLineParams): string

  self.bufnr = nil
  self.state = state
  self.keymaps = keymaps
  self.dirty = true
  self.rendering = false
  self.render_line = render_line
  self.on_rendered = on_rendered

  state.ticker:subscribe(Subscriber.new({
    on_next = function()
      ---@diagnostic disable-next-line: invisible
      self.dirty = true
    end,
  }))
  return self
end

---@return integer
function M:create_buf_as_needed()
  if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
    return self.bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].filetype = constant.FT_SELECT_MAIN
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  bind_keys(self.keymaps, { bufnr = bufnr, noremap = true, silent = true })
  self.bufnr = bufnr
  return bufnr
end

---@return integer|nil
function M:place_lnum_sign()
  local bufnr = self.bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    local linecount = vim.api.nvim_buf_line_count(bufnr) ---@type integer
    local lnum = math.max(1, self.state:get_lnum()) ---@type integer
    if lnum <= linecount then
      vim.fn.sign_unplace("*", { buffer = bufnr })
      vim.fn.sign_place(bufnr, "", signcolumn.names.select_main_current, bufnr, { lnum = lnum })
      return lnum
    end
  end
  return nil
end

---@return nil
function M:render()
  local state = self.state ---@type fml.types.ui.select.IState
  if self.rendering or not state:is_visible() then
    return
  end
  if self.bufnr == nil or not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = nil
    self.dirty = true
  end
  if not self.dirty then
    return
  end

  self.rendering = true
  vim.defer_fn(function()
    local matches = state:filter() ---@type fml.types.ui.select.ILineMatch[]
    self.dirty = false
    run_async(function()
      local bufnr = self:create_buf_as_needed() ---@type integer

      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].readonly = false

      vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
      for i, match in ipairs(matches) do
        local lnum = i - 1 ---@type integer
        local item = state.items[match.idx] ---@type fml.types.ui.select.IItem
        local line, highlights = self.render_line({ item = item, match = match }) ---@type string
        vim.api.nvim_buf_set_lines(bufnr, lnum, lnum, false, { line })
        if highlights ~= nil and #highlights > 0 then
          for _, hl in ipairs(highlights) do
            if hl.hlname ~= nil then
              vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, lnum, hl.cstart, hl.cend)
            end
          end
        end
      end
      self:place_lnum_sign()

      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true
      self.rendering = false

      self.on_rendered()

      if self.dirty then
        self:render()
      end
    end)
  end, 50)
end

return M
