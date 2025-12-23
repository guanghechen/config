return {
  "nvim-dap-ui",
  dependencies = {
    "nvim-dap-virtual-text",
    "nvim-nio",
  },
  -- stylua: ignore start
  keys = {
    { "<leader>du", function() require("dapui").toggle({ }) end, desc = "dap: ui" },
    { "<leader>de", function() require("dapui").eval() end, desc = "dap: eval", mode = {"n", "x"} },
  },
  -- stylua: ignore end
  opts = {
    icons = {
      expanded = ark.icon.ui.ArrowOpen,
      collapsed = ark.icon.ui.ArrowClosed,
      current_frame = ark.icon.ui.ArrowPresent,
    },
    controls = {
      enabled = true,
      icons = {
        pause = ark.icon.dap.Pause,
        play = ark.icon.dap.Play,
        rust_last = ark.icon.dap.RunLast,
        step_back = ark.icon.dap.StepBack,
        step_into = ark.icon.dap.StepInto,
        step_out = ark.icon.dap.StepOut,
        step_over = ark.icon.dap.StepOver,
        terminate = ark.icon.dap.Terminate,
        disconnect = ark.icon.dap.Disconnect,
      },
    },
  },
  config = function(_, opts)
    local dap = require("dap")
    local dapui = require("dapui")
    dapui.setup(opts)
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open({})
      vim.cmd("DapVirtualTextEnable")
      vim.cmd("stopinsert")
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      vim.cmd("DapVirtualTextDisable")
      dapui.close({})
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      vim.cmd("DapVirtualTextDisable")
      dapui.close({})
    end
    dap.listeners.before.disconnect["dapui_config"] = function()
      vim.cmd("DapVirtualTextDisable")
      dapui.close({})
    end
  end,
}
