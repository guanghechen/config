return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@telescope-file-browser.nvim",
  name = "telescope-file-browser.nvim",
  main = "telescope-file-browser",
  config = function()
    require("telescope").load_extension("file_browser")
  end,
  dependencies = {
    "telescope.nvim",
  },
}
