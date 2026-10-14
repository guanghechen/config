---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.menu" ---@type string

local Item = require("era.keystroke.cmp.item")
local Snippet = require("era.keystroke.cmp.snippet")

---@class era.keystroke.cmp.Menu
---@field public active                 boolean
---@field public start_col              integer
---@field public end_col                integer
---@field private _generation           integer
local M = {}
M.__index = M

---@return era.keystroke.cmp.Menu
function M.new()
  return setmetatable({ active = false, start_col = 0, end_col = 0, _generation = 0 }, M)
end

---@param raw                           lsp.CompletionItem
---@return string
local function label_text(raw)
  local details = Item.optional(raw.labelDetails)
  if details == nil then
    return raw.label
  end
  local detail = Item.optional(details.detail) or ""
  local description = Item.optional(details.description) or ""
  return raw.label .. detail .. (description ~= "" and " " .. description or "")
end

---@return boolean
function M:is_visible()
  return self.active and vim.fn.pumvisible() == 1
end

---@param data                          any
---@return boolean
function M:owns(data)
  return self.active and type(data) == "table" and data.era_cmp == self._generation
end

---@param context                       era.keystroke.cmp.IContext
---@param items                         era.keystroke.cmp.IItem[]
---@param selected                      ?integer
---@return nil
function M:show(context, items, selected)
  if #items == 0 or vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
    self:hide()
    return
  end
  self._generation = self._generation + 1
  local generation = self._generation
  local start_col = context.start_col
  for _, item in ipairs(items) do
    start_col = math.min(start_col, item.start_col)
  end
  self.start_col = start_col
  self.end_col = context.col
  local matches = {}
  for index, item in ipairs(items) do
    local raw = item.raw
    local kind = vim.lsp.protocol.CompletionItemKind[raw.kind or 1] or "Text"
    -- Native completion previews a prefix. Full LSP edits and snippet expansion belong to acceptance.
    local text = Item.insert_text(raw)
    if raw.insertTextFormat == 2 and text ~= nil then
      if item.preview_word == nil then
        item.preview_word = Snippet.preview_word(text, raw.label)
      end
      text = item.preview_word
    end
    local tags = Item.optional(raw.tags)
    matches[index] = {
      word = context.line:sub(start_col + 1, item.start_col)
        .. (text and (text:match("^[^\n]*") or "") or context.line:sub(item.start_col + 1, context.col)),
      abbr = label_text(raw):gsub("[%z\1-\31\127]", " "),
      kind = stl.icon.kind[kind] or stl.icon.kind.Text,
      kind_hlgroup = "CmpKind" .. kind,
      abbr_hlgroup = (raw.deprecated == true or (tags ~= nil and vim.list_contains(tags, 1))) and "CmpLabelDeprecated"
        or nil,
      menu = "[" .. item.source .. "]",
      equal = 1,
      dup = 1,
      empty = 1,
      user_data = { era_cmp = generation, index = index },
    }
  end
  -- Replacing the list can emit CompleteDone for its predecessor.
  self.active = false
  vim.fn.complete(start_col + 1, matches)
  if self._generation ~= generation then
    -- A synchronous hide cancels this publication before complete() installs its list.
    -- A newer active menu owns its own dismissal.
    if not self.active and vim.fn.pumvisible() == 1 and vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
      vim.fn.complete(vim.api.nvim_win_get_cursor(0)[2] + 1, {})
    end
    return
  end
  self.active = true
  self:select(selected, false)
end

---@param selected                      ?integer
---@param insert                        boolean
---@return nil
function M:select(selected, insert)
  vim.api.nvim_select_popupmenu_item(selected and selected - 1 or -1, insert, false, {})
end

---@return nil
function M:hide()
  self._generation = self._generation + 1
  local visible = self:is_visible()
  self.active = false
  if visible and vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
    -- An empty list dismisses the PUM without inserting or undoing its current preview.
    vim.fn.complete(vim.api.nvim_win_get_cursor(0)[2] + 1, {})
  end
end

return M
