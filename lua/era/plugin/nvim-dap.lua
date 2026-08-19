---@param config                        {type?:string, args?:string[]|fun():string[]?}
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
  name = "nvim-dap",
  dependencies = {
    "nvim-dap-ui",
    "nvim-nio",
  },
  -- stylua: ignore start
  keys = {
    { lhs = "<F6>",       rhs = function() require("dap").continue() end,   mode = { "i", "n", "t", "x" },            desc = "dap: continue" },
    { lhs = "<F7>",       rhs = function() require("dap").step_into() end,  mode = { "i", "n", "t", "x" },            desc = "dap: step into" },
    { lhs = "<F8>",       rhs = function() require("dap").step_over() end,  mode = { "i", "n", "t", "x" },            desc = "dap: step over" },
    { lhs = "<F9>",       rhs = function() require("dap").step_out() end,   mode = { "i", "n", "t", "x" },            desc = "dap: step out" },
    { lhs = "<F10>",      rhs = function() require("dap").pause() end,      mode = { "i", "n", "t", "x" },            desc = "dap: pause" },
    { lhs = "<leader>dB", rhs = function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "dap: breakpoint condition" },
    { lhs = "<leader>dO", rhs = function() require("dap").step_over() end,                                            desc = "dap: step over" },
    { lhs = "<leader>dC", rhs = function() require("dap").run_to_cursor() end,                                        desc = "dap: run to cursor" },
    { lhs = "<leader>dK", rhs = function() require("dap.ui.widgets").hover() end,                                     desc = "dap: hover widget" },
    { lhs = "<leader>da", rhs = function() require("dap").continue({ before = get_args }) end,                        desc = "dap: run with args" },
    { lhs = "<leader>db", rhs = function() require("dap").toggle_breakpoint() end,                                    desc = "dap: breakpoint" },
    { lhs = "<leader>dc", rhs = function() require("dap").continue() end,                                             desc = "dap: continue" },
    { lhs = "<leader>dg", rhs = function() require("dap").goto_() end,                                                desc = "dap: go to line (no execute)" },
    { lhs = "<leader>di", rhs = function() require("dap").step_into() end,                                            desc = "dap: step into" },
    { lhs = "<leader>dj", rhs = function() require("dap").down() end,                                                 desc = "dap: down" },
    { lhs = "<leader>dk", rhs = function() require("dap").up() end,                                                   desc = "dap: up" },
    { lhs = "<leader>dl", rhs = function() require("dap").run_last() end,                                             desc = "dap: run last" },
    { lhs = "<leader>do", rhs = function() require("dap").step_out() end,                                             desc = "dap: step out" },
    { lhs = "<leader>dp", rhs = function() require("dap").pause() end,                                                desc = "dap: pause" },
    { lhs = "<leader>dr", rhs = function() require("dap").repl.toggle() end,                                          desc = "dap: repl" },
    { lhs = "<leader>ds", rhs = function() require("dap").session() end,                                              desc = "dap: session" },
    { lhs = "<leader>dt", rhs = function() require("dap").terminate() end,                                            desc = "dap: terminate" },
    { lhs = "<leader>dw", rhs = function() require("dap.ui.widgets").hover() end,                                     desc = "dap: widgets" },
  },
  -- stylua: ignore end
  config = function()
    local vscode = require("dap.ext.vscode")
    vscode.json_decode = function(text)
      return stl.json.decode(text, { luanil = { object = true, array = true } })
    end
  end,
}
