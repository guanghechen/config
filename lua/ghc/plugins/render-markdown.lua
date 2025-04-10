return {
  "render-markdown.nvim",
  ft = eve.filetype.get_markdown_filetypes(),
  cmd = { "RenderMarkdown" },
  opts = {
    checkbox = {
      enabled = false,
    },
    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },
    completions = {
      blink = { enabled = true },
      lsp = { enabled = true },
    },
    file_types = eve.filetype.get_markdown_filetypes(),
    heading = {
      sign = false,
      icons = {},
    },
    quote = {
      repeat_linebreak = true,
    },
  },
  config = function(_, opts)
    local plugin = require("render-markdown")
    plugin.setup(opts)

    eve.state.observe({ eve.state.plugin.render_markdown }, function()
      local flag = eve.state.plugin.render_markdown:snapshot() ---@type boolean
      if flag then
        plugin.enable()
      else
        plugin.disable()
      end
    end, false)
  end,
}
