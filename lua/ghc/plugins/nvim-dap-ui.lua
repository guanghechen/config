return {
  "nvim-dap-ui",
  dependencies = {
    "nvim-dap-virtual-text",
    "nvim-nio",
  },
  -- stylua: ignore start
  keys = {
    { "<leader>du", function() require("dapui").toggle({ }) end, desc = "dap: ui" },
    { "<leader>de", function() require("dapui").eval() end, desc = "dap: eval", mode = {"n", "v"} },
  },
  -- stylua: ignore end
  opts = {
    icons = {
      expanded = eve.icon.ui.ArrowOpen,
      collapsed = eve.icon.ui.ArrowClosed,
      current_frame = eve.icon.ui.ArrowPresent,
    },
    controls = {
      enabled = true,
      icons = {
        pause = eve.icon.dap.Pause,
        play = eve.icon.dap.Play,
        rust_last = eve.icon.dap.RunLast,
        step_back = eve.icon.dap.StepBack,
        step_into = eve.icon.dap.StepInto,
        step_out = eve.icon.dap.StepOut,
        step_over = eve.icon.dap.StepOver,
        terminate = eve.icon.dap.Terminate,
        disconnect = eve.icon.dap.Disconnect,
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
      vim.cmd.stopinsert()
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
