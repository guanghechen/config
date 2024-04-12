return {
  "norcalli/nvim-colorizer.lua",
  lazy = false,
  config = function()
    require("colorizer").setup({
      "css",
      "html",
      "javascript",
      "tmux",
    })
  end,
}
