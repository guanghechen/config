local reporter = require("eve.builtin.reporter")
local Disposable = require("eve.collection.disposable")
local Subscriber = require("eve.collection.subscriber")
local Scheduler = require("eve.collection.scheduler")
local Ticker = require("eve.collection.ticker")
local editor = require("eve.context.editor")
local session = require("eve.context.session")
local workspace = require("eve.context.workspace")
local mvc = require("eve.globals.mvc")
local fs = require("eve.std.fs")
local std_nvim = require("eve.std.nvim")

---@class eve.context : eve.t.context
---@field public storage                eve.t.context.storage
local M = {
  storage = {},
}

---@return eve.t.context.data
function M.dump()
  local data_editor = editor.dump() ---@type eve.t.context.editor.data
  local data_session = session.dump() ---@type eve.t.context.session.data
  local data_workspace = workspace.dump() ---@type eve.t.context.workspace.data

  ---@type eve.t.context.data
  local data = {
    ---! editor
    dressing = data_editor.dressing,
    theme = data_editor.theme,

    ---! session
    bookmark = data_session.bookmark,
    find = data_session.find,
    flight = data_session.flight,
    search = data_session.search,

    ---! workspace
    bufs = data_workspace.bufs,
    tabs = data_workspace.tabs,
    wins = data_workspace.wins,
    frecency = data_workspace.frecency,
    input_history = data_workspace.input_history,
    tab_history = data_workspace.tab_history,
  }
  return data
end

---@param storage                       eve.t.context.storage
---@return nil
function M.load(storage)
  storage = storage or M.storage ---@type eve.t.context.storage

  if editor.state == nil or (storage.editor and vim.fn.filereadable(storage.editor)) ~= 0 then
    local raw_data = storage.editor and fs.read_json({ filepath = storage.editor, silent_on_bad_path = true }) or nil
    if editor.state == nil or raw_data ~= nil then
      local data = editor.normalize(raw_data) ---@type eve.t.context.editor.data
      editor.load(data)
    end
  end

  if session.state == nil or (storage.session and vim.fn.filereadable(storage.session)) ~= 0 then
    local raw_data = storage.session and fs.read_json({ filepath = storage.session, silent_on_bad_path = true }) or nil
    if session.state == nil or raw_data ~= nil then
      local data = session.normalize(raw_data) ---@type eve.t.context.session.data
      session.load(data)
    end
  end

  if workspace.state == nil or (storage.workspace and vim.fn.filereadable(storage.workspace)) ~= 0 then
    local raw_data = storage.workspace and fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
      or nil
    if workspace.state == nil or raw_data ~= nil then
      local data = workspace.normalize(raw_data) ---@type eve.t.context.workspace.data
      workspace.load(data)
    end
  end

  if M.state == nil then
    ---@type eve.t.context.state
    local state = {
      ---! editor
      dressing = editor.state.dressing,
      theme = editor.state.theme,

      ---! session
      bookmark = session.state.bookmark,
      find = session.state.find,
      flight = session.state.flight,
      search = session.state.search,

      ---! workspace
      bufs = workspace.state.bufs,
      tabs = workspace.state.tabs,
      wins = workspace.state.wins,
      status = workspace.state.status,
      frecency = workspace.state.frecency,
      input_history = workspace.state.input_history,
      tab_history = workspace.state.tab_history,

      ---
      editor_states_ticker = Ticker.new({ start = 0 }),
      session_states_ticker = Ticker.new({ start = 0 }),
      workspace_states_ticker = Ticker.new({ start = 0 }),
    }
    M.state = state
  else
    local state = M.state ---@type eve.t.context.state

    ---! workspace
    state.bufs = workspace.state.bufs
    state.tabs = workspace.state.tabs
    state.wins = workspace.state.wins
  end
end

---@param storage                       eve.t.context.storage
---@return nil
function M.save(storage)
  storage = storage or M.storage ---@type eve.t.context.storage

  if storage.editor then
    local data_editor = editor.dump() ---@type eve.t.context.editor.data
    fs.write_json(storage.editor, data_editor, true)
  end

  if storage.session then
    local data_session = session.dump() ---@type eve.t.context.session.data
    fs.write_json(storage.session, data_session, true)
  end

  if storage.workspace then
    local data_workspace = workspace.dump() ---@type eve.t.context.workspace.data
    fs.write_json(storage.workspace, data_workspace, true)
  end
end

---@param bufs                          table<integer, eve.t.context.state.buf.IItem>
---@return nil
function M.set_bufs(bufs)
  M.state.bufs = bufs
  workspace.state.bufs = bufs
end

---@param tabs                          table<integer, eve.t.context.state.tab.IItem>
---@return nil
function M.set_tabs(tabs)
  M.state.tabs = tabs
  workspace.state.tabs = tabs
end

---@param wins                          table<integer, eve.t.context.state.win.IItem>
---@return nil
function M.set_wins(wins)
  M.state.wins = wins
  workspace.state.wins = wins
end

---@param storage                       eve.t.context.storage
---@return nil
function M.set_storage(storage)
  M.storage = storage
end

---@param params                        eve.t.context.IWatchChangeParams
---@return nil
function M.watch_changes(params)
  local state = M.state ---@type eve.t.context.state

  mvc.observe({
    state.theme.theme,
    state.theme.transparency,
  }, function()
    if params.on_theme_changed then
      params.on_theme_changed()
    end

    vim.cmd.redraw()
    state.editor_states_ticker:tick()
  end, true)

  mvc.observe({
    state.dressing.autopairs,
    state.dressing.winsep,
    state.theme.relativenumber,
  }, function()
    vim.cmd.redraw()
    state.editor_states_ticker:tick()
  end, true)

  mvc.observe({
    state.bookmark.pinned,

    ---
    state.find.flag_case_sensitive,
    state.find.flag_gitignore,
    state.find.flag_fuzzy,
    state.find.flag_regex,
    state.find.includes,
    state.find.excludes,
    state.find.keyword,
    state.find.scope,

    ---
    state.flight.autoload,
    state.flight.autosave,
    state.flight.copilot,
    state.flight.devmode,
    state.flight.lsp_inlay_hints,

    ---
    state.search.flag_case_sensitive,
    state.search.flag_gitignore,
    state.search.flag_regex,
    state.search.flag_replace,
    state.search.max_filesize,
    state.search.max_matches,
    state.search.includes,
    state.search.excludes,
    state.search.keyword,
    state.search.replacement,
    state.search.scope,
    state.search.search_paths,
  }, function()
    state.session_states_ticker:tick()
  end, true)

  ---! Trigger statusline redraw.
  mvc.observe({
    ---find
    state.find.flag_case_sensitive,
    state.find.flag_gitignore,
    state.find.flag_fuzzy,
    state.find.flag_regex,
    state.find.scope,

    ---flight
    state.flight.copilot,

    ---search
    state.search.flag_case_sensitive,
    state.search.flag_gitignore,
    state.search.flag_regex,
    state.search.flag_replace,
    state.search.scope,

    ---status
    state.status.lsp_msg,
  }, function()
    vim.cmd.redrawstatus()
  end, true)

  ---! Trigger tabline redraw.
  mvc.observe({
    ---flight
    state.flight.devmode,
  }, function()
    vim.cmd.redrawtabline()
  end, true)

  mvc.observe({
    state.flight.lsp_inlay_hints,
  }, function()
    pcall(function()
      vim.cmd("LspRestart")
    end)
  end, true)

  local editor_states_save_scheduler = Scheduler.new({
    name = "eve.context#editor/save",
    delay = 200,
    silent = not state.flight.devmode:snapshot(),
    task = function(callback)
      local raw_data_snapshot = M.storage.editor
          and fs.read_json({ filepath = M.storage.editor, silent_on_bad_path = true })
        or nil
      local snapshot = editor.normalize(raw_data_snapshot) ---@type eve.t.context.editor.data
      if not editor.equals(snapshot) then
        M.save({ editor = M.storage.editor })
      end
      callback("fulfilled")
    end,
  })
  state.editor_states_ticker:subscribe(
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
      local session_has_changed = state.session_states_ticker:snapshot() > 0 ---@type boolean
      local autosave = state.flight.autosave:snapshot() ---@type boolean

      ---@type eve.t.context.storage
      local storage = {
        session = session_has_changed and M.storage.session or nil,
        workspace = autosave and M.storage.workspace or nil,
      }

      if autosave and M.storage.nvim_session_autosaved then
        std_nvim.save_nvim_session(M.storage.nvim_session_autosaved)
      end

      M.save(storage)
    end,
  }))

  ---! watch the editor states file changes.
  if M.storage.editor and vim.fn.filereadable(M.storage.editor) then
    local unwatch = fs.watch_file({
      filepath = M.storage.editor,
      ---@diagnostic disable-next-line: unused-local
      on_event = function(p, event)
        if type(event) == "table" and event.change == true then
          M.load({ editor = M.storage.editor })
        end
      end,
      on_error = function(p, err)
        reporter.error({
          from = "eve.context",
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
