---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.render" ---@type string

local highlight = require("era.dressing.hipattern.highlight")
local matcher = require("era.dressing.hipattern.matcher")

---@class era.dressing.hipattern.render
local M = {}

local INLINE_TEXT = "󱓻 " ---@type string
local INLINE_PRIORITY = 2000 ---@type integer
local HIGHLIGHT_PRIORITY = 200 ---@type integer
local namespace = vim.api.nvim_create_namespace(__module_name__) ---@type integer

---@param bufnr                         integer
---@param from_row                      integer
---@param to_row                        integer
---@return nil
local function render_rows(bufnr, from_row, to_row)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  local lines = vim.api.nvim_buf_get_lines(bufnr, from_row, to_row, false) ---@type string[]
  for index, line in ipairs(lines) do
    local row = from_row + index - 1 ---@type integer
    for _, decoration in ipairs(matcher.match(line, filetype)) do
      if decoration.kind == "inline_color" then
        local hlgroup = highlight.get_color_group(decoration.color)
        if hlgroup ~= nil then
          vim.api.nvim_buf_set_extmark(bufnr, namespace, row, decoration.coll, {
            priority = INLINE_PRIORITY,
            right_gravity = false,
            virt_text = { { INLINE_TEXT, hlgroup } },
            virt_text_pos = "inline",
          })
        end
      elseif decoration.hlgroup ~= nil and decoration.coll < decoration.colr then
        vim.api.nvim_buf_set_extmark(bufnr, namespace, row, decoration.coll, {
          end_col = decoration.colr,
          end_row = row,
          hl_group = decoration.hlgroup,
          priority = HIGHLIGHT_PRIORITY,
        })
      end
    end
  end
end

---@param bufnr                         integer
---@param from_row                      integer
---@param to_row                        integer
---@return nil
function M.clear(bufnr, from_row, to_row)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, namespace, from_row, to_row)
  end
end

---@param bufnr                         integer
---@param from_row                      integer
---@param to_row                        integer
---@return nil
function M.update(bufnr, from_row, to_row)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  from_row = math.max(0, from_row)
  to_row = math.max(from_row, to_row)
  M.clear(bufnr, from_row, to_row)

  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  from_row = math.min(from_row, line_count)
  to_row = math.min(to_row, line_count)
  if from_row >= to_row then
    return
  end
  render_rows(bufnr, from_row, to_row)
end

---@param bufnr                         integer
---@return nil
function M.update_all(bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  M.clear(bufnr, 0, -1)
  render_rows(bufnr, 0, vim.api.nvim_buf_line_count(bufnr))
end

---@return nil
function M.refresh_highlights()
  highlight.refresh()
end

return M
