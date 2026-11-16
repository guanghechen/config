---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.pairs" ---@type string

--- Rainbow highlighting of paired delimiters by depth and of unmatched ones, plus matchparen.
---@class era.dressing.pairs
local M = {}

---@type string[]
local GROUPS =
  { "f_matched_pairs_1", "f_matched_pairs_2", "f_matched_pairs_3", "f_matched_pairs_4", "f_matched_pairs_5" }
local UNMATCHED = "f_unmatched_pairs" ---@type string
local PRIORITY = 200 ---@type integer

local namespace = vim.api.nvim_create_namespace(__module_name__) ---@type integer
-- The document of the window being drawn: Neovim draws one window at a time, calling on_range after its on_win.
local drawn = nil ---@type yoz.pairs.Document|nil
local initialized = false ---@type boolean

---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, _, bufnr)
      drawn = era.m.pairs.document(bufnr)
      return drawn ~= nil
    end,
    -- One range per buffer line drawn; on a long line, only its drawn columns.
    on_range = function(_, _, bufnr, begin_row, begin_col, end_row, end_col)
      if drawn == nil then
        return
      end
      local data = drawn:highlights(begin_row, begin_col, end_row, end_col)
      local set_extmark = vim.api.nvim_buf_set_extmark
      for at = 1, #data, 4 do
        local height = data[at + 3] ---@type integer
        set_extmark(bufnr, namespace, data[at], data[at + 1], {
          end_col = data[at + 2],
          hl_group = height < 0 and UNMATCHED or GROUPS[height % #GROUPS + 1],
          priority = PRIORITY,
          ephemeral = true,
        })
      end
    end,
  })

  require("era.dressing.pairs.matchparen").setup(stl.nvim.fn.augroup(__module_name__))
end

return M
