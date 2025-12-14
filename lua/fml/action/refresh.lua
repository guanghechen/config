local __module_name__ = "fml.action.refresh" ---@type string

---@class fml.action.refresh
local M = {}

---@return nil
function M.refresh_all()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  local devmode = dot.context.flight.devmode:snapshot() ---@type boolean

  vim.cmd("checktime")
  dot.tab.refresh()

  pcall(function()
    require("gitsigns").refresh()
  end)

  pcall(function()
    if vim.treesitter and bufnr_sourcefile ~= nil then
      local parser = vim.treesitter.get_parser(bufnr_sourcefile)
      if parser ~= nil then
        parser:invalidate()
      end
    end
  end)

  if devmode then
    pcall(function()
      require("plenary.reload").reload_module("dot.lang")
      require("plenary.reload").reload_module("dot.theme")
      require("plenary.reload").reload_module("dot.theme.hlgroup")
      era.command.execute(era.command.definitions.ux.reload_theme.uuid, "force")
    end)
  end

  dot.state.status.suppress_warning:next(true)
  dot.state.status.dirtier_statusline:mark_dirty()
  dot.state.status.dirtier_tabline:mark_dirty()
  vim.cmd("redraw!")

  local clients = vim.lsp.get_clients({ bufnr = bufnr_sourcefile }) ---@type vim.lsp.Client[]
  if #clients > 0 then
    for _, client in ipairs(clients) do
      if client.name ~= "copilot" then
        vim.lsp.enable(client.name, false)
      end
    end

    for _, client in ipairs(clients) do
      if client.name ~= "copilot" then
        vim.lsp.enable(client.name, true)
      end
    end

    vim.defer_fn(function()
      vim.cmd("edit")
    end, 100)
  end

  ark.reporter.info({
    from = __module_name__,
    message = "Refreshed all!",
  })
end

return M
