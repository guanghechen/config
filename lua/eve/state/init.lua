local __module_name__ = "eve.state" ---@type string

local fs = require("eve.lib.fs")
local reporter = require("eve.lib.reporter")
local Disposable = require("eve.lib.collection.disposable")
local Scheduler = require("eve.lib.collection.scheduler")
local Subscriber = require("eve.lib.collection.subscriber")
local mvc = require("eve.builtin.mvc")
local save_nvim_session = require("eve.builtin.nvim").save_nvim_session

local state_bookmark = require("eve.state.workspace.bookmark")
local state_buf = require("eve.state.session.buf")
local state_find = require("eve.state.workspace.find")
local state_find_buffer = require("eve.state.workspace.find_buffer")
local state_flight = require("eve.state.workspace.flight")
local state_frecency = require("eve.state.workspace.frecency")
local state_input_history = require("eve.state.workspace.input_history")
local state_search = require("eve.state.workspace.search")
local state_status = require("eve.state.session.status")
local state_tab = require("eve.state.session.tab")
local state_theme = require("eve.state.editor.theme")
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
---@field public search                 eve.state.search.data

---@class eve.state.state
---@field public theme                  eve.state.theme.state
---
---@field public buf                    eve.state.buf.state
---@field public tab                    eve.state.tab.state
---@field public win                    eve.state.win.state
---@field public status                 eve.state.win.state
---
---@field public bookmark               eve.state.bookmark.state
---@field public find                   eve.state.find.state
---@field public find_buffer            eve.state.find_buffer.state
---@field public flight                 eve.state.flight.state
---@field public frecency               eve.state.frecency.state
---@field public input_history          eve.state.input_history.state
---@field public search                 eve.state.search.state
---
---@field public dump                   fun(): eve.state.data
---@field public load                   fun(storage: eve.state.storage): nil
---@field public save                   fun(storage: eve.state.storage): nil
---@field public get_storage            fun(): eve.state.storage
---@field public set_storage            fun(storage: eve.state.storage): nil
---@field public watch_changes          fun(params: eve.state.state.IWatchChangeParams): nil

---@class eve.state : eve.state.state
---@field private _storage              eve.state.storage
local M = {
  _storage = {},
}

---@return eve.state.data
function M.dump()
  ---@type eve.state.data
  local data = {
    theme = state_theme.dump(),

    buf = state_buf.dump(),
    tab = state_tab.dump(),
    win = state_win.dump(),
    status = state_status.dump(),

    bookmark = state_bookmark.dump(),
    find = state_find.dump(),
    find_buffer = state_find_buffer.dump(),
    flight = state_flight.dump(),
    frecency = state_frecency.dump(),
    input_history = state_input_history.dump(),
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
  M.search = state_search.load(data_workspace.search)

  local data_session = (
    storage.session
    and vim.fn.filereadable(storage.session) ~= 0
    and fs.read_json({ filepath = storage.session, silent_on_bad_path = true })
  ) or {}
  M.buf = state_buf.load(data_session.buf)
  M.tab = state_tab.load(data_session.tab)
  M.win = state_win.load(data_session.win)
  M.status = state_status.load(data_session.status)

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

---@param params                        eve.state.state.IWatchChangeParams
---@return nil
function M.watch_changes(params)
  mvc.observe({
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

  mvc.observe({
    M.theme.relativenumber,
  }, function()
    M.status.ticker_editor:tick()
    M.status.dirtier_statusline:mark_dirty()
    M.status.dirtier_tabline:mark_dirty()
    vim.cmd.redraw()
  end, true)

  mvc.observe({
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
    M.flight.dressing_hi_pairs,
    M.flight.dressing_winsep_fixed,
    M.flight.dressing_winsep_float,
    M.flight.lsp_inlay_hints,
    M.flight.lsp_code_lens,

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
  mvc.observe({
    M.flight.devmode,
  }, function()
    M.status.dirtier_tabline:mark_dirty()
  end, true)

  mvc.observe({
    M.flight.lsp_inlay_hints,
    M.flight.lsp_code_lens,
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

        if
          data.theme.theme ~= snapshot.theme.theme
          or data.theme.transparency ~= snapshot.theme.transparency
          or data.theme.relativenumber ~= snapshot.theme.relativenumber
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
  mvc.add_disposable(Disposable.new({
    on_dispose = function()
      local autosave = M.flight.autosave:snapshot() ---@type boolean

      ---@type eve.state.storage
      local storage = {
        session = autosave and M._storage.session or nil,
        workspace = M._storage.workspace,
      }

      if autosave and M._storage.nvim_session_autosaved then
        save_nvim_session(M._storage.nvim_session_autosaved)
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
    mvc.add_disposable(Disposable.new({ on_dispose = unwatch }))
  end
end

return M
