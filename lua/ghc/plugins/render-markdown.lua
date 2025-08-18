return {
  "render-markdown.nvim",
  ft = eve.filetype.get_markdown_filetypes(),
  cmd = { "RenderMarkdown" },
  opts = {
    bullet = {
      icons = { "", "", "", "⟡" },
    },
    checkbox = {
      enabled = true,
    },
    code = {
      conceal_delimiters = false,
      render_modes = true,
      right_pad = 1,
      sign = false,
      width = "block",
    },
    completions = {
      blink = { enabled = false },
      lsp = { enabled = false },
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
    require("fml.dressing.plugin").mock_miniicons()

    local plugin = require("render-markdown")
    plugin.setup(opts)

    std.fn.observe({ eve.context.plugin.render_markdown }, function()
      local flag = eve.context.plugin.render_markdown:snapshot() ---@type boolean
      if flag then
        plugin.enable()
      else
        plugin.disable()
      end
    end, false)
  end,
}
