---@see https://github.com/nvim-mini/mini.trailspace/tree/f8083ca969e1b2098480c10f3c3c4d2ce3586680

return {
  name = "mini.trailspace",
  event = "VeryLazy",
  opts = {
    only_in_normal_buffers = true,
  },
  config = function(_, opts)
    local MiniTrailspace = require("mini.trailspace")
    MiniTrailspace.setup(opts)

    std.fn.observe({ eve.context.plugin.mini_trailspace }, function()
      local flag = eve.context.plugin.mini_trailspace:snapshot() ---@type boolean
      vim.g.minitrailspace_disable = not flag

      for _, winnr in ipairs(vim.api.nvim_list_wins()) do
        vim.api.nvim_win_call(winnr, function()
          if flag then
            MiniTrailspace.highlight()
          else
            MiniTrailspace.unhighlight()
          end
        end)
      end
    end, false)
  end,
}
