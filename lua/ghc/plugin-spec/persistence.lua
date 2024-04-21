local path = require("ghc.core.util.path")

local function pre_save()
  -- remove buffers whose files are located outside of cwd
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local workspace = path.workspace()
    local bufpath = vim.api.nvim_buf_get_name(buf) .. "/"
    if not bufpath:match("^" .. vim.pesc(workspace)) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end

return {
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    enabled = false,
    opts = {
      options = vim.opt.sessionoptions:get(),
      pre_save = pre_save,
    },
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        desc = "Restore Session",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore Last Session",
      },
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Don't Save Current Session",
      },
    },
  },
}
