local __module_name__ = "eve.state" ---@type string

---@class eve.state.__mods
local __mods = {
  behavior = "eve.state.editor.behavior",
  theme = "eve.state.editor.theme",

  --------------------------------------------------------------------------------------------------

  editor = "eve.state.session.editor",
  status = "eve.state.session.status",
  tab = "eve.state.session.tab",

  --------------------------------------------------------------------------------------------------

  bookmark = "eve.state.workspace.bookmark",
  flight = "eve.state.workspace.flight",
  frecency = "eve.state.workspace.frecency",
  lsp = "eve.state.workspace.lsp",
  option = "eve.state.workspace.option",
  plugin = "eve.state.workspace.plugin",
  search_file = "eve.state.workspace.search_file",
  select = "eve.state.workspace.select",
}

---@class eve.state.__lazy
---@field public _disposables           eve.std.collection.BatchDisposable|nil
local __lazy = {
  _disposables = nil,
}

---@class eve.state.state.IWatchChangeParams
---@field public on_theme_changed       ?fun(): nil

---@class eve.state.storage
---@field public editor                 ?string
---@field public session                ?string
---@field public workspace              ?string
---@field public nvim_session           ?string
---@field public nvim_session_autosaved ?string

---@class eve.state.data
---@field public behavior               eve.state.behavior.data
---@field public theme                  eve.state.theme.data
---
---@field public editor                 eve.state.editor.data
---@field public status                 eve.state.status.data
---@field public tab                    eve.state.tab.data
---
---@field public bookmark               eve.state.bookmark.data
---@field public flight                 eve.state.flight.data
---@field public frecency               eve.state.frecency.data
---@field public lsp                    eve.state.lsp.data
---@field public option                 eve.state.option.data
---@field public plugin                 eve.state.plugin.data
---@field public search_file            eve.state.search_file.data
---@field public select                 eve.state.select.data

---@class eve.state.state
---
---@field public dump                   fun(): eve.state.data
---@field public load                   fun(storage: eve.state.storage): nil
---@field public save                   fun(storage: eve.state.storage): nil
---@field public get_storage            fun(): eve.state.storage
---@field public set_storage            fun(storage: eve.state.storage): nil
---
---@field public add_disposable         fun(disposable: eve.std.collection.IDisposable): nil
---@field public dispose                fun(): nil
---@field public observe                fun(observables: eve.std.collection.IObservable[], callback: fun(): nil, ignore_initial: boolean|nil): nil
---
---@field public refresh                fun(): nil
---@field public watch_changes          fun(params: eve.state.state.IWatchChangeParams): nil

---@class eve.state : eve.state.state
---@field public behavior               eve.state.behavior
---@field public theme                  eve.state.theme
---
---@field public editor                 eve.state.editor
---@field public status                 eve.state.status
---@field public tab                    eve.state.tab
---
---@field public bookmark               eve.state.bookmark
---@field public flight                 eve.state.flight
---@field public frecency               eve.state.frecency
---@field public lsp                    eve.state.lsp
---@field public option                 eve.state.option
---@field public plugin                 eve.state.plugin
---@field public search_file            eve.state.search_file
---@field public select                 eve.state.select
---@field private _storage              eve.state.storage
---@field private _disposables          eve.std.collection.BatchDisposable
local M = setmetatable({
  _storage = {},
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m ~= nil then
      return require(m)
    end

    if k == "_disposables" then
      __lazy._disposables = __lazy._disposables or eve.std.BatchDisposable.new() ---@type eve.std.collection.BatchDisposable
      return __lazy._disposables
    end
    return rawget(t, k)
  end,
})

---@return eve.state.data
function M.dump()
  ---@type eve.state.data
  local data = {
    behavior = M.behavior.dump(),
    theme = M.theme.dump(),

    editor = M.editor.dump(),
    status = M.status.dump(),
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

---@param storage                       eve.state.storage
---@param initialize                    boolean
---@return nil
function M.load(storage, initialize)
  if storage.editor or initialize then
    local data_editor = (
      storage.editor
      and vim.fn.filereadable(storage.editor) ~= 0
      and eve.fs.read_json({ filepath = storage.editor, silent_on_bad_path = true })
    ) or {}
    M.behavior.load(data_editor.behavior)
    M.theme.load(data_editor.theme)
  end

  if storage.workspace or initialize then
    local data_workspace = (
      storage.workspace
      and vim.fn.filereadable(storage.workspace) ~= 0
      and eve.fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
    ) or {}
    M.bookmark.load(data_workspace.bookmark)
    M.flight.load(data_workspace.flight)
    M.frecency.load(data_workspace.frecency)
    M.lsp.load(data_workspace.lsp)
    M.option.load(data_workspace.option)
    M.plugin.load(data_workspace.plugin)
    M.search_file.load(data_workspace.search_select)
    M.select.load(data_workspace.select)
  end

  if storage.session or initialize then
    local data_session = (
      storage.session
      and vim.fn.filereadable(storage.session) ~= 0
      and eve.fs.read_json({ filepath = storage.session, silent_on_bad_path = true })
    ) or {}
    M.editor.load(data_session.editor)
    M.status.load(data_session.status)
    M.tab.load(data_session.tab)
  end
end

---@param storage                       eve.state.storage
---@return nil
function M.save(storage)
  if storage.editor then
    local data = {
      behavior = M.behavior.dump(),
      theme = M.theme.dump(),
    }
    eve.fs.write_json(storage.editor, data, true)
  end

  if storage.session then
    local data = {
      tab = M.tab.dump(),
    }
    eve.fs.write_json(storage.session, data, true)
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
    }
    eve.fs.write_json(storage.workspace, data, true)
  end
end

---@return eve.state.storage
function M.get_storage()
  return M._storage
end

---@param storage                       eve.state.storage
---@return nil
function M.set_storage(storage)
  M._storage = storage
end

---@param disposable                    eve.std.collection.IDisposable
---@return nil
function M.add_disposable(disposable)
  M._disposables:add_disposable(disposable)
end

---@return nil
function M.dispose()
  M._disposables:dispose()
end

---@param observables                   eve.std.collection.IObservable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return nil
function M.observe(observables, callback, ignore_initial)
  for _, observable in ipairs(observables) do
    local subscriber = eve.std.Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    observable:subscribe(subscriber, ignore_initial)
  end
end

---@return nil
function M.refresh()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabnr in ipairs(tabnrs) do
    eve.tab.resolve(tabnr, true)
  end

  M.editor.on_refresh()

  local bufnrs_unreferenced = eve.tab.retrieve_unreferenced_bufnrs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs_unreferenced) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M.watch_changes()
  M.observe({ M.theme.theme }, function()
    eve.state.theme.reload_theme(false, true)
  end, true)
  M.observe({ M.theme.transparency }, function()
    eve.state.theme.reload_theme(true, true)
  end, true)

  M.observe({
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

  M.observe({
    M.behavior.auto_im,
    M.behavior.bufs_relative,
    M.theme.theme,
    M.theme.transparency,
    M.theme.username,
  }, function()
    M.status.ticker_editor:tick()
    M.status.dirtier_statusline:mark_dirty()
    M.status.dirtier_tabline:mark_dirty()
    vim.schedule(function()
      vim.cmd("redraw!")
    end)
  end, true)

  M.observe({
    M.plugin.render_markdown,
    M.plugin.treesitter_context,
    M.option.relativenumber,
  }, function()
    M.status.dirtier_statusline:mark_dirty()
    M.status.dirtier_tabline:mark_dirty()
    vim.schedule(function()
      vim.cmd("redraw!")
    end)
  end, true)

  ---@type eve.std.collection.IObservable[]
  local select_states = {
    M.bookmark.pinned,
    M.flight.ai,
    M.flight.ai_provider,
    M.flight.autoformat,
    M.flight.autoload,
    M.flight.autosave,
    M.flight.devmode,
    M.flight.dressing_hipairs,
    M.flight.dressing_illumniate,
    M.flight.dressing_input,
    M.flight.dressing_select,
    M.flight.dressing_winsep,
    M.flight.gitdiff_expand_all,
    M.lsp.breakpoints,
    M.lsp.code_lens,
    M.lsp.inlay_hints,
    M.lsp.spellcheck,
    M.lsp.python_debug_host,
    M.lsp.python_debug_port,
    M.lsp.python_venv_path,
    M.select.find_buffer_scope,
    M.select.find_file_scope,
  }
  for _, key in ipairs(M.select.keys) do
    local select_item = M.select[key] ---@type eve.state.select.item.state
    table.insert(select_states, select_item.flag_case_sensitive)
    table.insert(select_states, select_item.flag_gitignore)
    table.insert(select_states, select_item.flag_exclude)
    table.insert(select_states, select_item.flag_fuzzy)
    table.insert(select_states, select_item.flag_regex)
    table.insert(select_states, select_item.includes)
    table.insert(select_states, select_item.excludes)
  end
  M.observe(select_states, function()
    M.status.ticker_workspace:tick()
    M.status.dirtier_statusline:mark_dirty()
  end, true)

  ---! Trigger tabline redraw.
  M.observe({
    M.flight.devmode,
  }, function()
    M.status.dirtier_tabline:mark_dirty()
  end, true)

  M.observe({
    M.lsp.code_lens,
    M.lsp.inlay_hints,
  }, function()
    pcall(function()
      vim.cmd.LspRestart()
    end)
  end, true)

  M.observe({
    M.status.lsp_msg,
    M.status.recording_msg,
  }, function()
    M.status.dirtier_statusline:mark_dirty()
  end)

  local editor_states_save_scheduler = eve.std.Scheduler.new({
    name = "eve.state#editor/save",
    delay = 200,
    task = function(callback)
      if M._storage.editor then
        local raw_data = eve.fs.read_json({ filepath = M._storage.editor, silent_on_bad_path = true }) or {}
        local data = {
          theme = M.theme.normalize(raw_data.theme),
        }
        local snapshot = {
          theme = M.theme.dump(),
        }

        if
          data.theme.theme ~= snapshot.theme.theme
          or data.theme.transparency ~= snapshot.theme.transparency
          or data.theme.username ~= snapshot.theme.username
        then
          M.save({ editor = M._storage.editor })
        end
      end
      callback("fulfilled")
    end,
  })
  M.status.ticker_editor:subscribe(
    eve.std.Subscriber.new({
      on_next = function()
        editor_states_save_scheduler:schedule()
      end,
    }),
    true
  )

  ---! Save when leave the editor.
  M.add_disposable(eve.std.Disposable.new({
    on_dispose = function()
      local autosave = M.flight.autosave:snapshot() ---@type boolean

      ---@type eve.state.storage
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
    local unwatch = eve.fs.watch_file({
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
        eve.reporter.error({
          from = __module_name__,
          subject = "watch_changes",
          message = "Something got wrong while watching the editor states file changes!",
          details = { err = err, filepath = p },
        })
      end,
    })
    M.add_disposable(eve.std.Disposable.new({ on_dispose = unwatch }))
  end
end

return M
