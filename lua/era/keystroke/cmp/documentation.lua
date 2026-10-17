---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.documentation" ---@type string

local Edit = require("era.keystroke.cmp.edit")
local Item = require("era.keystroke.cmp.item")
local namespace = vim.api.nvim_create_namespace(__module_name__)

---@class era.keystroke.cmp.Documentation
---@field public bufnr                  ?integer
---@field public winnr                  ?integer
---@field private _text                 ?string
---@field private _separator            ?integer
local M = {}
M.__index = M

---@return era.keystroke.cmp.Documentation
function M.new()
  return setmetatable({}, M)
end

---@return boolean
function M:is_visible()
  local winnr = self.winnr
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and not vim.api.nvim_win_get_config(winnr).hide
end

---@return nil
function M:hide()
  if self:is_visible() then
    vim.api.nvim_win_set_config(self.winnr, { hide = true })
  end
  self._text = nil
  self.winnr = nil
  self.bufnr = nil
end

---@private
---@param index                         integer
---@param view                          ?table
---@return nil
function M:_publish(index, view)
  local info = vim.api.nvim__complete_set(index, { info = assert(self._text) })
  if info.winid == nil then
    -- Insufficient space hides the native window; it still owns the reading position.
    return
  end
  self.winnr, self.bufnr = info.winid, info.bufnr
  local winnr, bufnr = info.winid, info.bufnr
  local config = vim.api.nvim_win_get_config(winnr)
  vim.api.nvim_win_set_config(winnr, {
    border = "rounded",
    focusable = false,
    zindex = dot.var.zindex.POPUPMENU + 2,
    width = math.max(1, math.min(config.width, vim.o.columns - config.col - 2)),
  })
  -- The native info buffer is reused; setting the same filetype again would rerun FileType autocmds.
  if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ~= "cmp-documentation" then
    vim.api.nvim_set_option_value("filetype", "cmp-documentation", { buf = bufnr })
  end
  for name, value in pairs({
    wrap = true,
    smoothscroll = true,
    conceallevel = 2,
    concealcursor = "n",
    scrolloff = 0,
    winblend = 0,
    winhighlight = "Normal:CmpDoc,FloatBorder:CmpDocBorder",
  }) do
    vim.api.nvim_set_option_value(name, value, { win = winnr, scope = "local" })
  end
  vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true
  vim.w[winnr].wintype = stl.e.WinTypeEnum.POPUPMENU
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  if self._separator ~= nil then
    vim.api.nvim_buf_set_extmark(bufnr, namespace, self._separator, 0, {
      virt_text = { { ("─"):rep(vim.o.columns), "CmpDocSeparator" } },
      virt_text_pos = "overlay",
    })
  end
  -- The optional parser owns conceal; measure only after its highlights are available.
  pcall(vim.treesitter.start, bufnr, "markdown")
  local maximum = math.max(1, math.min(20, vim.o.lines - 2))
  vim.api.nvim_win_set_height(
    winnr,
    math.max(1, math.min(maximum, vim.api.nvim_win_text_height(winnr, { max_height = maximum }).all))
  )
  vim.api.nvim_win_call(winnr, function()
    vim.fn.winrestview(view or { topline = 1, lnum = 1, col = 0, skipcol = 0 })
  end)
end

---@param context                       era.keystroke.cmp.IContext
---@param raw                           lsp.CompletionItem
---@param index                         integer Zero-based native candidate index.
---@param snippet_text                  ?string Expanded body shared with acceptance.
---@return nil
function M:show(context, raw, index, snippet_text)
  local lines = {}
  local detail = Item.optional(raw.detail)
  if detail == nil and raw.insertTextFormat == 2 then
    local text = snippet_text or Item.insert_text(raw)
    detail = text ~= nil and Edit.snippet_text(text) or nil
  end
  if detail ~= nil and detail:find("%S") then
    lines = { "```" .. context.filetype }
    vim.list_extend(lines, vim.split(detail, "\n", { plain = true }))
    vim.list_extend(lines, { "```", "" })
  end
  local documentation = Item.optional(raw.documentation)
  local text ---@type string|nil
  local plaintext = false
  if type(documentation) == "string" then
    text = documentation
  elseif documentation ~= nil then
    text = Item.optional(documentation.value)
    plaintext = documentation.kind == "plaintext"
  end
  local separator ---@type integer|nil
  if text ~= nil and text:find("%S") then
    local docs = vim.split(text, "\n", { plain = true })
    if #lines > 0 and not plaintext then
      while #docs > 0 and not docs[1]:find("%S") do
        table.remove(docs, 1)
      end
      local first = docs[1] or ""
      local rule = first:gsub("[ \t]", "")
      if
        not first:match("^    ")
        and not first:match("^[ \t]*\t")
        and (rule:match("^%-%-%-+$") or rule:match("^%*%*%*+$") or rule:match("^___+$"))
      then
        table.remove(docs, 1)
        while #docs > 0 and not docs[1]:find("%S") do
          table.remove(docs, 1)
        end
      end
    end
    if #lines > 0 and #docs > 0 then
      separator = #lines - 1
    end
    local fence
    if plaintext then
      local length = 3
      for ticks in text:gmatch("`+") do
        length = math.max(length, #ticks + 1)
      end
      fence = ("`"):rep(length)
      lines[#lines + 1] = fence .. "text"
    end
    vim.list_extend(lines, docs)
    if fence ~= nil then
      lines[#lines + 1] = fence
    end
  end
  while #lines > 0 and not lines[#lines]:find("%S") do
    lines[#lines] = nil
  end
  while #lines > 0 and not lines[1]:find("%S") do
    table.remove(lines, 1)
  end
  if #lines == 0 then
    self:hide()
    return
  end
  while #lines > 1000 do
    lines[#lines] = nil
  end
  self._text = table.concat(lines, "\n")
  self._separator = separator ~= nil and separator < #lines and separator or nil
  self:_publish(index)
end

---@param index                         integer
---@return nil
function M:reposition(index)
  if self._text == nil then
    return
  end
  local winnr = self.winnr
  local view = winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_call(winnr, vim.fn.winsaveview)
    or nil
  -- Native reselect/resize hides dynamic info; republish it and preserve the reading position.
  self:_publish(index, view)
end

---@param direction                     integer
---@return boolean
function M:scroll(direction)
  if not self:is_visible() then
    return false
  end
  vim.api.nvim_win_call(self.winnr, function()
    vim.cmd.normal({ args = { "4" .. vim.keycode(direction > 0 and "<C-e>" or "<C-y>") }, bang = true })
  end)
  return true
end

return M
