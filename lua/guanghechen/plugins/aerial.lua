---@type table<string, string>
local icons = vim.tbl_extend("force", {}, eve.icons.kind)
for name, icon in pairs(icons) do
  icons[name] = icon .. " "
end

---@type string[]
local base_filter_kind = {
  "Class",
  "Constructor",
  "Enum",
  "Field",
  "Function",
  "Interface",
  "Method",
  "Module",
  "Namespace",
  "Package",
  "Property",
  "Struct",
  "Trait",
}

return {
  name = "aerial.nvim",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  opts = {
    attach_mode = "global",
    autojump = false,
    backends = { "lsp", "treesitter", "markdown", "man" },
    filter_kind = {
      _ = vim.list_extend({}, base_filter_kind),
      lua = vim.list_extend({
        "Object",
        "Property",
      }, base_filter_kind),
    },
    guides = {
      mid_item = "├╴",
      last_item = "└╴",
      nested_top = "│ ",
      whitespace = "  ",
    },
    icons = icons,
    ignore = {
      buftypes = "special",
      wintypes = "special",
      filetypes = {
        eve.constants.FT_AERIAL,
        eve.constants.FT_CHECKHEALTH,
        eve.constants.FT_DIFFVIEW_FILES,
        eve.constants.FT_GITCOMMIT,
        eve.constants.FT_NEOTREE,
        eve.constants.FT_NOTIFY,
        eve.constants.FT_LSPINFO,
        eve.constants.FT_PLENARY_TEST_POPUP,
        eve.constants.FT_SEARCH_INPUT,
        eve.constants.FT_SEARCH_MAIN,
        eve.constants.FT_SEARCH_PREVIEW,
        eve.constants.FT_STARTUPTIME,
        eve.constants.FT_TERM,
        eve.constants.FT_TROUBLE,
      },
      diff_windows = true,
      unlisted_buffers = true,
    },
    layout = {
      default_direction = "right",
      min_width = 40,
      placement = "edge",
      preserve_equality = false,
      resize_to_content = false,
      win_opts = {
        winhl = table.concat({
          "CursorColumn:AerialCursorLine",
          "CursorLine:AerialCursorLine",
          "CursorLineNr:AerialCursorLine",
          "FloatBorder:NormalFloat",
          "Normal:AerialNormal",
          "NormalNC:AerialNormalNC",
        }, ","),
        signcolumn = "yes",
        statuscolumn = " ",
      },
    },
    keymaps = {
      ["<C-s>"] = false,
      ["<C-v>"] = false,
      ["[["] = false,
      ["]]"] = false,
      ["{"] = false,
      ["}"] = false,
    },
    show_guides = true,
  },
  dependencies = {
    "nvim-treesitter",
    "mini.icons",
  },
}
