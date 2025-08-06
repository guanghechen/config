local __module_name__ = "eve.context" ---@type string

---@class eve.context.__mods
local __mods = {
  behavior = "eve.context.editor.behavior",
  theme = "eve.context.editor.theme",

  --------------------------------------------------------------------------------------------------

  tab = "eve.context.session.tab",

  --------------------------------------------------------------------------------------------------

  bookmark = "eve.context.workspace.bookmark",
  flight = "eve.context.workspace.flight",
  frecency = "eve.context.workspace.frecency",
  lsp = "eve.context.workspace.lsp",
  option = "eve.context.workspace.option",
  plugin = "eve.context.workspace.plugin",
  search_file = "eve.context.workspace.search_file",
  select = "eve.context.workspace.select",
}

---@class eve.context.state.IWatchChangeParams
---@field public on_theme_changed       ?fun(): nil

---@class eve.context.storage
---@field public editor                 ?string
---@field public session                ?string
---@field public workspace              ?string
---@field public nvim_session           ?string
---@field public nvim_session_autosaved ?string

---@class eve.context.data
---@field public behavior               eve.context.behavior.data
---@field public theme                  eve.context.theme.data
---
---@field public tab                    eve.context.tab.data
---
---@field public bookmark               eve.context.bookmark.data
---@field public flight                 eve.context.flight.data
---@field public frecency               eve.context.frecency.data
---@field public lsp                    eve.context.lsp.data
---@field public option                 eve.context.option.data
---@field public plugin                 eve.context.plugin.data
---@field public search_file            eve.context.search_file.data
---@field public select                 eve.context.select.data

---@class eve.context.state
---
---@field public dump                   fun(): eve.context.data
---@field public load                   fun(storage: eve.context.storage): nil
---@field public save                   fun(storage: eve.context.storage): nil
---@field public get_storage            fun(): eve.context.storage
---@field public set_storage            fun(storage: eve.context.storage): nil
---
---@field public observe                fun(observables: std.collection.IObservable[], callback: fun(): nil, ignore_initial: boolean|nil): nil
---
---@field public refresh                fun(): nil
---@field public watch_changes          fun(params: eve.context.state.IWatchChangeParams): nil

---@class eve.context : eve.context.state
---@field public behavior               eve.context.behavior
---@field public theme                  eve.context.theme
---
---@field public tab                    eve.context.tab
---
---@field public bookmark               eve.context.bookmark
---@field public flight                 eve.context.flight
---@field public frecency               eve.context.frecency
---@field public lsp                    eve.context.lsp
---@field public option                 eve.context.option
---@field public plugin                 eve.context.plugin
---@field public search_file            eve.context.search_file
---@field public select                 eve.context.select
---@field private _storage              eve.context.storage
local M = setmetatable({
  _storage = {},
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m ~= nil then
      return require(m)
    end
    return rawget(t, k)
  end,
})

---@return eve.context.data
function M.dump()
  ---@type eve.context.data
  local data = {
    behavior = M.behavior.dump(),
    theme = M.theme.dump(),

    tab = M.tab.dump(),

    bookmark = M.bookmark.dump(),
    flight = M.flight.dump(),
    frecency = M.frecency.dump(),
    lsp = M.lsp.dump(),
    option = M.option.dump(),
    plugin = M.plugin.dump(),
    search_file = M.search_file.dump(),
    select = M.select.dump(),
  }
  return data
end

---@param storage                       eve.context.storage
---@param initialize                    boolean
---@return nil
function M.load(storage, initialize)
  if storage.editor or initialize then
    local data_editor = (
      storage.editor
      and vim.fn.filereadable(storage.editor) ~= 0
      and std.fs.read_json({ filepath = storage.editor, silent_on_bad_path = true })
    ) or {}
    M.behavior.load(data_editor.behavior)
    M.theme.load(data_editor.theme)
  end

  if storage.workspace or initialize then
    local data_workspace = (
      storage.workspace
      and vim.fn.filereadable(storage.workspace) ~= 0
      and std.fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
    ) or {}
    M.bookmark.load(data_workspace.bookmark)
    M.flight.load(data_workspace.flight)
    M.frecency.load(data_workspace.frecency)
    M.lsp.load(data_workspace.lsp)
    M.option.load(data_workspace.option)
    M.plugin.load(data_workspace.plugin)
    M.search_file.load(data_workspace.search_file)
    M.select.load(data_workspace.select)
  end

  if storage.session or initialize then
    local data_session = (
      storage.session
      and vim.fn.filereadable(storage.session) ~= 0
      and std.fs.read_json({ filepath = storage.session, silent_on_bad_path = true })
    ) or {}
    eve.status.reset()
    M.tab.load(data_session.tab)
  end
end

---@param storage                       eve.context.storage
---@return nil
function M.save(storage)
  if storage.editor then
    local data = {
      behavior = M.behavior.dump(),
      theme = M.theme.dump(),
    }
    std.fs.write_json(storage.editor, data, true)
  end

  if storage.session then
    local data = {
      tab = M.tab.dump(),
    }
    std.fs.write_json(storage.session, data, true)
  end

  if storage.workspace then
    if package.loaded["dap"] then
      M.lsp.refresh_breakpoints()
    end

    local data = {
      bookmark = M.bookmark.dump(),
      flight = M.flight.dump(),
      frecency = M.frecency.dump(),
      lsp = M.lsp.dump(),
      option = M.option.dump(),
      plugin = M.plugin.dump(),
      search = M.search_file.dump(),
      select = M.select.dump(),
      search_file = M.search_file.dump(),
    }
    std.fs.write_json(storage.workspace, data, true)
  end
end

---@return eve.context.storage
function M.get_storage()
  return M._storage
end

---@param storage                       eve.context.storage
---@return nil
function M.set_storage(storage)
  M._storage = storage
end

---@return nil
function M.watch_changes()
  local ticker_editor = std.Ticker.new({ start = 0 })
  local ticker_workspace = std.Ticker.new({ start = 0 })

  std.fn.observe({ M.theme.theme }, function()
    eve.context.theme.reload_theme(false, true)
  end, true)
  std.fn.observe({ M.theme.transparency }, function()
    eve.context.theme.reload_theme(true, true)
  end, true)

  std.fn.observe({
    M.option.relativenumber,
  }, function()
    local flag = M.option.relativenumber:snapshot() ---@type boolean
    local winnrs = vim.api.nvim_list_wins() ---@type integer[]
    vim.o.relativenumber = flag
    for _, winnr in ipairs(winnrs) do
      if vim.wo[winnr].number then
        vim.wo[winnr].relativenumber = flag
      end
    end
  end, true)

  std.fn.observe({
    M.behavior.auto_im,
    M.behavior.bufs_relative,
    M.theme.theme,
    M.theme.transparency,
    M.theme.username,
  }, function()
    ticker_editor:tick()
    eve.status.dirtier_statusline:mark_dirty()
    eve.status.dirtier_tabline:mark_dirty()
    vim.schedule(function()
      vim.cmd("redraw!")
    end)
  end, true)

  std.fn.observe({
    M.plugin.render_markdown,
    M.plugin.treesitter_context,
    M.option.relativenumber,
  }, function()
    eve.status.dirtier_statusline:mark_dirty()
    eve.status.dirtier_tabline:mark_dirty()
    vim.schedule(function()
      vim.cmd("redraw!")
    end)
  end, true)

  ---@type std.collection.IObservable[]
  local select_states = {
    M.bookmark.pinned,
    M.flight.ai,
    M.flight.ai_provider,
    M.flight.autoformat,
    M.flight.autoload,
    M.flight.autosave,
    M.flight.devmode,
    M.flight.dressing_clipboard,
    M.flight.dressing_hipairs,
    M.flight.dressing_illumniate,
    M.flight.dressing_input,
    M.flight.dressing_select,
    M.flight.dressing_winsep,
    M.flight.gitdiff_expand_all,
    M.lsp.breakpoints,
    M.lsp.code_lens,
    M.lsp.diagnostics_virt_lines,
    M.lsp.inlay_hints,
    M.lsp.python_debug_host,
    M.lsp.python_debug_port,
    M.lsp.python_venv_path,
  }
  std.fn.observe(select_states, function()
    ticker_workspace:tick()
    eve.status.dirtier_statusline:mark_dirty()
    eve.status.dirtier_tabline:mark_dirty()
  end, true)

  std.fn.observe({
    M.lsp.code_lens,
    M.lsp.diagnostics_virt_lines,
    M.lsp.inlay_hints,
  }, function()
    pcall(function()
      eve.command.execute(eve.command.definitions.lsp.restart.uuid)
    end)
  end, true)

  std.fn.observe({
    eve.status.msg_lsp,
    eve.status.msg_mode,
  }, function()
    eve.status.dirtier_statusline:mark_dirty()
  end)

  local scheduler = std.Scheduler.new({
    name = __module_name__,
    mode = "throttle",
    delay = 256,
    timeout = 3000,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function()
      if M._storage.editor then
        local raw_data = std.fs.read_json({ filepath = M._storage.editor, silent_on_bad_path = true }) or {}
        local data = { theme = M.theme.normalize(raw_data.theme) }
        local snapshot = { theme = M.theme.dump() }

        if
          data.theme.theme ~= snapshot.theme.theme
          or data.theme.transparency ~= snapshot.theme.transparency
          or data.theme.username ~= snapshot.theme.username
        then
          M.save({ editor = M._storage.editor })
        end
      end
      return true
    end,
  })
  ticker_editor:subscribe(
    std.Subscriber.new({
      on_next = function()
        scheduler:schedule()
      end,
    }),
    true
  )

  ---! Save when leave the editor.
  eve.status.add_disposable(std.Disposable.new({
    on_dispose = function()
      local autosave = M.flight.autosave:snapshot() ---@type boolean

      ---@type eve.context.storage
      local storage = {
        session = autosave and M._storage.session or nil,
        workspace = M._storage.workspace,
      }

      if autosave and M._storage.nvim_session_autosaved then
        eve.session.save_session(M._storage.nvim_session_autosaved)
      end

      M.save(storage)
    end,
  }))

  ---! watch the editor states file changes.
  if M._storage.editor and vim.fn.filereadable(M._storage.editor) then
    local unwatch = std.fs.watch_file({
      filepath = M._storage.editor,
      ---@diagnostic disable-next-line: unused-local
      on_event = function(p, event)
        if type(event) == "table" and event.change == true then
          vim.schedule(function()
            M.load({ editor = M._storage.editor }, false)
          end)
        end
      end,
      on_error = function(p, err)
        std.reporter.error({
          from = __module_name__,
          subject = "watch_changes",
          message = "Something got wrong while watching the editor states file changes!",
          details = { err = err, filepath = p },
        })
      end,
    })
    eve.status.add_disposable(std.Disposable.new({ on_dispose = unwatch }))
  end
end

return M
