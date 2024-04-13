return {
  "NvChad/nvim-colorizer.lua",
  lazy = false,
  config = function()
    require("colorizer").setup({
      filetypes = {
        "css",
        "html",
        "javascript",
        "tmux",
      },
    })
  end,
}
