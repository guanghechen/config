vim.api.nvim_create_autocmd({ "WinResized", "BufWinEnter", "CursorHold", "InsertLeave" }, {
  group = fml.fn.augroup("barbecue.updater"),
  callback = function()
    require("barbecue.ui").update()
  end,
})

return {
  "utilyre/barbecue.nvim",
  name = "barbecue",
  event = { "BufReadPost" },
  dependencies = {
    "SmiteshP/nvim-navic",
    "nvim-tree/nvim-web-devicons", -- optional dependency
  },
  opts = {
    create_autocmd = false,
    theme = {
      normal = { fg = "#989898" },

      -- these highlights correspond to symbols table from config
      ellipsis = { fg = "#A4A4A4" },
      separator = { fg = "#A4A4A4" },
      modified = { fg = "#A4A4A4" },

      -- these highlights represent the _text_ of three main parts of barbecue
      dirname = { fg = "#A4A4A4" },
      basename = { bold = true },
      context = {},

      -- these highlights are used for context/navic icons
      context_file = { fg = "#ac8fe4" },
      context_module = { fg = "#ac8fe4" },
      context_namespace = { fg = "#ac8fe4" },
      context_package = { fg = "#ac8fe4" },
      context_class = { fg = "#ac8fe4" },
      context_method = { fg = "#ac8fe4" },
      context_property = { fg = "#ac8fe4" },
      context_field = { fg = "#ac8fe4" },
      context_constructor = { fg = "#ac8fe4" },
      context_enum = { fg = "#ac8fe4" },
      context_interface = { fg = "#ac8fe4" },
      context_function = { fg = "#ac8fe4" },
      context_variable = { fg = "#ac8fe4" },
      context_constant = { fg = "#ac8fe4" },
      context_string = { fg = "#ac8fe4" },
      context_number = { fg = "#ac8fe4" },
      context_boolean = { fg = "#ac8fe4" },
      context_array = { fg = "#ac8fe4" },
      context_object = { fg = "#ac8fe4" },
      context_key = { fg = "#ac8fe4" },
      context_null = { fg = "#ac8fe4" },
      context_enum_member = { fg = "#ac8fe4" },
      context_struct = { fg = "#ac8fe4" },
      context_event = { fg = "#ac8fe4" },
      context_operator = { fg = "#ac8fe4" },
      context_type_parameter = { fg = "#ac8fe4" },
    },
  },
}
