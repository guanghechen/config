local __module_name__ = "eve.state" ---@type string

local fs = require("eve.lib.fs")
local reporter = require("eve.lib.reporter")
local Disposable = require("eve.lib.collection.disposable")
local Subscriber = require("eve.lib.collection.subscriber")
local Scheduler = require("eve.lib.collection.scheduler")
local Ticker = require("eve.lib.collection.ticker")
local mvc = require("eve.builtin.mvc")
local nvim = require("eve.builtin.nvim")
local status = require("eve.builtin.status")
local editor = require("eve.state.editor")
local session = require("eve.state.session")
local workspace = require("eve.state.workspace")

---@class eve.state : eve.t.state
---@field private _storage              eve.t.state.storage
local M = {
  _storage = {},
}

---@return eve.t.state.data
function M.dump()
  local data_editor = editor.dump() ---@type eve.t.state.editor.data
  local data_workspace = workspace.dump() ---@type eve.t.state.workspace.data
  local data_session = session.dump() ---@type eve.t.state.session.data

  ---@type eve.t.state.data
  local data = {
    ---! editor
    theme = data_editor.theme,

    ---! workspace
    bookmark = data_workspace.bookmark,
    dressing = data_workspace.dressing,
    find = data_workspace.find,
    flight = data_workspace.flight,
    frecency = data_workspace.frecency,
    input_history = data_workspace.input_history,
    search = data_workspace.search,

    ---! session
    bufs = data_session.bufs,
    tabs = data_session.tabs,
    wins = data_session.wins,
    tab_history = data_session.tab_history,
  }
  return data
end

---@param storage                       eve.t.state.storage
---@return nil
function M.load(storage)
  storage = storage or M._storage ---@type eve.t.state.storage

  if editor.state == nil or (storage.editor and vim.fn.filereadable(storage.editor)) ~= 0 then
    local raw_data = storage.editor and fs.read_json({ filepath = storage.editor, silent_on_bad_path = true }) or nil
    if editor.state == nil or raw_data ~= nil then
      local data = editor.normalize(raw_data) ---@type eve.t.state.editor.data
      editor.load(data)
    end
  end

  if workspace.state == nil or (storage.workspace and vim.fn.filereadable(storage.workspace)) ~= 0 then
    local raw_data = storage.workspace and fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
      or nil
    if workspace.state == nil or raw_data ~= nil then
      local data = workspace.normalize(raw_data) ---@type eve.t.state.workspace.data
      workspace.load(data)
    end
  end

  if session.state == nil or (storage.session and vim.fn.filereadable(storage.session)) ~= 0 then
    local raw_data = storage.session and fs.read_json({ filepath = storage.session, silent_on_bad_path = true }) or nil
    if session.state == nil or raw_data ~= nil then
      local data = session.normalize(raw_data) ---@type eve.t.state.session.data
      session.load(data)
    end
  end

  if M.state == nil then
    ---@type eve.t.state.state.dirtier
    local dirtier = {
      editor_states = Ticker.new({ start = 0 }),
      workspace_states = Ticker.new({ start = 0 }),
      session_states = Ticker.new({ start = 0 }),
    }

    ---@type eve.t.state.state
    local state = {
      ---! editor
      theme = editor.state.theme,

      ---! workspace
      bookmark = workspace.state.bookmark,
      dressing = workspace.state.dressing,
      find = workspace.state.find,
      flight = workspace.state.flight,
      frecency = workspace.state.frecency,
      input_history = workspace.state.input_history,
      search = workspace.state.search,

      ---! session
      tab_history = session.state.tab_history,

      ---
      dirtier = dirtier,
    }
    M.state = state
  end
end

---@param storage                       eve.t.state.storage
---@return nil
function M.save(storage)
  storage = storage or M._storage ---@type eve.t.state.storage

  if storage.editor then
    local data_editor = editor.dump() ---@type eve.t.state.editor.data
    fs.write_json(storage.editor, data_editor, true)
  end

  if storage.workspace then
    local data_workspace = workspace.dump() ---@type eve.t.state.workspace.data
    fs.write_json(storage.workspace, data_workspace, true)
  end

  if storage.session then
    local data_session = session.dump() ---@type eve.t.state.session.data
    fs.write_json(storage.session, data_session, true)
  end
end

---@return eve.t.state.storage
function M.get_storage()
  return M._storage
end

---@param storage                       eve.t.state.storage
---@return nil
function M.set_storage(storage)
  M._storage = storage
end

---@param params                        eve.t.state.IWatchChangeParams
---@return nil
function M.watch_changes(params)
  local state = M.state ---@type eve.t.state.state

  mvc.observe({
    state.theme.theme,
    state.theme.transparency,
  }, function()
    if params.on_theme_changed then
      params.on_theme_changed()
    end

    state.dirtier.editor_states:tick()
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
    vim.cmd.redraw()
  end, true)

  mvc.observe({
    state.theme.relativenumber,
  }, function()
    state.dirtier.editor_states:tick()
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
    vim.cmd.redraw()
  end, true)

  mvc.observe({
    state.bookmark.pinned,

    ---
    state.dressing.autopairs,
    state.dressing.winsep,

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
    state.flight.lsp_code_lens,

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
    state.dirtier.workspace_states:tick()
    status.statusline_dirtier:mark_dirty()
  end, true)

  ---! Trigger statusline redraw.
  mvc.observe({
    ---find
    state.find.flag_gitignore,
    state.find.scope,

    ---flight
    state.flight.copilot,

    ---search
    state.search.flag_gitignore,
    state.search.flag_replace,
    state.search.scope,

    ---status
    status.lsp_msg,
  }, function()
    status.statusline_dirtier:mark_dirty()
  end, true)

  ---! Trigger tabline redraw.
  mvc.observe({
    state.flight.devmode,
  }, function()
    status.tabline_dirtier:mark_dirty()
  end, true)

  mvc.observe({
    state.flight.lsp_inlay_hints,
    state.flight.lsp_code_lens,
  }, function()
    pcall(function()
      vim.cmd("LspRestart")
    end)
  end, true)

  local editor_states_save_scheduler = Scheduler.new({
    name = "eve.state#editor/save",
    delay = 200,
    silent = not state.flight.devmode:snapshot(),
    task = function(callback)
      local raw_data_snapshot = M._storage.editor
          and fs.read_json({ filepath = M._storage.editor, silent_on_bad_path = true })
        or nil
      local snapshot = editor.normalize(raw_data_snapshot) ---@type eve.t.state.editor.data
      if not editor.equals(snapshot) then
        M.save({ editor = M._storage.editor })
      end
      callback("fulfilled")
    end,
  })
  state.dirtier.editor_states:subscribe(
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
      local autosave = state.flight.autosave:snapshot() ---@type boolean

      ---@type eve.t.state.storage
      local storage = {
        session = autosave and M._storage.session or nil,
        workspace = M._storage.workspace,
      }

      if autosave and M._storage.nvim_session_autosaved then
        nvim.save_nvim_session(M._storage.nvim_session_autosaved)
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
          M.load({ editor = M._storage.editor })
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
