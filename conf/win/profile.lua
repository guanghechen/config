---@class conf.win.profile
local M = {}

---@param config table
function M.setup(config)
  -- Use WSL SSH domain as default
  config.default_domain = "SSH:wsl"

  -- Launch Menu (equivalent to Windows Terminal's profiles list)
  config.launch_menu = {
    {
      label = "PowerShell 7",
      args = { "pwsh.exe" },
      domain = { DomainName = "local" },
    },
    -- {
    --   label = "Windows PowerShell",
    --   args = { "powershell.exe" },
    --   domain = { DomainName = "local" },
    -- },
    -- {
    --   label = "Command Prompt",
    --   args = { "cmd.exe" },
    --   domain = { DomainName = "local" },
    -- },
    {
      label = "WSL Ubuntu",
      args = { "wsl.exe", "-d", "Ubuntu" },
      domain = { DomainName = "local" },
    },
  }

  -- Set environment variables for each profile
  config.set_environment_variables = {
    -- Set default terminal type
    TERM = "xterm-256color",
  }
end

return M
