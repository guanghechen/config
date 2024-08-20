return {
  name = "telescope-file-browser.nvim",
  config = function()
    require("telescope").load_extension("file_browser")
  end,
  dependencies = {
    "telescope.nvim",
  },
}
