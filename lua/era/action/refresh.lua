local __module_name__ = "era.action.refresh" ---@type string

---@class era.action.refresh
local M = {}

---@return nil
function M.refresh_all()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  local devmode = dot.context.flight.devmode:snapshot() ---@type boolean

  vim.cmd("checktime")
  dot.tab.refresh()
  dot.git.state.refresh_async(true)

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
      ark.hot.reload_module("ark.lang")
      ark.hot.reload_module("ark.theme")
      ark.hot.reload_module("dot.theme")
      dot.command.definitions.ux.reload_theme:execute("force")
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

  stl.reporter.info({
    from = __module_name__,
    message = "Refreshed all!",
  })
end

return M
