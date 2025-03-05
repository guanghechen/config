local __module_name__ = "eve.state" ---@type string

local fs = require("eve.builtin.fs")
local reporter = require("eve.builtin.reporter")
local BatchDisposable = require("eve.collection.batch_disposable")
local Disposable = require("eve.collection.disposable")
local Scheduler = require("eve.collection.scheduler")
local Subscriber = require("eve.collection.subscriber")
local editor = require("eve.module.editor")
local session = require("eve.module.session")

local state_bookmark = require("eve.state.workspace.bookmark")
local state_buf = require("eve.state.session.buf")
local state_flight = require("eve.state.workspace.flight")
local state_frecency = require("eve.state.workspace.frecency")
local state_lsp = require("eve.state.workspace.lsp")
local state_option = require("eve.state.workspace.option")
local state_qflist = require("eve.state.session.qflist")
local state_search_file = require("eve.state.workspace.search_file")
local state_select = require("eve.state.workspace.select")
local state_status = require("eve.state.session.status")
local state_tab = require("eve.state.session.tab")
local state_theme = require("eve.state.editor.theme")
local state_widget = require("eve.state.session.widget")
local state_win = require("eve.state.session.win")

---@class eve.state.state.IWatchChangeParams
---@field public on_theme_changed       ?fun(): nil

---@class eve.state.storage
---@field public editor                 ?string
---@field public session                ?string
---@field public workspace              ?string
---@field public nvim_session           ?string
---@field public nvim_session_autosaved ?string

---@class eve.state.data
---@field public theme                  eve.state.theme.data
---
---@field public buf                    eve.state.buf.data
---@field public tab                    eve.state.tab.data
---@field public win                    eve.state.win.data
---@field public status                 eve.state.status.data
---
---@field public bookmark               eve.state.bookmark.data
---@field public flight                 eve.state.flight.data
---@field public frecency               eve.state.frecency.data
---@field public lsp                    eve.state.lsp.data
---@field public option                 eve.state.option.data
---@field public search_file            eve.state.search_file.data
---@field public select                 eve.state.select.data

---@class eve.state.state
---@field public theme                  eve.state.theme.state
---
---@field public buf                    eve.state.buf.state
---@field public tab                    eve.state.tab.state
---@field public win                    eve.state.win.state
---@field public qflist                 eve.state.qflist.state
---@field public status                 eve.state.win.state
---@field public widget                 eve.state.widget.state
---
---@field public bookmark               eve.state.bookmark.state
---@field public flight                 eve.state.flight.state
---@field public frecency               eve.state.frecency.state
---@field public lsp                    eve.state.lsp.state
---@field public option                 eve.state.option.state
---@field public search_file            eve.state.search_file.state
---@field public select                 eve.state.select.state
---
---@field public dump                   fun(): eve.state.data
---@field public load                   fun(storage: eve.state.storage): nil
---@field public save                   fun(storage: eve.state.storage): nil
---@field public get_storage            fun(): eve.state.storage
---@field public set_storage            fun(storage: eve.state.storage): nil
---
---@field public add_disposable         fun(disposable: eve.collection.IDisposable): nil
---@field public dispose                fun(): nil
---@field public observe                fun(observables: eve.collection.IObservable[], callback: fun(): nil, ignore_initial: boolean|nil): nil
---
---@field public refresh                fun(): nil
---@field public watch_changes          fun(params: eve.state.state.IWatchChangeParams): nil

---@class eve.state : eve.state.state
---@field private _storage              eve.state.storage
---@field private _disposables          eve.collection.BatchDisposable
local M = {
  _storage = {},
  _disposables = BatchDisposable.new(),
}

---@return eve.state.data
function M.dump()
  ---@type eve.state.data
  local data = {
    theme = state_theme.dump(),

    buf = state_buf.dump(),
    tab = state_tab.dump(),
    win = state_win.dump(),
    qflist = state_qflist.dump(),
    status = state_status.dump(),
    widget = state_widget.dump(),

    bookmark = state_bookmark.dump(),
    flight = state_flight.dump(),
    frecency = state_frecency.dump(),
    lsp = state_lsp.dump(),
    option = state_option.dump(),
    search_file = state_search_file.dump(),
    select = state_select.dump(),
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
      and fs.read_json({ filepath = storage.editor, silent_on_bad_path = true })
    ) or {}
    M.theme = state_theme.load(data_editor.theme)
  end

  if storage.workspace or initialize then
    local data_workspace = (
      storage.workspace
      and vim.fn.filereadable(storage.workspace) ~= 0
      and fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
    ) or {}
    M.bookmark = state_bookmark.load(data_workspace.bookmark)
    M.flight = state_flight.load(data_workspace.flight)
    M.frecency = state_frecency.load(data_workspace.frecency)
    M.lsp = state_lsp.load(data_workspace.lsp)
    M.option = state_option.load(data_workspace.option)
    M.search_file = state_search_file.load(data_workspace.search_select)
    M.select = state_select.load(data_workspace.select)
  end

  if storage.session or initialize then
    local data_session = (
      storage.session
      and vim.fn.filereadable(storage.session) ~= 0
      and fs.read_json({ filepath = storage.session, silent_on_bad_path = true })
    ) or {}
    M.buf = state_buf.load(data_session.buf)
    M.tab = state_tab.load(data_session.tab)
    M.win = state_win.load(data_session.win)
    M.qflist = state_qflist.load(data_session.qflist)
    M.status = state_status.load(data_session.status)
    M.widget = state_widget.load(data_session.widget)
  end
  M.buf.refresh_all()
  M.win.refresh_all()
  M.tab.refresh_all()

  M._initialized = true
end

---@param storage                       eve.state.storage
---@return nil
function M.save(storage)
  if storage.editor then
    local data = {
      theme = state_theme.dump(),
    }
    fs.write_json(storage.editor, data, true)
  end

  if storage.session then
    local data = {
      buf = state_buf.dump(),
      tab = state_tab.dump(),
      win = state_win.dump(),
    }
    fs.write_json(storage.session, data, true)
  end

  if storage.workspace then
    local data = {
      bookmark = state_bookmark.dump(),
      flight = state_flight.dump(),
      frecency = state_frecency.dump(),
      lsp = state_lsp.dump(),
      option = state_option.dump(),
      search = state_search_file.dump(),
      select = state_select.dump(),
    }
    fs.write_json(storage.workspace, data, true)
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

---@param disposable                    eve.collection.IDisposable
---@return nil
function M.add_disposable(disposable)
  M._disposables:add_disposable(disposable)
end

---@return nil
function M.dispose()
  M._disposables:dispose()
end

---@param observables                   eve.collection.IObservable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return nil
function M.observe(observables, callback, ignore_initial)
  for _, observable in ipairs(observables) do
    local subscriber = Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    observable:subscribe(subscriber, ignore_initial)
  end
end

---@return nil
function M.refresh()
  M.buf.refresh_all()
  M.win.refresh_all()
  M.tab.refresh_all()

  local unrefereced_bufnrs = M.tab.get_unrefereced_bufnrs() ---@type integer[]
  for _, bufnr in ipairs(unrefereced_bufnrs) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param params                        eve.state.state.IWatchChangeParams
---@return nil
function M.watch_changes(params)
  M.observe({
    M.theme.theme,
    M.theme.transparency,
  }, function()
    if params.on_theme_changed then
      params.on_theme_changed()
    end
  end, true)

  M.observe({
    M.option.relativenumber,
  }, function()
    local flag = M.option.relativenumber:snapshot() ---@type boolean
    local winnrs = vim.api.nvim_list_wins() ---@type integer[]
    vim.o.relativenumber = flag
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if editor.is_buf_valid(bufnr) then
        vim.wo[winnr].relativenumber = flag
      end
    end
  end, true)

  M.observe({
    M.flight.render_markdown,
    M.flight.smear_cursor,
    M.flight.spellcheck,
    M.flight.treesitter_context,
    M.option.relativenumber,
    M.theme.theme,
    M.theme.transparency,
    M.theme.username,
  }, function()
    M.status.ticker_editor:tick()
    M.status.dirtier_statusline:mark_dirty()
    M.status.dirtier_tabline:mark_dirty()
    vim.cmd.redraw()
  end, true)

  ---@type eve.collection.IObservable[]
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
    M.flight.dressing_winsep_fixed,
    M.flight.dressing_winsep_float,
    M.flight.gitdiff_expand_all,
    M.flight.lsp_inlay_hints,
    M.flight.lsp_code_lens,
    M.lsp.python_venv_path,
    M.select.find_buffer_scope,
    M.select.find_file_scope,
  }
  for _, key in ipairs(state_select.keys) do
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
    M.flight.lsp_inlay_hints,
    M.flight.lsp_code_lens,
  }, function()
    pcall(function()
      vim.cmd.LspRestart()
    end)
  end, true)

  M.observe({
    M.status.lsp_msg,
  }, function()
    M.status.dirtier_statusline:mark_dirty()
  end)

  local editor_states_save_scheduler = Scheduler.new({
    name = "eve.state#editor/save",
    delay = 200,
    task = function(callback)
      if M._storage.editor then
        local raw_data = fs.read_json({ filepath = M._storage.editor, silent_on_bad_path = true }) or {}
        local data = {
          theme = state_theme.normalize(raw_data.theme),
        }
        local snapshot = {
          theme = state_theme.dump(),
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
    Subscriber.new({
      on_next = function()
        editor_states_save_scheduler:schedule()
      end,
    }),
    true
  )

  ---! Save when leave the editor.
  M.add_disposable(Disposable.new({
    on_dispose = function()
      local autosave = M.flight.autosave:snapshot() ---@type boolean

      ---@type eve.state.storage
      local storage = {
        session = autosave and M._storage.session or nil,
        workspace = M._storage.workspace,
      }

      if autosave and M._storage.nvim_session_autosaved then
        session.save_session(M._storage.nvim_session_autosaved)
      end

      M.save(storage)
    end,
  }))

  ---! watch the editor states file changes.
  if M._storage.editor and vim.fn.filereadable(M._storage.editor) then
    local unwatch = fs.watch_file({
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
        reporter.error({
          from = __module_name__,
          subject = "watch_changes",
          message = "Something got wrong while watching the editor states file changes!",
          details = { err = err, filepath = p },
        })
      end,
    })
    M.add_disposable(Disposable.new({ on_dispose = unwatch }))
  end
end

return M
