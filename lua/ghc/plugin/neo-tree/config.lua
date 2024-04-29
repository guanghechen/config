local function config(_, opts)
  local function on_move(data)
    require("ghc.core.lsp.common").on_rename(data.source, data.destination)
  end

  local events = require("neo-tree.events")
  opts.event_handlers = opts.event_handlers or {}
  vim.list_extend(opts.event_handlers, {
    { event = events.FILE_MOVED, handler = on_move },
    { event = events.FILE_RENAMED, handler = on_move },
  })
  require("neo-tree").setup(opts)
  vim.api.nvim_create_autocmd("TermClose", {
    pattern = "*lazygit",
    callback = function()
      if package.loaded["neo-tree.sources.git_status"] then
        require("neo-tree.sources.git_status").refresh()
      end
    end,
  })
end

return config
