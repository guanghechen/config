local ft = require("eve.constant.filetype")

return {
  "render-markdown.nvim",
  ft = ft.get_markdown_filetypes(),
  cmd = { "RenderMarkdown" },
  opts = {
    file_types = ft.get_markdown_filetypes(),
  },
}
