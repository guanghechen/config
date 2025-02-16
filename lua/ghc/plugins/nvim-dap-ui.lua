return {
  "nvim-dap-ui",
  dependencies = { "nvim-nio" },
  -- stylua: ignore start
  keys = {
    { "<leader>du", function() require("dapui").toggle({ }) end, desc = "dap: ui" },
    { "<leader>de", function() require("dapui").eval() end, desc = "dap: eval", mode = {"n", "v"} },
  },
  -- stylua: ignore end
  opts = {},
  config = function(_, opts)
    local dap = require("dap")
    local dapui = require("dapui")
    dapui.setup(opts)
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open({})
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close({})
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close({})
    end
  end,
}
