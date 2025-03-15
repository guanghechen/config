return {
  "smear-cursor.nvim",
  event = { "VeryLazy" },
  opts = {
    cursor_color = nil,
    distance_stop_animating = 0.5,
    hide_target_hack = false,
    stiffness = 0.8,
    trailing_stiffness = 0.5,
  },
  config = function(_, opts)
    local plugin = require("smear_cursor")
    plugin.setup(opts)

    eve.state.observe({ eve.state.plugin.smear_cursor }, function()
      local flag = eve.state.plugin.smear_cursor:snapshot() ---@type boolean
      plugin.enabled = flag

      vim.defer_fn(function()
        if not flag then
          local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
          for _, bufnr in ipairs(bufnrs) do
            local filetype = vim.bo[bufnr].filetype ---@type string
            if filetype == eve.filetype.SMEAR_CURSOR then
              vim.api.nvim_buf_delete(bufnr, { force = true })
            end
          end
        end
      end, 200)
    end, false)
  end,
}
