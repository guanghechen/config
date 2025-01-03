local __module_name__ = "eve.state" ---@type string

local fs = require("eve.builtin.fs")
local reporter = require("eve.builtin.reporter")
local BatchDisposable = require("eve.collection.batch_disposable")
local Disposable = require("eve.collection.disposable")
local Scheduler = require("eve.collection.scheduler")
local Subscriber = require("eve.collection.subscriber")
local setting = require("eve.constant.setting")
local editor = require("eve.module.editor")
local session = require("eve.module.session")

local state_bookmark = require("eve.state.workspace.bookmark")
local state_buf = require("eve.state.session.buf")
local state_find = require("eve.state.workspace.find")
local state_find_buffer = require("eve.state.workspace.find_buffer")
local state_flight = require("eve.state.workspace.flight")
local state_frecency = require("eve.state.workspace.frecency")
local state_input_history = require("eve.state.workspace.input_history")
local state_option = require("eve.state.workspace.option")
local state_qflist = require("eve.state.session.qflist")
local state_search = require("eve.state.workspace.search")
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
---@field public find                   eve.state.find.data
---@field public find_buffer            eve.state.find_buffer.data
---@field public flight                 eve.state.flight.data
---@field public frecency               eve.state.frecency.data
---@field public input_history          eve.state.input_history.data
---@field public option                 eve.state.option.data
---@field public search                 eve.state.search.data

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
---@field public find                   eve.state.find.state
---@field public find_buffer            eve.state.find_buffer.state
---@field public flight                 eve.state.flight.state
---@field public frecency               eve.state.frecency.state
---@field public input_history          eve.state.input_history.state
---@field public option                 eve.state.option.state
---@field public search                 eve.state.search.state
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
---@field public open_filepath          fun(filepath: string, lnum?: integer, col?: integer): boolean
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
    find = state_find.dump(),
    find_buffer = state_find_buffer.dump(),
    flight = state_flight.dump(),
    frecency = state_frecency.dump(),
    input_history = state_input_history.dump(),
    option = state_option.dump(),
    search = state_search.dump(),
  }
  return data
end

---@param storage                       eve.state.storage
---@return nil
function M.load(storage)
  local data_editor = (
    storage.editor
    and vim.fn.filereadable(storage.editor) ~= 0
    and fs.read_json({ filepath = storage.editor, silent_on_bad_path = true })
  ) or {}
  M.theme = state_theme.load(data_editor.theme)

  local data_workspace = (
    storage.workspace
    and vim.fn.filereadable(storage.workspace) ~= 0
    and fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
  ) or {}
  M.bookmark = state_bookmark.load(data_workspace.bookmark)
  M.find = state_find.load(data_workspace.find)
  M.find_buffer = state_find_buffer.load(data_workspace.find_buffer)
  M.flight = state_flight.load(data_workspace.flight)
  M.frecency = state_frecency.load(data_workspace.frecency)
  M.input_history = state_input_history.load(data_workspace.input_history)
  M.option = state_option.load(data_workspace.option)
  M.search = state_search.load(data_workspace.search)

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

  M.buf.refresh_all()
  M.win.refresh_all()
  M.tab.refresh_all()
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
      find = state_find.dump(),
      find_buffer = state_find_buffer.dump(),
      flight = state_flight.dump(),
      frecency = state_frecency.dump(),
      input_history = state_input_history.dump(),
      option = state_option.dump(),
      search = state_search.dump(),
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

---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(filepath, lnum, col)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_listed = M.tab.resolve_winnr_listed(tabnr) ---@type integer
  if winnr_listed > 0 and vim.api.nvim_win_is_valid(winnr_listed) then
    M.buf.open_filepath(winnr_listed, filepath, lnum, col)
    return true
  end

  local meta_tab = M.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab ~= nil and meta_tab.tabtype == setting.TT_NORMAL then
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    local non_floating_winnr = 0 ---@type integer
    for _, winnr in ipairs(winnrs) do
      local config = vim.api.nvim_win_get_config(winnr)
      if not config.relative or config.relative == "" then
        non_floating_winnr = winnr
        break
      end
    end

    if non_floating_winnr > 0 then
      vim.api.nvim_set_current_win(non_floating_winnr)
      vim.cmd("vsplit")

      local winnr = vim.api.nvim_get_current_win() ---@type integer
      M.buf.open_filepath(winnr, filepath, lnum, col)
      return true
    end
  end
  return false
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

    M.status.ticker_editor:tick()
    M.status.dirtier_statusline:mark_dirty()
    M.status.dirtier_tabline:mark_dirty()
    vim.cmd.redraw()
  end, true)

  M.observe({
    M.option.relativenumber,
  }, function()
    M.status.ticker_editor:tick()
    M.status.dirtier_statusline:mark_dirty()
    M.status.dirtier_tabline:mark_dirty()

    local flag = M.option.relativenumber:snapshot() ---@type boolean
    local winnrs = vim.api.nvim_list_wins() ---@type integer[]
    vim.o.relativenumber = flag
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if editor.is_buf_valid(bufnr) then
        vim.wo[winnr].relativenumber = flag
      end
    end

    vim.cmd("redraw!")
  end, true)

  M.observe({
    M.bookmark.pinned,

    ---
    M.find.flag_case_sensitive,
    M.find.flag_gitignore,
    M.find.flag_fuzzy,
    M.find.flag_regex,
    M.find.includes,
    M.find.excludes,
    M.find.keyword,
    M.find.scope,

    ---
    M.find_buffer.flag_case_sensitive,
    M.find_buffer.flag_fuzzy,
    M.find_buffer.flag_regex,
    M.find_buffer.keyword,
    M.find_buffer.scope,

    ---
    M.flight.autoload,
    M.flight.autosave,
    M.flight.copilot,
    M.flight.devmode,
    M.flight.dressing_hipairs,
    M.flight.dressing_winsep_fixed,
    M.flight.dressing_winsep_float,
    M.flight.lsp_inlay_hints,
    M.flight.lsp_code_lens,
    M.flight.spellcheck,

    ---
    M.search.flag_case_sensitive,
    M.search.flag_gitignore,
    M.search.flag_regex,
    M.search.flag_replace,
    M.search.max_filesize,
    M.search.max_matches,
    M.search.includes,
    M.search.excludes,
    M.search.keyword,
    M.search.replacement,
    M.search.scope,
    M.search.search_paths,
  }, function()
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
    M.flight.spellcheck,
  }, function()
    pcall(function()
      vim.cmd("LspRestart")
    end)
  end, true)

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

        if data.theme.theme ~= snapshot.theme.theme or data.theme.transparency ~= snapshot.theme.transparency then
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
            M.load({ editor = M._storage.editor })
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
