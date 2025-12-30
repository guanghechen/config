return {
  name = "nvim-dap-ui",
  dependencies = {
    "nvim-dap-virtual-text",
    "nvim-nio",
  },
  -- stylua: ignore start
  keys = {
    { lhs = "<leader>du", rhs = function() require("dapui").toggle({ }) end, desc = "dap: ui" },
    { lhs = "<leader>de", rhs = function() require("dapui").eval() end, desc = "dap: eval", mode = {"n", "x"} },
  },
  -- stylua: ignore end
  opts = {
    icons = {
      expanded = stl.icon.ui.ArrowOpen,
      collapsed = stl.icon.ui.ArrowClosed,
      current_frame = stl.icon.ui.ArrowPresent,
    },
    controls = {
      enabled = true,
      icons = {
        pause = stl.icon.dap.Pause,
        play = stl.icon.dap.Play,
        rust_last = stl.icon.dap.RunLast,
        step_back = stl.icon.dap.StepBack,
        step_into = stl.icon.dap.StepInto,
        step_out = stl.icon.dap.StepOut,
        step_over = stl.icon.dap.StepOver,
        terminate = stl.icon.dap.Terminate,
        disconnect = stl.icon.dap.Disconnect,
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
