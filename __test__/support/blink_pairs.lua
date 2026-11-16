---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.blink_pairs" ---@type string

-- blink.pairs as this configuration used it before era.keystroke.pairs and era.dressing.pairs replaced it, for the
-- pairs benchmark and fixture generators. Needs a built blink.pairs and the ark runtime.

local M = {}

--- Puts blink.pairs at `root` on the runtime path and sets it up with the configuration's former options, keeping
--- the undo break-points of Enter and Space in front of its maps.
---@param root                          string
---@return nil
function M.setup(root)
  vim.opt.runtimepath:prepend(root)
  require("blink.pairs").setup({
    mappings = {
      enabled = true,
      cmdline = true,
      disabled_filetypes = stl.filetype.list_not_sourcefile_filetypes(),
      wrap = { ["<C-b>"] = false, ["<C-S-b>"] = false },
    },
    highlights = {
      enabled = true,
      cmdline = true,
      groups = {
        "f_matched_pairs_1",
        "f_matched_pairs_2",
        "f_matched_pairs_3",
        "f_matched_pairs_4",
        "f_matched_pairs_5",
      },
      unmatched_group = "f_unmatched_pairs",
      matchparen = { enabled = true, cmdline = false, include_surrounding = true, group = "f_matched_pairs_0" },
    },
  })
  local keymaps = {} ---@type table<string, vim.api.keyset.get_keymap>
  for _, keymap in ipairs(vim.api.nvim_get_keymap("i")) do
    keymaps[keymap.lhsraw] = keymap
  end
  local enter = assert(keymaps[vim.keycode("<CR>")].callback)
  local space = assert(keymaps[vim.keycode("<Space>")].callback)
  vim.keymap.set("i", "<CR>", function()
    return "<C-g>u" .. enter()
  end, { expr = true })
  vim.keymap.set("i", "<Space>", function()
    local col = vim.api.nvim_win_get_cursor(0)[2] ---@type integer
    local before = vim.api.nvim_get_current_line():sub(col, col) ---@type string
    return ((before ~= "" and before:match("%s") == nil) and "<C-g>u" or "") .. space()
  end, { expr = true })
end

return M
