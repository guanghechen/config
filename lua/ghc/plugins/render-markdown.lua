local state = require("eve.state")

return {
  "render-markdown.nvim",
  ft = eve.filetype.get_markdown_filetypes(),
  cmd = { "RenderMarkdown" },
  opts = {
    file_types = eve.filetype.get_markdown_filetypes(),
    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },
    heading = {
      sign = false,
      icons = {},
    },
    checkbox = {
      enabled = false,
    },
  },
  config = function(_, opts)
    local plugin = require("render-markdown")
    plugin.setup(opts)

    state.observe({ state.plugin.render_markdown }, function()
      local flag = state.plugin.render_markdown:snapshot() ---@type boolean
      if flag then
        plugin.enable()
      else
        plugin.disable()
      end
    end, false)
  end,
}
