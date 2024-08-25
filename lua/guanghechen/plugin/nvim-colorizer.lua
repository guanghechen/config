return {
  name = "nvim-colorizer.lua",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  opts = {
    filetypes = {
      css = {
        rgb_fn = true,
        hsl_fn = true,
        names = true,
      },
      html = {},
      lua = {},
      tmux = {},
      yaml = {},
    },
    user_default_options = {
      RGB = true, -- #RGB hex codes
      RRGGBB = true, -- #RRGGBB hex codes
      names = false, -- "Name" codes like Blue or blue
      RRGGBBAA = true, -- #RRGGBBAA hex codes
      AARRGGBB = false, -- 0xAARRGGBB hex codes
      rgb_fn = false, -- CSS rgb() and rgba() functions
      hsl_fn = false, -- CSS hsl() and hsla() functions
      css = false, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
      css_fn = false, -- Enable all CSS *functions*: rgb_fn, hsl_fn
      mode = "background", -- foreground, back, virtualtext
      -- Available methods are false / true / "normal" / "lsp" / "both"
      -- True is same as normal
      tailwind = false, -- Enable tailwind colors
      -- parsers can contain values used in |user_default_options|
      sass = { enable = false, parsers = { "css" } }, -- Enable sass colors
      virtualtext = "■",
      -- update color values even if buffer is not focused
      -- example use: cmp_menu, cmp_docs
      always_update = false,
    },
  },
  config = function(_, opts)
    require("colorizer").setup(opts)

    -- execute colorizer as soon as possible
    vim.defer_fn(function()
      require("colorizer").attach_to_buffer(0)
    end, 0)
  end,
}
