local kinds = require("eve.constant.icon").kind

---@type table<string, string>
local icons = vim.tbl_extend("force", {}, kinds)
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
      filetypes = eve.c.filetype.get_no_ibl_filetypes(),
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
