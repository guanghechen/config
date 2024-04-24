local config = function(_, opts)
  dofile(vim.g.base46_cache .. "mason")
  require("mason").setup(opts)
  require("mason-lspconfig").setup(require("ghc.plugin.mason-lspconfig.opts"))

  -- custom nvchad cmd to install all mason binaries listed
  vim.api.nvim_create_user_command("MasonInstallAll", function()
    if opts.ensure_installed and #opts.ensure_installed > 0 then
      vim.cmd("MasonInstall " .. table.concat(opts.ensure_installed, " "))
    end
  end, {})
end

return config
