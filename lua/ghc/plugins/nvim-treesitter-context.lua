---! https://github.com/nvim-treesitter/nvim-treesitter-context
return {
  name = "nvim-treesitter-context",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  opts = {
    enable = true,
    line_numbers = true,
    max_lines = 3,
    min_window_height = 30,
    mode = "cursor",
    multiline_threshold = 20,
    separator = nil,
    trim_scope = "outer",
    zindex = 30,
  },
  config = function(_, opts)
    local tsc = require("treesitter-context")
    tsc.setup(opts)

    eve.fn.observe({ eve.context.plugin.treesitter_context }, function()
      local flag = eve.context.plugin.treesitter_context:snapshot() ---@type boolean
      if flag then
        tsc.enable()
      else
        tsc.disable()
      end
    end, false)
  end,
}
