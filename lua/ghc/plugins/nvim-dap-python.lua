local state = require("eve.state")

return {
  "nvim-dap-python",
  dependencies = {
    "nvim-dap",
  },
  -- stylua: ignore start
  keys = {
    { "<leader>dPt", function() require("dap-python").test_method() end, desc = "Debug Method", ft = "python" },
    { "<leader>dPc", function() require("dap-python").test_class() end, desc = "Debug Class", ft = "python" },
  },
  -- stylua: ignore end
  config = function()
    local dap_python = pcall(require, "dap-python")
    local python_path = state.lsp.get_python_bin_path() ---@type string|nil
    dap_python.setup(python_path)
    dap_python.resolve_python = function()
      return state.lsp.python_venv_path:snapshot()
    end
  end,
}
