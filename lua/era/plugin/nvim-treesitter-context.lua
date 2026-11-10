---@see https://github.com/nvim-treesitter/nvim-treesitter-context

return {
  name = "nvim-treesitter-context",
  event = "VeryLazy",
  opts = {
    enable = true,
    line_numbers = true,
    max_lines = "20%",
    min_window_height = 30,
    mode = "cursor",
    multiline_threshold = 20,
    multiwindow = true,
    separator = nil,
    trim_scope = "outer",
    zindex = dot.var.zindex.TREESITTER_CONTEXT,
  },
  config = function(_, opts)
    local tsc = require("treesitter-context")
    -- The plugin loads whatever the toggle says, so that turning it on later can show the context.
    opts.enable = dot.context.plugin.treesitter_context:snapshot()
    tsc.setup(opts)

    stl.fn.observe({ dot.context.plugin.treesitter_context }, function()
      local flag = dot.context.plugin.treesitter_context:snapshot() ---@type boolean
      if flag then
        tsc.enable()
      else
        tsc.disable()
      end
    end, false)
  end,
}
