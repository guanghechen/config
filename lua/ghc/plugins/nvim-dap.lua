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

---@return nil
local function setup_node()
  local js_filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
  local vscode = require("dap.ext.vscode")
  vscode.type_to_filetypes["node"] = js_filetypes
  vscode.type_to_filetypes["pwa-node"] = js_filetypes

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
          eve.lsp.locate_mason_pkg_path("js-debug-adapter", "/js-debug/src/dapDebugServer.js"),
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
    dap.configurations[language] = dap.configurations[language] or {}
    vim.list_extend(dap.configurations[language], {
      {
        type = "pwa-node",
        request = "launch",
        name = "pwa-node: file",
        description = "pwa-node: launch file",
        program = "${file}",
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "pwa-node: attach",
        description = "pwa-node: attach",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
      },
    })
  end
end

---@return nil
local function setup_python()
  local dap = require("dap")

  local function resolve_python_path()
    local python_path = eve.state.lsp.get_python_bin_path() ---@type string|nil
    return python_path
  end

  dap.adapters.debugpy = dap.adapters.python
  dap.adapters.python = function(cb, config)
    if config.request == "attach" then
      local host = (config.connect or config).host or "127.0.0.1" ---@type string
      local port = (config.connect or config).port ---@type integer|nil

      local adapter = {
        type = "server",
        host = host,
        port = assert(port, "`connect.port` is required for a python `attach` configuration"),
        options = {
          source_filetype = "python",
        },
      }
      cb(adapter)
    else
      local adapter = {
        type = "executable",
        command = resolve_python_path(),
        args = { "-m", "debugpy.adapter" },
        options = {
          source_filetype = "python",
        },
      }
      cb(adapter)
    end
  end

  dap.configurations.python = {
    {
      type = "python",
      request = "attach",
      name = "python: attach",
      description = "python: attach",
      cwd = "${workspaceFolder}",
      connect = function()
        local host = eve.state.lsp.python_debug_host:snapshot() ---@type string
        local port = eve.state.lsp.python_debug_port:snapshot() ---@type integer
        return { host = host, port = port }
      end,
    },
    {
      type = "python",
      request = "launch",
      name = "python: file",
      description = "python: launch file",
      program = "${file}",
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      pythonPath = resolve_python_path,
    },
    {
      type = "python",
      request = "launch",
      name = "python: file:args",
      description = "python: launch file with args",
      program = "${file}",
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      args = function()
        local text = vim.fn.input("args: ")
        local utils = require("dap.utils")
        if utils.splitstr then
          return utils.splitstr(text)
        end
        return vim.split(text, " +")
      end,
      pythonPath = resolve_python_path,
    },
    {
      type = "python",
      request = "launch",
      name = "python: file:doctest",
      description = "python: launch doctest",
      module = "doctest",
      args = { "${file}" },
      noDebug = true,
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      pythonPath = resolve_python_path,
    },
  }
end

return {
  "nvim-dap",
  dependencies = {
    "nvim-dap-ui",
    "nvim-nio",
  },
  -- stylua: ignore start
  keys = {
    { "<F6>",       function() require("dap").continue() end,   mode = { "i", "n", "t", "v" },            desc = "dap: continue" },
    { "<F7>",       function() require("dap").step_into() end,  mode = { "i", "n", "t", "v" },            desc = "dap: step into" },
    { "<F8>",       function() require("dap").step_over() end,  mode = { "i", "n", "t", "v" },            desc = "dap: step over" },
    { "<F9>",       function() require("dap").step_out() end,   mode = { "i", "n", "t", "v" },            desc = "dap: step out" },
    { "<F10>",      function() require("dap").pause() end,      mode = { "i", "n", "t", "v" },            desc = "dap: pause" },
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "dap: breakpoint condition" },
    { "<leader>dO", function() require("dap").step_over() end,                                            desc = "dap: step over" },
    { "<leader>dC", function() require("dap").run_to_cursor() end,                                        desc = "dap: run to cursor" },
    { "<leader>dK", function() require("dap.ui.widgets").hover() end,                                     desc = "dap: hover widget" },
    { "<leader>da", function() require("dap").continue({ before = get_args }) end,                        desc = "dap: run with args" },
    { "<leader>db", function() require("dap").toggle_breakpoint() end,                                    desc = "dap: breakpoint" },
    { "<leader>dc", function() require("dap").continue() end,                                             desc = "dap: continue" },
    { "<leader>dg", function() require("dap").goto_() end,                                                desc = "dap: go to line (no execute)" },
    { "<leader>di", function() require("dap").step_into() end,                                            desc = "dap: step into" },
    { "<leader>dj", function() require("dap").down() end,                                                 desc = "dap: down" },
    { "<leader>dk", function() require("dap").up() end,                                                   desc = "dap: up" },
    { "<leader>dl", function() require("dap").run_last() end,                                             desc = "dap: run last" },
    { "<leader>do", function() require("dap").step_out() end,                                             desc = "dap: step out" },
    { "<leader>dp", function() require("dap").pause() end,                                                desc = "dap: pause" },
    { "<leader>dr", function() require("dap").repl.toggle() end,                                          desc = "dap: repl" },
    { "<leader>ds", function() require("dap").session() end,                                              desc = "dap: session" },
    { "<leader>dt", function() require("dap").terminate() end,                                            desc = "dap: terminate" },
    { "<leader>dw", function() require("dap.ui.widgets").hover() end,                                     desc = "dap: widgets" },
  },
  -- stylua: ignore end
  config = function()
    -- setup dap config by VsCode launch.json file
    local vscode = require("dap.ext.vscode")
    local json = require("plenary.json")
    vscode.json_decode = function(text)
      return vim.json.decode(json.json_strip_comments(text))
    end

    setup_node()
    setup_python()
  end,
}
