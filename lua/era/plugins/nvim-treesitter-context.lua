---@see https://github.com/nvim-treesitter/nvim-treesitter-context/tree/660861b1849256398f70450afdf93908d28dc945

return {
  name = "nvim-treesitter-context",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
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
    zindex = ark.var.zindex.TREESITTER_CONTEXT,
  },
  config = function(_, opts)
    local tsc = require("treesitter-context")
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
