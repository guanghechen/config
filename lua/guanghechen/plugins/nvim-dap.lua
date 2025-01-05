local locate_mason_pkg_path = require("guanghechen.lsp.common").locate_mason_pkg_path

---@param config {type?:string, args?:string[]|fun():string[]?}
local function get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or config.args or {} --[[@as string[] | string ]]
  local args_str = type(args) == "table" and table.concat(args, " ") or args --[[@as string]]

  config = vim.deepcopy(config)
  ---@cast args string[]
  config.args = function()
    local new_args = vim.fn.expand(vim.fn.input("Run with args: ", args_str)) --[[@as string]]
    if config.type and config.type == "java" then
      ---@diagnostic disable-next-line: return-type-mismatch
      return new_args
    end
    return require("dap.utils").splitstr(new_args)
  end
  return config
end

return {
  "nvim-dap",
  dependencies = {
    "mason-nvim-dap",
    "nvim-dap-ui",
    "nvim-dap-virtual-text",
  },
  -- stylua: ignore
  keys = {
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "dap: breakpoint condition" },
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "dap: toggle breakpoint" },
    { "<leader>dc", function() require("dap").continue() end, desc = "dap: run/continue" },
    { "<leader>da", function() require("dap").continue({ before = get_args }) end, desc = "dap: run with args" },
    { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "dap: run to cursor" },
    { "<leader>dg", function() require("dap").goto_() end, desc = "dap: go to line (no execute)" },
    { "<leader>di", function() require("dap").step_into() end, desc = "dap: step into" },
    { "<leader>dj", function() require("dap").down() end, desc = "dap: down" },
    { "<leader>dk", function() require("dap").up() end, desc = "dap: up" },
    { "<leader>dl", function() require("dap").run_last() end, desc = "dap: run last" },
    { "<leader>do", function() require("dap").step_out() end, desc = "dap: step out" },
    { "<leader>dO", function() require("dap").step_over() end, desc = "dap: step over" },
    { "<leader>dP", function() require("dap").pause() end, desc = "dap: pause" },
    { "<leader>dr", function() require("dap").repl.toggle() end, desc = "dap: toggle repl" },
    { "<leader>ds", function() require("dap").session() end, desc = "dap: session" },
    { "<leader>dt", function() require("dap").terminate() end, desc = "dap: terminate" },
    { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "dap: widgets" },
  },
  config = function()
    vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

    local json = require("plenary.json")

    -- setup dap config by VsCode launch.json file
    local vscode = require("dap.ext.vscode")
    local js_filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
    vscode.type_to_filetypes["node"] = js_filetypes
    vscode.type_to_filetypes["pwa-node"] = js_filetypes
    vscode.json_decode = function(str)
      return vim.json.decode(json.json_strip_comments(str))
    end

    local dap = require("dap")
    if not dap.adapters["pwa-node"] then
      require("dap").adapters["pwa-node"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          -- 💀 Make sure to update this path to point to your installation
          args = {
            locate_mason_pkg_path("js-debug-adapter", "/js-debug/src/dapDebugServer.js"),
            "${port}",
          },
        },
      }
    end
    if not dap.adapters["node"] then
      dap.adapters["node"] = function(cb, config)
        if config.type == "node" then
          config.type = "pwa-node"
        end
        local nativeAdapter = dap.adapters["pwa-node"]
        if type(nativeAdapter) == "function" then
          nativeAdapter(cb, config)
        else
          cb(nativeAdapter)
        end
      end
    end

    for _, language in ipairs(js_filetypes) do
      if not dap.configurations[language] then
        dap.configurations[language] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch file",
            program = "${file}",
            cwd = "${workspaceFolder}",
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end
  end,
}
