local __module_name__ = "dot.context" ---@type string

---@class dot.context.__mods
local __mods = {
  behavior = "dot.context.editor.behavior",
  theme = "dot.context.editor.theme",

  --------------------------------------------------------------------------------------------------

  tab = "dot.context.session.tab",

  --------------------------------------------------------------------------------------------------

  bookmark = "dot.context.workspace.bookmark",
  colorpicker = "dot.context.workspace.colorpicker",
  explorer = "dot.context.workspace.explorer",
  flight = "dot.context.workspace.flight",
  frecency = "dot.context.workspace.frecency",
  lsp = "dot.context.workspace.lsp",
  module = "dot.context.workspace.module",
  option = "dot.context.workspace.option",
  plugin = "dot.context.workspace.plugin",
  search_buffer = "dot.context.workspace.search_buffer",
  search_file = "dot.context.workspace.search_file",
  select = "dot.context.workspace.select",
}

---@class dot.context.state.IWatchChangeParams
---@field public on_theme_changed       ?fun(): nil

---@class dot.context.storage
---@field public editor                 ?string
---@field public session                ?string
---@field public workspace              ?string
---@field public nvim_session           ?string
---@field public nvim_session_autosaved ?string

---@class dot.context.data
---@field public behavior               dot.context.behavior.data
---@field public theme                  dot.context.theme.data
---
---@field public tab                    dot.context.tab.data
---
---@field public bookmark               dot.context.bookmark.data
---@field public colorpicker            dot.context.colorpicker.data
---@field public explorer               dot.context.explorer.data
---@field public flight                 dot.context.flight.data
---@field public frecency               dot.context.frecency.data
---@field public lsp                    dot.context.lsp.data
---@field public module                 dot.context.module.data
---@field public option                 dot.context.option.data
---@field public plugin                 dot.context.plugin.data
---@field public search_buffer          dot.context.search_buffer.data
---@field public search_file            dot.context.search_file.data
---@field public select                 dot.context.select.data

---@class dot.context.state
---
---@field public dump                   fun(): dot.context.data
---@field public load                   fun(storage: dot.context.storage): nil
---@field public save                   fun(storage: dot.context.storage): nil
---@field public get_storage            fun(): dot.context.storage
---@field public set_storage            fun(storage: dot.context.storage): nil
---
---@field public observe                fun(observables: stl.c.Observable[], callback: fun(): nil, ignore_initial: boolean|nil): nil
---
---@field public refresh                fun(): nil
---@field public watch_changes          fun(params: dot.context.state.IWatchChangeParams): nil

---@class dot.context : dot.context.state
---@field public behavior               dot.context.behavior
---@field public theme                  dot.context.theme
---
---@field public tab                    dot.context.tab
---
---@field public bookmark               dot.context.bookmark
---@field public colorpicker            dot.context.colorpicker
---@field public explorer               dot.context.explorer
---@field public flight                 dot.context.flight
---@field public frecency               dot.context.frecency
---@field public lsp                    dot.context.lsp
---@field public module                 dot.context.module
---@field public option                 dot.context.option
---@field public plugin                 dot.context.plugin
---@field public search_buffer          dot.context.search_buffer
---@field public search_file            dot.context.search_file
---@field public select                 dot.context.select
---@field protected _storage            dot.context.storage
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

---@return dot.context.data
function M.dump()
  ---@type dot.context.data
  local data = {
    behavior = M.behavior.dump(),
    theme = M.theme.dump(),

    tab = M.tab.dump(),

    bookmark = M.bookmark.dump(),
    colorpicker = M.colorpicker.dump(),
    explorer = M.explorer.dump(),
    flight = M.flight.dump(),
    frecency = M.frecency.dump(),
    lsp = M.lsp.dump(),
    module = M.module.dump(),
    option = M.option.dump(),
    plugin = M.plugin.dump(),
    search_buffer = M.search_buffer.dump(),
    search_file = M.search_file.dump(),
    select = M.select.dump(),
  }
  return data
end

---@param storage                       dot.context.storage
---@param initialize                    boolean
---@return nil
function M.load(storage, initialize)
  if storage.editor or initialize then
    local data_editor = (
      storage.editor
      and vim.fn.filereadable(storage.editor) ~= 0
      and stl.fs.read_json({ filepath = storage.editor, silent_on_bad_path = true })
    ) or {}
    M.behavior.load(data_editor.behavior)
    M.theme.load(data_editor.theme)
  end

  if storage.workspace or initialize then
    local data_workspace = (
      storage.workspace
      and vim.fn.filereadable(storage.workspace) ~= 0
      and stl.fs.read_json({ filepath = storage.workspace, silent_on_bad_path = true })
    ) or {}
    M.bookmark.load(data_workspace.bookmark)
    M.colorpicker.load(data_workspace.colorpicker)
    M.explorer.load(data_workspace.explorer)
    M.flight.load(data_workspace.flight)
    M.frecency.load(data_workspace.frecency)
    M.lsp.load(data_workspace.lsp)
    M.module.load(data_workspace.module)
    M.option.load(data_workspace.option)
    M.plugin.load(data_workspace.plugin)
    M.search_buffer.load(data_workspace.search_buffer)
    M.search_file.load(data_workspace.search_file)
    M.select.load(data_workspace.select)
  end

  if storage.session or initialize then
    local data_session = (
      storage.session
      and vim.fn.filereadable(storage.session) ~= 0
      and stl.fs.read_json({ filepath = storage.session, silent_on_bad_path = true })
    ) or {}
    dot.state.status.reset()
    M.tab.load(data_session.tab)
  end
end

---@param storage                       dot.context.storage
---@return nil
function M.save(storage)
  if storage.editor then
    local data = {
      behavior = M.behavior.dump(),
      theme = M.theme.dump(),
    }
    stl.fs.write_json(storage.editor, data, true)
  end

  if storage.session then
    local data = {
      tab = M.tab.dump(),
    }
    stl.fs.write_json(storage.session, data, true)
  end

  if storage.workspace then
    if package.loaded["dap"] then
      M.lsp.refresh_breakpoints()
    end

    local data = {
      bookmark = M.bookmark.dump(),
      colorpicker = M.colorpicker.dump(),
      explorer = M.explorer.dump(),
      flight = M.flight.dump(),
      frecency = M.frecency.dump(),
      lsp = M.lsp.dump(),
      module = M.module.dump(),
      option = M.option.dump(),
      plugin = M.plugin.dump(),
      search_buffer = M.search_buffer.dump(),
      search_file = M.search_file.dump(),
      select = M.select.dump(),
    }
    stl.fs.write_json(storage.workspace, data, true)
  end
end

---@return dot.context.storage
function M.get_storage()
  return M._storage
end

---@param storage                       dot.context.storage
---@return nil
function M.set_storage(storage)
  M._storage = storage
end

---@return nil
function M.watch_changes()
  local ticker_editor = stl.c.Ticker.new({ start = 0 })
  local ticker_workspace = stl.c.Ticker.new({ start = 0 })

  stl.fn.observe({ M.theme.theme }, function()
    dot.context.theme.reload_theme(false, true)
  end, true)
  stl.fn.observe({ M.theme.transparency }, function()
    dot.context.theme.reload_theme(true, true)
  end, true)

  stl.fn.observe({
    M.option.expandtab,
  }, function()
    local flag = M.option.expandtab:snapshot() ---@type boolean
    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    vim.o.expandtab = flag
    for _, bufnr in ipairs(bufnrs) do
      if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
        vim.bo[bufnr].expandtab = flag
      end
    end
  end, true)

  stl.fn.observe({
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

  stl.fn.observe({
    M.behavior.auto_im,
    M.behavior.bufs_relative,
    M.theme.theme,
    M.theme.transparency,
    M.theme.username,
  }, function()
    ticker_editor:tick()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
    vim.schedule(function()
      vim.cmd("redraw!")
    end)
  end, true)

  stl.fn.observe({
    M.plugin.render_markdown,
    M.plugin.treesitter_context,
    M.option.relativenumber,
  }, function()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
    vim.schedule(function()
      vim.cmd("redraw!")
    end)
  end, true)

  ---@type stl.c.Observable[]
  local select_states = {
    M.bookmark.pinned,
    M.flight.ai,
    M.flight.autoformat,
    M.flight.autoload,
    M.flight.autosave,
    M.flight.devmode,
    M.flight.dressing_clipboard,
    M.flight.dressing_illuminate,
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
  stl.fn.observe(select_states, function()
    ticker_workspace:tick()
    dot.state.status.dirtier_statusline:mark_dirty()
    dot.state.status.dirtier_tabline:mark_dirty()
  end, true)

  stl.fn.observe({
    M.lsp.code_lens,
    M.lsp.diagnostics_virt_lines,
    M.lsp.inlay_hints,
  }, function()
    pcall(function()
      dot.command.definitions.lsp.restart:execute()
    end)
  end, true)

  stl.fn.observe({
    dot.state.status.msg_lsp,
    dot.state.status.msg_mode,
  }, function()
    dot.state.status.dirtier_statusline:mark_dirty()
  end)

  local scheduler = stl.c.Scheduler.new({
    name = __module_name__,
    mode = "throttle",
    delay = 256,
    timeout = 3000,
    silent = stl.fn.falsy,
    value = stl.c.Observable.from_value(true),
    task = function()
      if M._storage.editor then
        local raw_data = stl.fs.read_json({ filepath = M._storage.editor, silent_on_bad_path = true }) or {}
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
    stl.c.Subscriber.new({
      on_next = function()
        scheduler:schedule()
      end,
    }),
    true
  )

  ---! Save when leave the editor.
  dot.state.status.add_disposable(stl.c.Disposable.new({
    on_dispose = function()
      local autosave = M.flight.autosave:snapshot() ---@type boolean

      ---@type dot.context.storage
      local storage = {
        session = autosave and M._storage.session or nil,
        workspace = M._storage.workspace,
      }

      if autosave and M._storage.nvim_session_autosaved then
        dot.session.save_session(M._storage.nvim_session_autosaved)
      end

      M.save(storage)
    end,
  }))

  ---! watch the editor states file changes.
  if M._storage.editor and vim.fn.filereadable(M._storage.editor) then
    local unwatch = stl.fs.watch_file({
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
        stl.reporter.error({
          from = __module_name__,
          subject = "watch_changes",
          message = "Something got wrong while watching the editor states file changes!",
          details = { err = err, filepath = p },
        })
      end,
    })
    dot.state.status.add_disposable(stl.c.Disposable.new({ on_dispose = unwatch }))
  end
end

return M
