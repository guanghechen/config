local ft = require("eve.constant.filetype")
local state = require("eve.state")

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
    local smear = require("smear_cursor")
    smear.setup(opts)

    state.observe({ state.flight.smear_cursor }, function()
      local flag = state.flight.smear_cursor:snapshot() ---@type boolean
      smear.enabled = flag

      vim.defer_fn(function()
        if not flag then
          local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
          for _, bufnr in ipairs(bufnrs) do
            local filetype = vim.bo[bufnr].filetype ---@type string
            if filetype == ft.SMEAR_CURSOR then
              vim.api.nvim_buf_delete(bufnr, { force = true })
            end
          end
        end
      end, 200)
    end, false)
  end,
}
