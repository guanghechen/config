---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.refresh_all" ---@type string

---@return nil
local function refresh_all()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  local devmode = dot.context.flight.devmode:snapshot() ---@type boolean

  vim.cmd("checktime")
  dot.tab.refresh()
  stl.async.run(function()
    era.m.git.state.refresh():await()
  end)
  era.m.git.buffer.invalidate_compare_text_all()

  pcall(function()
    if bufnr_sourcefile ~= nil then
      local parser = vim.treesitter.get_parser(bufnr_sourcefile)
      if parser ~= nil then
        parser:invalidate()
      end
    end
  end)

  if devmode then
    pcall(function()
      stl.hot.reload_module("stl.lang")
      stl.hot.reload_module("dot.theme")
      dot.command.definitions.ux.reload_theme:execute()
    end)
  end

  dot.state.status.suppress_warning:next(true)
  dot.state.status.dirtier_statusline:mark_dirty()
  dot.state.status.dirtier_tabline:mark_dirty()
  vim.cmd("redraw!")

  local names = {} ---@type string[]
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr_sourcefile })) do
    if not vim.list_contains(names, client.name) then
      names[#names + 1] = client.name
    end
  end
  if #names > 0 then
    -- Each client is started again once its server exits, attached to the buffers it had.
    vim.cmd("lsp restart " .. table.concat(names, " "))
  end

  stl.reporter.info({
    from = __module_name__,
    message = "Refreshed all!",
  })
end

return refresh_all
