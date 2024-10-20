local Disposable = require("eve.collection.disposable")
local Subscriber = require("eve.collection.subscriber")
local Ticker = require("eve.collection.ticker")
local client = require("eve.context.client")
local session = require("eve.context.session")
local workspace = require("eve.context.workspace")
local mvc = require("eve.globals.mvc")
local fs = require("eve.std.fs")
local reporter = require("eve.std.reporter")
local std_nvim = require("eve.std.nvim")

---@class eve.context : t.eve.context
---@field public storage                t.eve.context.storage
local M = {
  storage = {},
}

---@return t.eve.context.data
function M.dump()
  local data_client = client.dump() ---@type t.eve.context.client.data
  local data_session = session.dump() ---@type t.eve.context.session.data
  local data_workspace = workspace.dump() ---@type t.eve.context.workspace.data

  ---@type t.eve.context.data
  local data = {
    ---! client
    theme = data_client.theme,

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

---@param storage                       t.eve.context.storage
---@return nil
function M.load(storage)
  storage = storage or M.storage ---@type t.eve.context.storage

  if client.state == nil or (storage.client and vim.fn.filereadable(storage.client)) ~= 0 then
    local raw_data = storage.client and eve.fs.read_json({ filepath = storage.client, silent_on_bad_path = true })
      or nil
    if client.state == nil or raw_data ~= nil then
      local data = client.normalize(raw_data) ---@type t.eve.context.client.data
      client.load(data)
    end
  end

  if session.state == nil or (storage.session and vim.fn.filereadable(storage.session)) ~= 0 then
    local raw_data = storage.session and eve.fs.read_json({ filepath = storage.session, silent_on_bad_path = true })
      or nil
    if session.state == nil or raw_data ~= nil then
      local data = session.normalize(raw_data) ---@type t.eve.context.session.data
      session.load(data)
    end
  end

  if workspace.state == nil or (storage.workspace and vim.fn.filereadable(storage.workspace)) ~= 0 then
    local raw_data = storage.workspace and eve.fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
      or nil
    if workspace.state == nil or raw_data ~= nil then
      local data = workspace.normalize(raw_data) ---@type t.eve.context.workspace.data
      workspace.load(data)
    end
  end

  if M.state == nil then
    ---@type t.eve.context.state
    local state = {
      ---! client
      theme = client.state.theme,

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
      winline_dirty_nr = workspace.state.winline_dirty_nr,

      ---
      client_has_changed = Ticker.new({ start = 0 }),
      session_has_changed = Ticker.new({ start = 0 }),
      workspace_has_changed = Ticker.new({ start = 0 }),
    }
    M.state = state
  end
end

---@param storage                       t.eve.context.storage
---@return nil
function M.save(storage)
  storage = storage or M.storage ---@type t.eve.context.storage

  if storage.client then
    local data_client = client.dump() ---@type t.eve.context.client.data
    eve.fs.write_json(storage.client, data_client, true)
  end

  if storage.session then
    local data_session = session.dump() ---@type t.eve.context.session.data
    eve.fs.write_json(storage.session, data_session, true)
  end

  if storage.workspace then
    local data_workspace = workspace.dump() ---@type t.eve.context.workspace.data
    eve.fs.write_json(storage.workspace, data_workspace, true)
  end
end

---@param storage                       t.eve.context.storage
---@return nil
function M.set_storage(storage)
  M.storage = storage
end

---@param params                        t.eve.context.IWatchChangeParams
---@return nil
function M.watch_changes(params)
  local state = M.state ---@type t.eve.context.state

  mvc.observe({
    state.theme.theme,
    state.theme.mode,
    state.theme.transparency,
    state.theme.relativenumber,
  }, function()
    if params.on_theme_changed then
      params.on_theme_changed()
    end

    vim.cmd.redraw()
    state.client_has_changed:tick()
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
    state.session_has_changed:tick()
  end, true)

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
  }, function()
    vim.cmd.redrawstatus()
  end, true)

  mvc.observe({
    ---flight
    state.flight.devmode,
  }, function()
    vim.cmd.redrawtabline()
  end, true)

  local client_last_saved_tick = 0 ---@type integer
  state.client_has_changed:subscribe(Subscriber.new({
    on_next = function()
      client_last_saved_tick = state.client_has_changed:snapshot() ---@type integer
      vim.defer_fn(function()
        local tick = state.client_has_changed:snapshot() ---@type integer
        if client_last_saved_tick == tick then
          local raw_data_snapshot = M.storage.client
              and eve.fs.read_json({ filepath = M.storage.client, silent_on_bad_path = true })
            or nil
          local snapshot = client.normalize(raw_data_snapshot) ---@type t.eve.context.client.data
          if not client.equals(snapshot) then
            M.save({ client = M.storage.client })
          end
        end
      end, 200)
    end,
  }))

  ---! Save when leave the editor.
  mvc.add_disposable(Disposable.new({
    on_dispose = function()
      local session_has_changed = state.session_has_changed:snapshot() > 0 ---@type boolean
      local autosave = state.flight.autosave:snapshot() ---@type boolean

      ---@type t.eve.context.storage
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

  ---! watch the client config file changes.
  if M.storage.client and vim.fn.filereadable(M.storage.client) then
    local unwatch = fs.watch_file({
      filepath = M.storage.client,
      ---@diagnostic disable-next-line: unused-local
      on_event = function(p, event)
        if type(event) == "table" and event.change == true then
          M.load({ client = M.storage.client })
        end
      end,
      on_error = function(p, err)
        reporter.error({
          from = "eve.context",
          subject = "watch_changes",
          message = "Something got wrong while watching the client context file changes!",
          details = { err = err, filepath = p },
        })
      end,
    })
    mvc.add_disposable(Disposable.new({ on_dispose = unwatch }))
  end
end

return M
