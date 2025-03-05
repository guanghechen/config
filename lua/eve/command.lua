local __module_name__ = "eve.command" ---@type string

local fn = require("eve.builtin.fn")
local reporter = require("eve.builtin.reporter")
local setting = require("eve.constant.setting")

---@alias eve.command.definitions.copy.Scope
---| "absolute"
---| "relative"

---@class eve.command.IContext
---@field public tabnr                  integer
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public tabtype                eve.e.state.tab.meta.TabType
---@field public selected_text          string|nil

---@class eve.command.IDefinition
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  0|1|"?"
---@field public candidates             ?string[]

---@class eve.command.IDefinitionWithCandidates
---@field public uuid                   string
---@field public desc                   string
---@field public nargs                  1|"?"
---@field public candidates             string[]

---@class eve.command.ICommand
---@field public uuid                   string
---@field public tabtype                eve.e.state.tab.meta.TabType
---@field public action                 fun(context: eve.command.IContext, args?: string): nil

---@class eve.command.IImplementation
---@field public uuid                   string
---@field public tabtype                ?eve.e.state.tab.meta.TabType
---@field public action                 fun(context: eve.command.IContext, args?: string): nil

local definition_map = {} ---@type table<string, eve.command.IDefinition>
local command_map = {} ---@type table<string, eve.command.ICommand>

---@class eve.command
---@field protected __context__         eve.command.IContext|nil
---@field protected __definition_map__  table<string, eve.command.IDefinition>
---@field protected __command_map__     table<string, eve.command.ICommand>
local M = {
  __context__ = nil,
  __definition_map__ = definition_map,
  __command_map__ = command_map,
}

---@param raw_definition                eve.command.IDefinition | eve.command.IDefinitionWithCandidates
---@param overwrite                     boolean|nil
---@return eve.command
function M.define(raw_definition, overwrite)
  if definition_map[raw_definition.uuid] ~= nil and not overwrite then
    reporter.warn({
      from = __module_name__,
      subject = "define",
      message = "The definition with the uuid has already existed.",
      details = { definition = raw_definition },
    })
    return M
  end

  ---@type eve.command.IDefinition
  local definition = {
    uuid = raw_definition.uuid,
    desc = raw_definition.desc,
    nargs = raw_definition.nargs,
    candidates = raw_definition.candidates,
  }
  definition_map[definition.uuid] = definition

  ---@param opts                        { name: string, args: string, fargs: string[] }
  ---@return nil
  local function handle(opts)
    local context ---@type eve.command.IContext
    local winnr = vim.api.nvim_get_current_win() ---@type integer

    local last_context = M.__context__ ---@type eve.command.IContext|nil
    if last_context ~= nil and fn.is_win_floating(winnr) then
      context = last_context
    else
      local state = require("eve.state")

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local tabtype = state.tab.resolve_tabtype(tabnr) ---@type eve.e.state.tab.meta.TabType

      ---@type eve.command.IContext
      context = {
        tabnr = tabnr,
        winnr = winnr,
        bufnr = bufnr,
        tabtype = tabtype,
        selected_text = nil,
      }
    end

    M.execute(definition.uuid, context, opts.args, false)
  end

  ---@param argLead                     string
  ---@return string[]
  local function complete(argLead)
    if definition.candidates ~= nil then
      local options = definition.candidates ---@type string[]
      local pattern = "^" .. argLead ---@type string
      local matches = {} ---@type string[]
      for _, option in ipairs(options) do
        if option:match(pattern) then
          matches[#matches + 1] = option
        end
      end
      return matches
    end
    return {}
  end

  vim.api.nvim_create_user_command(definition.uuid, handle, {
    desc = definition.desc,
    nargs = definition.nargs,
    complete = definition.nargs ~= 0 and complete or nil,
  })
  return M
end

---@param implementation                 eve.command.IImplementation
---@return eve.command
function M.implement(implementation)
  local uuid = implementation.uuid ---@type string
  local tabtype = implementation.tabtype or setting.tabtypes.ALL ---@type string
  local action = implementation.action ---@type fun(args?: string): nil
  local definition = definition_map[uuid] ---@type eve.command.IDefinition|nil
  if definition == nil then
    reporter.warn({
      from = __module_name__,
      subject = "implement",
      message = "Cannot find the definition by the given uuid.",
      details = { uuid = uuid, tabtype = tabtype, action = action },
    })
    return M
  end

  local key = tabtype == setting.tabtypes.ALL and uuid or (uuid .. ":" .. tabtype) ---@type string
  if command_map[key] ~= nil then
    reporter.error({
      from = __module_name__,
      subject = "implement",
      message = "The command has already been implemented.",
      details = { key = key, uuid = uuid, tabtype = tabtype, action = action },
    })
    return M
  end

  ---@type eve.command.ICommand
  local command = {
    uuid = uuid,
    tabtype = tabtype,
    action = action,
  }
  command_map[key] = command
  return M
end

---@param uuid                          string
---@param context                       eve.command.IContext
---@param args                          ?string
---@param silent                        ?boolean
---@return nil
function M.execute(uuid, context, args, silent)
  M.__context__ = context

  local tabtype = context.tabtype ---@type eve.e.state.tab.meta.TabType
  local key = uuid .. ":" .. tabtype ---@type string
  local command = command_map[key] or command_map[uuid] ---@type eve.command.ICommand|nil

  if command == nil then
    if not silent then
      reporter.warn({
        from = __module_name__,
        subject = "execute",
        message = "Cannot resolve the command by the given uuid",
        details = { uuid = uuid, args = args },
      })
    end
    return
  end

  command.action(context, args)
end

---@return eve.command.IContext|nil
function M.context_snapshot()
  return M.__context__
end

---@return integer|nil
function M.context_winnr()
  local winnr = M.__context__ and M.__context__.winnr or nil ---@type integer|nil
  return winnr ~= nil and winnr > 0 and vim.api.nvim_win_is_valid(winnr) and winnr or nil
end

---@return integer|nil
function M.context_bufnr()
  local bufnr = M.__context__ and M.__context__.bufnr or nil ---@type integer|nil
  return bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) and bufnr or nil
end

---@param uuid                          string
---@param desc                          string
---@param nargs                         ?0|1|"?"
---@param candidates                    ?string[]
---@return eve.command.IDefinition
local function def(uuid, desc, nargs, candidates)
  ---@type eve.command.IDefinition
  local definition = {
    uuid = uuid,
    desc = desc,
    nargs = nargs or 0,
    candidates = candidates,
  }
  M.define(definition)
  return definition
end

---@param uuid                          string
---@param desc                          string
---@param nargs                         1|"?"
---@param candidates                    string[]
---@return eve.command.IDefinitionWithCandidates
local function defc(uuid, desc, nargs, candidates)
  ---@type eve.command.IDefinitionWithCandidates
  local definition = {
    uuid = uuid,
    desc = desc,
    nargs = nargs,
    candidates = vim.list_slice(candidates),
  }
  M.define(definition)
  return definition
end

---@class eve.command.definitions
M.definitions = {}

---@class eve.command.definitions.ai
M.definitions.ai = {
  avante_ask = def("Faiavanteask", "ai: avante ask"),
  avante_edit = def("Faiavanteedit", "ai: avante edit"),
  avante_refresh = def("Faiavanterefresh", "ai: avante refresh"),

  copilot_chat_prompt = def("Faicopilotchatprompt", "ai: copilot chat prompt"),
  copilot_chat_quick = def("Faicopilotchatquick", "ai: copilot chat quick"),
  copilot_chat_reset = def("Faicopilotchatreset", "ai: copilot chat reset"),
  copilot_chat_stop = def("Faicopilotchatstop", "ai: copilot chat stop"),
  copilot_chat_toggle = def("Faicopilotchattoggle", "ai: copilot chat toggle"),
}

---@class eve.command.definitions.buf
M.definitions.buf = {
  close = def("Fbufclose", "buf: close"),
  close_to_leftest = def("Fbufclosetoleftest", "buf: close to leftest"),
  close_to_rightest = def("Fbufclosetorightest", "buf: close to rightest"),
  close_others = def("Fbufcloseothers", "buf: close others"),

  focus_01 = def("Fbuffocus01", "buf: focus 1"),
  focus_02 = def("Fbuffocus02", "buf: focus 2"),
  focus_03 = def("Fbuffocus03", "buf: focus 3"),
  focus_04 = def("Fbuffocus04", "buf: focus 4"),
  focus_05 = def("Fbuffocus05", "buf: focus 5"),
  focus_06 = def("Fbuffocus06", "buf: focus 6"),
  focus_07 = def("Fbuffocus07", "buf: focus 7"),
  focus_08 = def("Fbuffocus08", "buf: focus 8"),
  focus_09 = def("Fbuffocus09", "buf: focus 9"),
  focus_10 = def("Fbuffocus10", "buf: focus 10"),
  focus_11 = def("Fbuffocus11", "buf: focus 11"),
  focus_12 = def("Fbuffocus12", "buf: focus 12"),
  focus_13 = def("Fbuffocus13", "buf: focus 13"),
  focus_14 = def("Fbuffocus14", "buf: focus 14"),
  focus_15 = def("Fbuffocus15", "buf: focus 15"),
  focus_16 = def("Fbuffocus16", "buf: focus 16"),
  focus_17 = def("Fbuffocus17", "buf: focus 17"),
  focus_18 = def("Fbuffocus18", "buf: focus 18"),
  focus_19 = def("Fbuffocus19", "buf: focus 19"),
  focus_20 = def("Fbuffocus20", "buf: focus 20"),
  focus_21 = def("Fbuffocus21", "buf: focus 21"),
  focus_22 = def("Fbuffocus22", "buf: focus 22"),
  focus_23 = def("Fbuffocus23", "buf: focus 23"),
  focus_24 = def("Fbuffocus24", "buf: focus 24"),
  focus_25 = def("Fbuffocus25", "buf: focus 25"),
  focus_26 = def("Fbuffocus26", "buf: focus 26"),
  focus_27 = def("Fbuffocus27", "buf: focus 27"),
  focus_28 = def("Fbuffocus28", "buf: focus 28"),
  focus_29 = def("Fbuffocus29", "buf: focus 29"),
  focus_30 = def("Fbuffocus30", "buf: focus 30"),
  focus_31 = def("Fbuffocus31", "buf: focus 31"),
  focus_32 = def("Fbuffocus32", "buf: focus 32"),
  focus_33 = def("Fbuffocus33", "buf: focus 33"),
  focus_34 = def("Fbuffocus34", "buf: focus 34"),
  focus_35 = def("Fbuffocus35", "buf: focus 35"),
  focus_36 = def("Fbuffocus36", "buf: focus 36"),
  focus_37 = def("Fbuffocus37", "buf: focus 37"),
  focus_38 = def("Fbuffocus38", "buf: focus 38"),
  focus_39 = def("Fbuffocus39", "buf: focus 39"),
  focus_40 = def("Fbuffocus40", "buf: focus 40"),
  focus_41 = def("Fbuffocus41", "buf: focus 41"),
  focus_42 = def("Fbuffocus42", "buf: focus 42"),
  focus_43 = def("Fbuffocus43", "buf: focus 43"),
  focus_44 = def("Fbuffocus44", "buf: focus 44"),
  focus_45 = def("Fbuffocus45", "buf: focus 45"),
  focus_46 = def("Fbuffocus46", "buf: focus 46"),
  focus_47 = def("Fbuffocus47", "buf: focus 47"),
  focus_48 = def("Fbuffocus48", "buf: focus 48"),
  focus_49 = def("Fbuffocus49", "buf: focus 49"),

  open = def("Fopen", "buf: open (bufnr)", 1),
  focus = def("Fbuffocus", "buf: focus (bufid)", 1),
  focus_left = def("Fbuffocusleft", "buf: focus left", "?"),
  focus_right = def("Fbuffocusright", "buf: focus right", "?"),

  swap_left = def("Fbufswapleft", "buf: swap left"),
  swap_right = def("Fbufswapright", "buf: swap right"),

  new = def("Fbufnew", "buf: new"),
  pin = def("Fbufpin", "buf: pin"),
  save = def("Fbufsave", "buf: save"),
}

---@class eve.command.definitions.clipboard
M.definitions.clipboard = {
  paste = def("Fclipboardpaste", "clipboard: paste"),
}

---@class eve.command.definitions.code
M.definitions.code = {
  run = def("Fcoderun", "code: run"),
  run_force = def("Fcoderunforce", "code: run (force)"),

  swap_conditional_branches = def("Fcodeswapconditionalbranches", "code: swap conditional branches"),
}

---@class eve.command.definitions.copy
M.definitions.copy = {
  char_under_cursor = def("Fcopycharundercursor", "copy: char under cursor"),

  filepath = defc("Fcopyfilepath", "copy: current filepath", "?", { "absolute", "relative" }),
  filepath_absolute = def("Fcopyfilepathabsolute", "copy: current filepath (absolute)"),
  filepath_relative = def("Fcopyfilepathrelative", "copy: current filepath (relative)"),
}

---@class eve.command.definitions.debug
M.definitions.debug = {
  inspect_pos = def("Fdebuginspectpos", "debug: inspect pos"),
  inspect_state = def("Fdebuginspectstate", "debug: inspect state"),
  inspect_tree = def("Fdebuginspecttree", "debug: inspect tree"),
  inspect_window = def("Fdebuginspectwindow", "debug: inspect window"),
}

---@class eve.command.definitions.diagnostic
M.definitions.diagnostic = {
  goto_next = def("Fdiagnosticgotonext", "diagnostic: goto next"),
  goto_next_error = def("Fdiagnosticgotonexterror", "diagnostic: goto next (error)"),
  goto_next_warn = def("Fdiagnosticgotonextwarn", "diagnostic: goto next (warn)"),
  goto_next_hint = def("Fdiagnosticgotonexthint", "diagnostic: goto next (hint)"),
  goto_next_info = def("Fdiagnosticgotonextinfo", "diagnostic: goto next (info)"),
  goto_next_quickfix = def("Fdiagnosticgotonextquickfix", "diagnostic: goto next (quickfix)"),

  goto_prev = def("Fdiagnosticgotoprev", "diagnostic: goto prev"),
  goto_prev_error = def("Fdiagnosticgotopreverror", "diagnostic: goto prev (error)"),
  goto_prev_warn = def("Fdiagnosticgotoprevwarn", "diagnostic: goto prev (warn)"),
  goto_prev_hint = def("Fdiagnosticgotoprevhint", "diagnostic: goto prev (hint)"),
  goto_prev_info = def("Fdiagnosticgotoprevinfo", "diagnostic: goto prev (info)"),
  goto_prev_quickfix = def("Fdiagnosticgotoprevquickfix", "diagnostic: goto prev (quickfix)"),

  line = def("Fdiagnosticline", "diagnostic: line"),
  outline = def("Fdiagnosticoutline", "diagnostic: outline"),
}

---@class eve.command.definitions.explorer
M.definitions.explorer = {
  fs_cwd = def("Fexplorerfscwd", "explorer: filesystem (cwd)"),
  fs_workspace = def("Fexplorerfsworkspace", "explorer: filesystem (workspace)"),
  fs_reveal = def("Fexplorerfsreveal", "explorer: filesystem (reveal)"),

  git_cwd = def("Fexplorergitcwd", "explorer: git (cwd)"),
  git_workspace = def("Fexplorergitworkspace", "explorer: git (workspace)"),

  last = def("Fexplorerlast", "explorer: last"),
  toggle = def("Fexplorertoggle", "explorer: toggle"),
}

---@class eve.command.definitions.find
M.definitions.find = {
  bufs = def("Ffindbufs", "find: buffers"),
  bufs_file = def("Ffindbufsfile", "find: buffers (file)"),
  bufs_term = def("Ffindbufsterm", "find: buffers (term)"),

  explorer = def("Ffindexplorer", "find: explorer"),
  files = def("Ffindfiles", "find: files"),
  files_cwd = def("Ffindfilescwd", "find: files (cwd)"),
  files_directory = def("Ffindfilesdirectory", "find: files (directory)"),
  files_workspace = def("Ffindfilesworkspace", "find: files (workspace)"),
  git_not_committed = def("Ffindgitnotcommitted", "find: git not committed"),
  highlights = def("Ffindhighlights", "find: highlights"),
  pinned_files = def("Ffindpinnedfiles", "find: pinned files"),
  vim_options = def("Ffindvimoptions", "find: vim options"),
}

---@class eve.command.definitions.git
M.definitions.git = {
  browse = def("Fgitbrowse", "git: browse"),
  diffview = def("Fgitdiffview", "git: diffview"),
  history = def("Fgithistory", "git: history (commits)"),
  history_file = def("Fgithistoryfile", "git: history (file)"),
}

---@class eve.command.definitions.lsp
M.definitions.lsp = {
  goto_definitions = def("Flspgotodefinitions", "lsp: goto definitions"),
  goto_implementations = def("Flspgotoimplementations", "lsp: goto implementations"),
  goto_references = def("Flspgotoreferences", "lsp: goto references"),
  goto_type_definitions = def("Flspgototypedefinitions", "lsp: goto type definitions"),

  select_python_venv = def("Flspselectpythonvenv", "lsp: select python venv"),
}

---@class eve.command.definitions.refresh
M.definitions.refresh = {
  all = def("Frefreshall", "refresh: all"),
}

---@class eve.command.definitions.replace
M.definitions.replace = {
  files = def("Freplacefiles", "replace: files"),
  files_in_buffer = def("Freplacefilesinbuffer", "replace: files (buffer)"),
  files_in_cwd = def("Freplacefilesincwd", "replace: files (cwd)"),
  files_in_directory = def("Freplacefilesindirectory", "replace: files (directory)"),
  files_in_workspace = def("Freplacefilesinworkspace", "replace: files (workspace)"),
}

---@class eve.command.definitions.search
M.definitions.search = {
  files = def("Fsearchfiles", "search: files"),
  files_in_buffer = def("Fsearchfilesinbuffer", "search: files (buffer)"),
  files_in_cwd = def("Fsearchfilesincwd", "search: files (cwd)"),
  files_in_directory = def("Fsearchfilesindirectory", "search: files (directory)"),
  files_in_workspace = def("Fsearchfilesinworkspace", "search: files (workspace)"),
}

---@class eve.command.definitions.session
M.definitions.session = {
  restore = def("Fsessionrestore", "session: restore"),
  restore_autosaved = def("Fsessionrestoreautosaved", "session: restore autosaved"),

  save = def("Fsessionsave", "session: save"),
}

---@class eve.command.definitions.tab
M.definitions.tab = {
  close = def("Ftabclose", "tab: close"),
  close_others = def("Ftabcloseothers", "tab: close others"),
  close_to_leftest = def("Ftabclosetoleftest", "tab: close to leftest"),
  close_to_rightest = def("Ftabclosetorightest", "tab: close to rightest"),

  focus_1 = def("Ftabfocus1", "tab: focus 1"),
  focus_2 = def("Ftabfocus2", "tab: focus 2"),
  focus_3 = def("Ftabfocus3", "tab: focus 3"),
  focus_4 = def("Ftabfocus4", "tab: focus 4"),
  focus_5 = def("Ftabfocus5", "tab: focus 5"),
  focus_6 = def("Ftabfocus6", "tab: focus 6"),
  focus_7 = def("Ftabfocus7", "tab: focus 7"),
  focus_8 = def("Ftabfocus8", "tab: focus 8"),
  focus_9 = def("Ftabfocus9", "tab: focus 9"),
  focus_10 = def("Ftabfocus10", "tab: focus 10"),
  focus = def("Ftabfocus", "tab: focus", 1),
  focus_left = def("Ftabfocusleft", "tab: focus left", "?"),
  focus_right = def("Ftabfocusright", "tab: focus right", "?"),

  new = def("Ftabnew", "tab: new"),
  new_with_buf = def("Ftabnewwithbuf", "tab: new with buf"),
}

---@class eve.command.definitions.term
M.definitions.term = {
  toggle_cwd = def("Ftermcwd", "term: toggle (cwd)"),
  toggle_directory = def("Ftermdirectory", "term: toggle (directory)"),
  toggle_workspace = def("Ftermworkspace", "term: toggle (workspace)"),

  lazygit_cwd = def("Ftermlazygitcwd", "term: lazygit (cwd)"),
  lazygit_workspace = def("Ftermlazygitworkspace", "term: lazygit (workspace)"),
  lazygit_file_history = def("Ftermlazygitfilehistory", "term: lazygit (file history)"),

  yazi_cwd = def("Ftermyazicwd", "term: yazi (cwd)"),
  yazi_reveal = def("Ftermyazireveal", "term: yazi (reveal)"),
  yazi_workspace = def("Ftermyaziworkspace", "term: yazi (workspace)"),
}

---@class eve.command.definitions.toggle
M.definitions.toggle = {
  list = defc("Ftoggle", "toggle: select", "?", setting.togglers),
  ai_provider = defc("Ftoggleaiprovider", "toggle: ai provider", "?", setting.ai_providers),
  flight = defc("Ftoggleflight", "toggle: flight", "?", setting.flights),
  markdown = def("Ftogglemarkdown", "toggle: markdown"),
  maximize = def("Ftogglemaximize", "toggle: maximize"),
  relativenumber = def("Ftogglerelativenumber", "toggle: relativenumber"),
  theme = defc("Ftoggletheme", "toggle: theme", "?", setting.themes),
  theme_variant = def("Ftogglethemevariant", "toggle: theme variant"),
  transparency = def("Ftoggletransparency", "toggle: transparency"),
  username = def("Ftoggleusername", "toggle: username"),
}

---@class eve.command.definitions.ux
M.definitions.ux = {
  dismiss_notifications = def("Fuxdismissnotifications", "ux: dismiss notifications"),
  reload_theme = def("Fuxreloadtheme", "ux: reload theme", "?"),
  resume_last_widget = def("Fuxresume", "ux: resume last widget"),
}

---@class eve.command.definitions.win
M.definitions.win = {
  close = def("Fwinclose", "win: close"),
  close_others = def("Fwincloseothers", "win: close others"),

  focus_top = def("Fwinfocustop", "win: focus top"),
  focus_right = def("Fwinfocusright", "win: focus right"),
  focus_bottom = def("Fwinfocusbottom", "win: focus bottom"),
  focus_left = def("Fwinfocusleft", "win: focus left"),
  focus_prev = def("Fwinfocusprev", "win: focus prev"),
  focus_next = def("Fwinfocusnext", "win: focus next"),

  history = def("Fwinhistory", "win: history"),
  history_backward = def("Fwinhistorybackward", "win: history backward"),
  history_forward = def("Fwinhistoryforward", "win: history forward"),

  resize_horizontal_minus = def("Fwinresizehorizontalminus", "win: resize horizontal (minus)"),
  resize_horizontal_plus = def("Fwinresizehorizontalplus", "win: resize horizontal (plus)"),
  resize_vertical_minus = def("Fwinresizeverticalminus", "win: resize vertical (minus)"),
  resize_vertical_plus = def("Fwinresizeverticalplus", "win: resize vertical (plus)"),

  split_above = def("Fwinsplitabove", "win: split above"),
  split_right = def("Fwinsplitright", "win: split right"),
  split_below = def("Fwinsplitbelow", "win: split below"),
  split_left = def("Fwinsplitleft", "win: split left"),

  focus = def("Fwinfocus", "win: focus (with picker)"),
  project = def("Fwinproject", "win: project (with picker)"),
  swap = def("Fwinswap", "win: swap (with picker)"),

  scroll_down = def("Fwinscrolldown", "win: scroll down"),
  scroll_up = def("Fwinscrollup", "win: scroll up"),
}

return M
