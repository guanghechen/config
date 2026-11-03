---@see https://github.com/saghen/blink.pairs

return {
  name = "blink.pairs",
  event = "VeryLazy",
  build = "cargo build --release", -- Requires nightly, selected by blink.pairs/rust-toolchain.toml.
  opts = {
    mappings = {
      enabled = true,
      cmdline = true,
      disabled_filetypes = stl.filetype.list_not_sourcefile_filetypes(),
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
      matchparen = {
        enabled = true,
        cmdline = false,
        include_surrounding = true,
        group = "f_matched_pairs_0",
      },
    },
    debug = false,
  },
  config = function(_, opts)
    require("blink.pairs").setup(opts)

    -- blink.pairs replaces the Enter and Space maps of ark/keymap.lua in Insert mode. Keep their undo break-points in
    -- front of its keys: a line break and the first space after a word start a new undo step.
    ---@type table<string, fun(): string>
    local breaks = {
      ["<CR>"] = function()
        return "<C-g>u"
      end,
      ["<Space>"] = function()
        local col = vim.api.nvim_win_get_cursor(0)[2] ---@type integer
        local before = vim.api.nvim_get_current_line():sub(col, col) ---@type string
        return (before ~= "" and before:match("%s") == nil) and "<C-g>u" or ""
      end,
    }
    local keymaps = {} ---@type table<string, vim.api.keyset.get_keymap>
    for _, keymap in ipairs(vim.api.nvim_get_keymap("i")) do
      keymaps[keymap.lhsraw] = keymap
    end
    for lhs, undo_break in pairs(breaks) do
      local keymap = keymaps[vim.keycode(lhs)] ---@type vim.api.keyset.get_keymap|nil
      local callback = assert(keymap and keymap.callback, "blink.pairs no longer maps " .. lhs) ---@type function
      vim.keymap.set("i", lhs, function()
        return undo_break() .. callback()
      end, { expr = true, silent = true, desc = "pairs: " .. lhs .. " after an undo break-point" })
    end
  end,
}
