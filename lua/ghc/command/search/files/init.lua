local state = require("eve.state")
local context = require("ghc.command.search.files.context")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@return nil
local function open()
  local selected_text = eve.nvim.get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    state.search.flag_regex:next(false)
    state.search.keyword:next(next_search_pattern)
  end

  local search = context.get_search() ---@type fml.t.ux.search.ISearch
  search:focus()
end

eve.commander
  .register({
    uuid = uuids.search_files,
    desc = "search: files",
    action = function()
      state.search.flag_replace:next(false)
      open()
    end,
  })
  .register({
    uuid = uuids.search_files_buffer,
    desc = "search: files (buffer)",
    action = function()
      state.search.flag_replace:next(false)
      state.search.scope:next("B")
      open()
    end,
  })
  .register({
    uuid = uuids.search_files_cwd,
    desc = "search: files (cwd)",
    action = function()
      state.search.flag_replace:next(false)
      state.search.scope:next("C")
      open()
    end,
  })
  .register({
    uuid = uuids.search_files_directory,
    desc = "search: files (directory)",
    action = function()
      state.search.flag_replace:next(false)
      state.search.scope:next("D")
      open()
    end,
  })
  .register({
    uuid = uuids.search_files_workspace,
    desc = "search: files (workspace)",
    action = function()
      state.search.flag_replace:next(false)
      state.search.scope:next("W")
      open()
    end,
  })
  .register({
    uuid = uuids.replace_files,
    desc = "replace: files",
    action = function()
      state.search.flag_replace:next(true)
      open()
    end,
  })
  .register({
    uuid = uuids.replace_files_buffer,
    desc = "replace: files (buffer)",
    action = function()
      state.search.flag_replace:next(true)
      state.search.scope:next("B")
      open()
    end,
  })
  .register({
    uuid = uuids.replace_files_cwd,
    desc = "replace: files (cwd)",
    action = function()
      state.search.flag_replace:next(true)
      state.search.scope:next("C")
      open()
    end,
  })
  .register({
    uuid = uuids.replace_files_directory,
    desc = "replace: files (directory)",
    action = function()
      state.search.flag_replace:next(true)
      state.search.scope:next("D")
      open()
    end,
  })
  .register({
    uuid = uuids.replace_files_workspace,
    desc = "replace: files (workspace)",
    action = function()
      state.search.flag_replace:next(true)
      state.search.scope:next("W")
      open()
    end,
  })
