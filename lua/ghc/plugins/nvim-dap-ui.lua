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
      expanded = dot.icon.ui.ArrowOpen,
      collapsed = dot.icon.ui.ArrowClosed,
      current_frame = dot.icon.ui.ArrowPresent,
    },
    controls = {
      enabled = true,
      icons = {
        pause = dot.icon.dap.Pause,
        play = dot.icon.dap.Play,
        rust_last = dot.icon.dap.RunLast,
        step_back = dot.icon.dap.StepBack,
        step_into = dot.icon.dap.StepInto,
        step_out = dot.icon.dap.StepOut,
        step_over = dot.icon.dap.StepOver,
        terminate = dot.icon.dap.Terminate,
        disconnect = dot.icon.dap.Disconnect,
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
