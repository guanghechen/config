---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.command" ---@type string

---@alias dot.command.definitions.copy.Scope
---| "absolute"
---| "relative"
---| "filename"

---@class dot.command.ICommand
---@field public uuid                   string
---@field public tabtype                stl.nvim.tab.TypeEnum|nil
---@field public action                 fun(args?: string): nil

---@class dot.command.IImplementation
---@field public uuid                   string
---@field public tabtype                ?stl.nvim.tab.TypeEnum
---@field public action                 fun(args?: string): nil

local definition_map = {} ---@type table<string, dot.command.IRawDefinition>
local command_map = {} ---@type table<string, dot.command.ICommand>

---@class dot.command
---@field protected __definition_map__  table<string, dot.command.IRawDefinition>
---@field protected __command_map__     table<string, dot.command.ICommand>
local M = {
  __definition_map__ = definition_map,
  __command_map__ = command_map,
}

---@param uuid                          string
---@param args                          ?string
---@param silent                        ?boolean
---@return nil
function M.execute(uuid, args, silent)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = dot.tab.resolve_type(tabnr, false) ---@type stl.nvim.tab.TypeEnum
  local key = uuid .. ":" .. tabtype ---@type string
  local command = command_map[key] or command_map[uuid] ---@type dot.command.ICommand|nil

  if command == nil then
    if not silent then
      stl.reporter.warn({
        from = __module_name__,
        subject = "execute",
        message = "Cannot resolve the command by the given uuid",
        details = { uuid = uuid, args = args },
      })
    end
    return
  end

  command.action(args)
end

---@param raw_definition                dot.command.IRawDefinition
---@param overwrite                     boolean|nil
---@return dot.command
function M.define(raw_definition, overwrite)
  if definition_map[raw_definition.uuid] ~= nil and not overwrite then
    stl.reporter.warn({
      from = __module_name__,
      subject = "define",
      message = "The definition with the uuid has already existed.",
      details = { definition = raw_definition },
    })
    return M
  end

  ---@type dot.command.IRawDefinition
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
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    dot.state.status.set_winnr_command(winnr)
    M.execute(definition.uuid, opts.args, false)
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

---@param implementation                dot.command.IImplementation
---@return dot.command
function M.implement(implementation)
  local uuid = implementation.uuid ---@type string
  local tabtype = implementation.tabtype ---@type stl.nvim.tab.TypeEnum|nil
  local action = implementation.action ---@type fun(args?: string): nil
  local definition = definition_map[uuid] ---@type dot.command.IRawDefinition|nil
  if definition == nil then
    stl.reporter.warn({
      from = __module_name__,
      subject = "implement",
      message = "Cannot find the definition by the given uuid.",
      details = { uuid = uuid, tabtype = tabtype, action = action },
    })
    return M
  end

  local key = tabtype == nil and uuid or (uuid .. ":" .. tabtype) ---@type string
  if command_map[key] ~= nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "implement",
      message = "The command has already been implemented.",
      details = { key = key, uuid = uuid, tabtype = tabtype, action = action },
    })
    return M
  end

  ---@type dot.command.ICommand
  local command = {
    uuid = uuid,
    tabtype = tabtype,
    action = action,
  }
  command_map[key] = command
  return M
end

---@param modes                         string[]
---@param keys                          string|string[]
---@param definition                    dot.command.IDefinition|dot.command.IDefinitionWithCandidates
---@return nil
function M.shortcut(modes, keys, definition)
  ---@return nil
  local function callback()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    dot.state.status.set_winnr_command(winnr)
    M.execute(definition.uuid)
  end

  ---@type vim.keymap.set.Opts
  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
    desc = definition.desc,
  }

  if type(keys) == "string" then
    vim.keymap.set(modes, keys, callback, opts)
  else
    for _, key in ipairs(keys) do
      vim.keymap.set(modes, key, callback, opts)
    end
  end
end

---@class dot.command.Definition : dot.command.IDefinition
local D = {}
D.__index = D

---@param uuid                          string
---@param desc                          string
---@param nargs                         ?0|1|"?"
---@param candidates                    ?string[]
---@return dot.command.IDefinition
function D.new(uuid, desc, nargs, candidates)
  local definition = setmetatable({
    uuid = uuid,
    desc = desc,
    nargs = nargs or 0,
    candidates = candidates and vim.list_slice(candidates) or nil,
  }, D)
  M.define(definition)
  return definition
end

---@param args                          ?string
---@param silent                        ?boolean
---@return nil
function D:execute(args, silent)
  M.execute(self.uuid, args, silent or false)
end

---@class dot.command.definitions
M.definitions = {}

---@class dot.command.definitions.acp
M.definitions.acp = {
  cancel = D.new("Facpcancel", "acp: cancel"),
  clear = D.new("Facpclear", "acp: clear session"),
  close = D.new("Facpclose", "acp: close"),
  focus = D.new("Facpfocus", "acp: focus"),
  new = D.new("Facpnew", "acp: new session"),
  open = D.new("Facpopen", "acp: open", "?", { "claude", "gemini", "openai", "codex", "opencode" }),
  select_provider = D.new("Facpselectprovider", "acp: select provider"),
  submit = D.new("Facpsubmit", "acp: submit", "?"),
  toggle = D.new("Facptoggle", "acp: toggle", "?", { "claude", "gemini", "openai", "codex", "opencode" }),
}

---@class dot.command.definitions.ai
M.definitions.ai = {
  attach_agent = D.new("Faiattachagent", "ai: attach agent"),
  detach_agent = D.new("Faidetachagent", "ai: detach agent"),
  edit = D.new("Faiedit", "ai: edit"),
  select_prompt = D.new("Faiselectprompt", "ai: select prompt"),
  send_buffer = D.new("Faisendbuffer", "ai: send buffer"),
  send_file = D.new("Faisendfile", "ai: send file"),
  send_selection = D.new("Faisendselection", "ai: send selection"),
  submit_buffer = D.new("Faisubmitbuffer", "ai: submit buffer"),
  submit_selection = D.new("Faisubmitselection", "ai: submit selection"),
  submit_to = D.new("Faisubmitto", "ai: submit to"),
}

---@class dot.command.definitions.buf
M.definitions.buf = {
  close = D.new("Fbufclose", "buf: close"),
  close_to_leftest = D.new("Fbufclosetoleftest", "buf: close to leftest"),
  close_to_rightest = D.new("Fbufclosetorightest", "buf: close to rightest"),
  close_others = D.new("Fbufcloseothers", "buf: close others"),

  focus_left_1 = D.new("Fbuffocusleft1", "buf: focus left 1"),
  focus_left_2 = D.new("Fbuffocusleft2", "buf: focus left 2"),
  focus_left_3 = D.new("Fbuffocusleft3", "buf: focus left 3"),
  focus_left_4 = D.new("Fbuffocusleft4", "buf: focus left 4"),
  focus_left_5 = D.new("Fbuffocusleft5", "buf: focus left 5"),
  focus_left_6 = D.new("Fbuffocusleft6", "buf: focus left 6"),
  focus_left_7 = D.new("Fbuffocusleft7", "buf: focus left 7"),
  focus_left_8 = D.new("Fbuffocusleft8", "buf: focus left 8"),
  focus_left_9 = D.new("Fbuffocusleft9", "buf: focus left 9"),
  focus_right_1 = D.new("Fbuffocusright1", "buf: focus right 1"),
  focus_right_2 = D.new("Fbuffocusright2", "buf: focus right 2"),
  focus_right_3 = D.new("Fbuffocusright3", "buf: focus right 3"),
  focus_right_4 = D.new("Fbuffocusright4", "buf: focus right 4"),
  focus_right_5 = D.new("Fbuffocusright5", "buf: focus right 5"),
  focus_right_6 = D.new("Fbuffocusright6", "buf: focus right 6"),
  focus_right_7 = D.new("Fbuffocusright7", "buf: focus right 7"),
  focus_right_8 = D.new("Fbuffocusright8", "buf: focus right 8"),
  focus_right_9 = D.new("Fbuffocusright9", "buf: focus right 9"),
  focus_01 = D.new("Fbuffocus01", "buf: focus 1"),
  focus_02 = D.new("Fbuffocus02", "buf: focus 2"),
  focus_03 = D.new("Fbuffocus03", "buf: focus 3"),
  focus_04 = D.new("Fbuffocus04", "buf: focus 4"),
  focus_05 = D.new("Fbuffocus05", "buf: focus 5"),
  focus_06 = D.new("Fbuffocus06", "buf: focus 6"),
  focus_07 = D.new("Fbuffocus07", "buf: focus 7"),
  focus_08 = D.new("Fbuffocus08", "buf: focus 8"),
  focus_09 = D.new("Fbuffocus09", "buf: focus 9"),
  focus_10 = D.new("Fbuffocus10", "buf: focus 10"),
  focus_11 = D.new("Fbuffocus11", "buf: focus 11"),
  focus_12 = D.new("Fbuffocus12", "buf: focus 12"),
  focus_13 = D.new("Fbuffocus13", "buf: focus 13"),
  focus_14 = D.new("Fbuffocus14", "buf: focus 14"),
  focus_15 = D.new("Fbuffocus15", "buf: focus 15"),
  focus_16 = D.new("Fbuffocus16", "buf: focus 16"),
  focus_17 = D.new("Fbuffocus17", "buf: focus 17"),
  focus_18 = D.new("Fbuffocus18", "buf: focus 18"),
  focus_19 = D.new("Fbuffocus19", "buf: focus 19"),
  focus_20 = D.new("Fbuffocus20", "buf: focus 20"),
  focus_21 = D.new("Fbuffocus21", "buf: focus 21"),
  focus_22 = D.new("Fbuffocus22", "buf: focus 22"),
  focus_23 = D.new("Fbuffocus23", "buf: focus 23"),
  focus_24 = D.new("Fbuffocus24", "buf: focus 24"),
  focus_25 = D.new("Fbuffocus25", "buf: focus 25"),
  focus_26 = D.new("Fbuffocus26", "buf: focus 26"),
  focus_27 = D.new("Fbuffocus27", "buf: focus 27"),
  focus_28 = D.new("Fbuffocus28", "buf: focus 28"),
  focus_29 = D.new("Fbuffocus29", "buf: focus 29"),
  focus_30 = D.new("Fbuffocus30", "buf: focus 30"),
  focus_31 = D.new("Fbuffocus31", "buf: focus 31"),
  focus_32 = D.new("Fbuffocus32", "buf: focus 32"),
  focus_33 = D.new("Fbuffocus33", "buf: focus 33"),
  focus_34 = D.new("Fbuffocus34", "buf: focus 34"),
  focus_35 = D.new("Fbuffocus35", "buf: focus 35"),
  focus_36 = D.new("Fbuffocus36", "buf: focus 36"),
  focus_37 = D.new("Fbuffocus37", "buf: focus 37"),
  focus_38 = D.new("Fbuffocus38", "buf: focus 38"),
  focus_39 = D.new("Fbuffocus39", "buf: focus 39"),
  focus_40 = D.new("Fbuffocus40", "buf: focus 40"),
  focus_41 = D.new("Fbuffocus41", "buf: focus 41"),
  focus_42 = D.new("Fbuffocus42", "buf: focus 42"),
  focus_43 = D.new("Fbuffocus43", "buf: focus 43"),
  focus_44 = D.new("Fbuffocus44", "buf: focus 44"),
  focus_45 = D.new("Fbuffocus45", "buf: focus 45"),
  focus_46 = D.new("Fbuffocus46", "buf: focus 46"),
  focus_47 = D.new("Fbuffocus47", "buf: focus 47"),
  focus_48 = D.new("Fbuffocus48", "buf: focus 48"),
  focus_49 = D.new("Fbuffocus49", "buf: focus 49"),

  open = D.new("Fopen", "buf: open (bufnr)", 1),
  focus = D.new("Fbuffocus", "buf: focus (bufid)", 1),
  focus_left = D.new("Fbuffocusleft", "buf: focus left", "?"),
  focus_right = D.new("Fbuffocusright", "buf: focus right", "?"),

  swap_left = D.new("Fbufswapleft", "buf: swap left"),
  swap_right = D.new("Fbufswapright", "buf: swap right"),

  new = D.new("Fbufnew", "buf: new"),
  pin = D.new("Fbufpin", "buf: pin"),
  save = D.new("Fbufsave", "buf: save", "?"),
  save_no_format = D.new("Fbufsavenoformat", "buf: save without format"),
}

---@class dot.command.definitions.clipboard
M.definitions.clipboard = {
  paste_image = D.new("Fclipboardpasteimage", "clipboard: paste image"),
  paste_image_as_base64 = D.new("Fclipboardpasteimageasbase64", "clipboard: paste image as base64"),
}

---@class dot.command.definitions.code
M.definitions.code = {
  format = D.new("Fcodeformat", "code: format buffer"),
  insert_splitline = D.new("Fcodeinsertsplitline", "code: insert splitline"),
  run = D.new("Fcoderun", "code: run"),
  run_as_neovim_command = D.new("Fcoderunasneovimcommand", "code: run selection/buffer as :cmd"),
  run_force = D.new("Fcoderunforce", "code: run (force)"),
  swap_conditional_branches = D.new("Fcodeswapconditionalbranches", "code: swap conditional branches"),
  swap_next_parameter = D.new("Fcodeswapnextparameter", "code: swap next parameter"),
  swap_prev_parameter = D.new("Fcodeswapprevparameter", "code: swap prev parameter"),
  trim_trailspace = D.new("Fcodetrimtrailspace", "code: trim trailing whitespace"),
}

---@class dot.command.definitions.copy
M.definitions.copy = {
  char_under_cursor = D.new("Fcopycharundercursor", "copy: char under cursor"),

  filepath = D.new("Fcopyfilepath", "copy: current filepath", "?", { "absolute", "relative", "filename" }),
  filepath_absolute = D.new("Fcopyfilepathabsolute", "copy: current filepath (absolute)"),
  filepath_relative = D.new("Fcopyfilepathrelative", "copy: current filepath (relative)"),
}

---@class dot.command.definitions.diagnostic
M.definitions.diagnostic = {
  goto_next = D.new("Fdiagnosticgotonext", "diagnostic: goto next"),
  goto_next_error = D.new("Fdiagnosticgotonexterror", "diagnostic: goto next (error)"),
  goto_next_warn = D.new("Fdiagnosticgotonextwarn", "diagnostic: goto next (warn)"),
  goto_next_hint = D.new("Fdiagnosticgotonexthint", "diagnostic: goto next (hint)"),
  goto_next_info = D.new("Fdiagnosticgotonextinfo", "diagnostic: goto next (info)"),
  goto_next_quickfix = D.new("Fdiagnosticgotonextquickfix", "diagnostic: goto next (quickfix)"),

  goto_prev = D.new("Fdiagnosticgotoprev", "diagnostic: goto prev"),
  goto_prev_error = D.new("Fdiagnosticgotopreverror", "diagnostic: goto prev (error)"),
  goto_prev_warn = D.new("Fdiagnosticgotoprevwarn", "diagnostic: goto prev (warn)"),
  goto_prev_hint = D.new("Fdiagnosticgotoprevhint", "diagnostic: goto prev (hint)"),
  goto_prev_info = D.new("Fdiagnosticgotoprevinfo", "diagnostic: goto prev (info)"),
  goto_prev_quickfix = D.new("Fdiagnosticgotoprevquickfix", "diagnostic: goto prev (quickfix)"),

  line = D.new("Fdiagnosticline", "diagnostic: line"),
  outline = D.new("Fdiagnosticoutline", "diagnostic: outline"),
  to_md = D.new("Fdiagnostictomd", "diagnostic: export to markdown"),
}

---@class dot.command.definitions.explorer
M.definitions.explorer = {
  focus = D.new("Fexplorerfocus", "explorer: focus"),
  focus_cwd = D.new("Fexplorerfocuscwd", "explorer: focus cwd"),
  focus_workspace = D.new("Fexplorerfocusworkspace", "explorer: focus workspace"),
  hide = D.new("Fexplorerhide", "explorer: hide"),
  refresh = D.new("Fexplorerrefresh", "explorer: refresh"),
  reveal = D.new("Fexplorerreveal", "explorer: reveal current file"),
  toggle = D.new("Fexplorertoggle", "explorer: toggle"),
}

---@class dot.command.definitions.find
M.definitions.find = {
  bufs = D.new("Ffindbufs", "find: buffers"),
  bufs_file = D.new("Ffindbufsfile", "find: buffers (file)"),
  bufs_term = D.new("Ffindbufsterm", "find: buffers (term)"),

  diagnostics = D.new("Ffinddiagnostics", "find: diagnostics"),
  diagnostics_in_workspace = D.new("Ffinddiagnosticsinworkspace", "find: diagnostics (workspace)"),
  explorer = D.new("Ffindexplorer", "find: explorer", "?"),
  files = D.new("Ffindfiles", "find: files", "?"),
  files_in_cwd = D.new("Ffindfilesincwd", "find: files (cwd)"),
  files_in_directory = D.new("Ffindfilesindirectory", "find: files (directory)"),
  files_in_workspace = D.new("Ffindfilesinworkspace", "find: files (workspace)"),
  git_not_committed = D.new("Ffindgitnotcommitted", "find: git not committed"),
  highlights = D.new("Ffindhighlights", "find: highlights"),
  keymaps = D.new("Ffindkeymaps", "find: keymaps"),
  lsp_symbols = D.new("Ffindlspsymbols", "find: lsp symbols"),
  notifications = D.new("Ffindnotifications", "find: notifications"),
  pinned_files = D.new("Ffindpinnedfiles", "find: pinned files"),
  vim_options = D.new("Ffindvimoptions", "find: vim options"),
}

---@class dot.command.definitions.git
M.definitions.git = {
  blame = D.new("Fgitblame", "git: blame line"),
  blame_buffer = D.new("Fgitblamebuffer", "git: blame buffer"),
  browse = D.new("Fgitbrowse", "git: browse"),
  browse_permalink = D.new("Fgitbrowsepermalink", "git: browse (permalink)"),
  browse_repo = D.new("Fgitbrowserepo", "git: browse (repo)"),
  diffview = D.new("Fgitdiffview", "git: diffview"),
  history = D.new("Fgithistory", "git: history (commits)"),
  history_file = D.new("Fgithistoryfile", "git: history (file)"),
  hunk_goto_prev = D.new("Fgithunkgotoprev", "git: goto prev hunk"),
  hunk_goto_next = D.new("Fgithunkgotonext", "git: goto next hunk"),
  hunk_goto_prev_all = D.new("Fgithunkgotoprevall", "git: goto prev hunk (all)"),
  hunk_goto_next_all = D.new("Fgithunkgotonextall", "git: goto next hunk (all)"),
  hunk_preview = D.new("Fgithunkpreview", "git: preview hunk"),
  hunk_stage = D.new("Fgithunkstage", "git: stage hunk"),
  hunk_stage_visual = D.new("Fgithunkstagevisual", "git: stage hunk (visual)"),
  hunk_unstage = D.new("Fgithunkunstage", "git: unstage hunk"),
  hunk_unstage_visual = D.new("Fgithunkunstagevisual", "git: unstage hunk (visual)"),
  hunk_reset = D.new("Fgithunkreset", "git: reset hunk"),
  hunk_reset_visual = D.new("Fgithunkresetvisual", "git: reset hunk (visual)"),
  stage_buffer = D.new("Fgitstagebuffer", "git: stage buffer"),
  reset_buffer = D.new("Fgitresetbuffer", "git: reset buffer"),
}

---@class dot.command.definitions.inspect
M.definitions.inspect = {
  inspect_buf = D.new("Fdebuginspectbuf", "debug: inspect buf"),
  inspect_pos = D.new("Fdebuginspectpos", "debug: inspect pos"),
  inspect_state = D.new("Fdebuginspectstate", "debug: inspect state"),
  inspect_state_full = D.new("Fdebuginspectstatefull", "debug: inspect state (full)"),
  inspect_tab = D.new("Fdebuginspecttab", "debug: inspect tab"),
  inspect_tree = D.new("Fdebuginspecttree", "debug: inspect tree"),
  inspect_window = D.new("Fdebuginspectwindow", "debug: inspect window"),
}

---@class dot.command.definitions.lint
M.definitions.lint = {
  spellcheck_register = D.new("Flintspellcheckregister", "lint: add word to cspell dictionary"),
}

---@class dot.command.definitions.log
M.definitions.log = {
  preview_json_normal = D.new("Fjsonviewnormal", "json: preview current line"),
  preview_json_visual = D.new("Fjsonviewvisual", "json: preview selection"),
}

---@class dot.command.definitions.lsp
M.definitions.lsp = {
  goto_definitions = D.new("Flspgotodefinitions", "lsp: goto definitions"),
  goto_implementations = D.new("Flspgotoimplementations", "lsp: goto implementations"),
  goto_references = D.new("Flspgotoreferences", "lsp: goto references"),
  goto_type_definitions = D.new("Flspgototypedefinitions", "lsp: goto type definitions"),

  goto_prev_reference = D.new("Flspgotoprevreference", "lsp: goto prev reference"),
  goto_next_reference = D.new("Flspgotonextreference", "lsp: goto next reference"),

  restart = D.new("Flsprestart", "lsp: restart"),
  select_python_venv = D.new("Flspselectpythonvenv", "lsp: select python venv"),
}

---@class dot.command.definitions.notepad
M.definitions.notepad = {
  append_content = D.new("Fnotepadappendcontent", "notepad: append content", 1),
  create = D.new("Fnotepadcreate", "notepad: create"),
  destroy = D.new("Fnotepaddestroy", "notepad: destroy"),
  rename = D.new("Fnotepadrename", "notepad: rename"),
  toggle = D.new("Fnotepadtoggle", "notepad: toggle"),
  save = D.new("Fnotepadsave", "notepad: save"),
  show = D.new("Fnotepadshow", "notepad: show"),
  close = D.new("Fnotepadclose", "notepad: close"),
  focus_1 = D.new("Fnotepadfocus1", "notepad: focus 1"),
  focus_2 = D.new("Fnotepadfocus2", "notepad: focus 2"),
  focus_3 = D.new("Fnotepadfocus3", "notepad: focus 3"),
  focus_4 = D.new("Fnotepadfocus4", "notepad: focus 4"),
  focus_5 = D.new("Fnotepadfocus5", "notepad: focus 5"),
  focus_6 = D.new("Fnotepadfocus6", "notepad: focus 6"),
  focus_7 = D.new("Fnotepadfocus7", "notepad: focus 7"),
  focus_8 = D.new("Fnotepadfocus8", "notepad: focus 8"),
  focus_9 = D.new("Fnotepadfocus9", "notepad: focus 9"),
  focus_left = D.new("Fnotepadfocusleft", "notepad: focus left", "?"),
  focus_left_1 = D.new("Fnotepadfocusleft1", "notepad: focus left 1"),
  focus_left_2 = D.new("Fnotepadfocusleft2", "notepad: focus left 2"),
  focus_left_3 = D.new("Fnotepadfocusleft3", "notepad: focus left 3"),
  focus_left_4 = D.new("Fnotepadfocusleft4", "notepad: focus left 4"),
  focus_left_5 = D.new("Fnotepadfocusleft5", "notepad: focus left 5"),
  focus_left_6 = D.new("Fnotepadfocusleft6", "notepad: focus left 6"),
  focus_left_7 = D.new("Fnotepadfocusleft7", "notepad: focus left 7"),
  focus_left_8 = D.new("Fnotepadfocusleft8", "notepad: focus left 8"),
  focus_left_9 = D.new("Fnotepadfocusleft9", "notepad: focus left 9"),
  focus_right = D.new("Fnotepadfocusright", "notepad: focus right", "?"),
  focus_right_1 = D.new("Fnotepadfocusright1", "notepad: focus right 1"),
  focus_right_2 = D.new("Fnotepadfocusright2", "notepad: focus right 2"),
  focus_right_3 = D.new("Fnotepadfocusright3", "notepad: focus right 3"),
  focus_right_4 = D.new("Fnotepadfocusright4", "notepad: focus right 4"),
  focus_right_5 = D.new("Fnotepadfocusright5", "notepad: focus right 5"),
  focus_right_6 = D.new("Fnotepadfocusright6", "notepad: focus right 6"),
  focus_right_7 = D.new("Fnotepadfocusright7", "notepad: focus right 7"),
  focus_right_8 = D.new("Fnotepadfocusright8", "notepad: focus right 8"),
  focus_right_9 = D.new("Fnotepadfocusright9", "notepad: focus right 9"),
  swap_left = D.new("Fnotepadswapleft", "notepad: swap left", "?"),
  swap_right = D.new("Fnotepadswapright", "notepad: swap right", "?"),
  source_select = D.new("Fnotepadsourceselect", "notepad: select source"),
  note_select = D.new("Fnotepadnoteselect", "notepad: select note"),
  source_prev = D.new("Fnotepadsourceprev", "notepad: previous source"),
  source_next = D.new("Fnotepadsourcenext", "notepad: next source"),
  change_engine = D.new("Fnotepadchangeengine", "notepad: change storage engine"),
  go_backward = D.new("Fnotepadgobackward", "notepad: go backward in history"),
  go_forward = D.new("Fnotepadgoforward", "notepad: go forward in history"),
  split_h = D.new("Fnotepadsplith", "notepad: split left"),
  split_j = D.new("Fnotepadsplitj", "notepad: split below"),
  split_k = D.new("Fnotepadsplitk", "notepad: split above"),
  split_l = D.new("Fnotepadsplitl", "notepad: split right"),
}

---@class dot.command.definitions.plugin
M.definitions.plugin = {
  open = D.new("Fpluginopen", "plugin: open"),
}

---@class dot.command.definitions.refresh
M.definitions.refresh = {
  all = D.new("Frefreshall", "refresh: all"),
}

---@class dot.command.definitions.search
M.definitions.search = {
  in_files = D.new("Fsearchinfiles", "search: in files", "?"),
  in_file = D.new("Fsearchinfile", "search: in file", "?"),
  in_buffer = D.new("Fsearchinbuffer", "search: in buffer"),
  in_cwd = D.new("Fsearchincwd", "search: in cwd"),
  in_directory = D.new("Fsearchindirectory", "search: in directory"),
  in_workspace = D.new("Fsearchinworkspace", "search: in workspace"),
}

---@class dot.command.definitions.session
M.definitions.session = {
  restore = D.new("Fsessionrestore", "session: restore"),
  restore_autosaved = D.new("Fsessionrestoreautosaved", "session: restore autosaved"),

  save = D.new("Fsessionsave", "session: save"),
}

---@class dot.command.definitions.tab
M.definitions.tab = {
  close = D.new("Ftabclose", "tab: close"),
  close_others = D.new("Ftabcloseothers", "tab: close others"),
  close_to_leftest = D.new("Ftabclosetoleftest", "tab: close to leftest"),
  close_to_rightest = D.new("Ftabclosetorightest", "tab: close to rightest"),

  focus_1 = D.new("Ftabfocus1", "tab: focus 1"),
  focus_2 = D.new("Ftabfocus2", "tab: focus 2"),
  focus_3 = D.new("Ftabfocus3", "tab: focus 3"),
  focus_4 = D.new("Ftabfocus4", "tab: focus 4"),
  focus_5 = D.new("Ftabfocus5", "tab: focus 5"),
  focus_6 = D.new("Ftabfocus6", "tab: focus 6"),
  focus_7 = D.new("Ftabfocus7", "tab: focus 7"),
  focus_8 = D.new("Ftabfocus8", "tab: focus 8"),
  focus_9 = D.new("Ftabfocus9", "tab: focus 9"),
  focus_10 = D.new("Ftabfocus10", "tab: focus 10"),
  focus = D.new("Ftabfocus", "tab: focus", 1),
  focus_left = D.new("Ftabfocusleft", "tab: focus left", "?"),
  focus_right = D.new("Ftabfocusright", "tab: focus right", "?"),

  new = D.new("Ftabnew", "tab: new"),
  new_with_buf = D.new("Ftabnewwithbuf", "tab: new with buf"),
}

---@class dot.command.definitions.term
M.definitions.term = {
  create = D.new("Ftermcreate", "term: create"),
  destroy = D.new("Ftermdestroy", "term: destroy"),
  rename = D.new("Ftermrename", "term: rename"),
  toggle = D.new("Ftermtoggle", "term: toggle"),

  lazygit_cwd = D.new("Ftermlazygitcwd", "term: lazygit (cwd)"),
  lazygit_file_history = D.new("Ftermlazygitfilehistory", "term: lazygit (file history)"),

  yazi_cwd = D.new("Ftermyazicwd", "term: yazi (cwd)"),
  yazi_reveal = D.new("Ftermyazireveal", "term: yazi (reveal)"),
  yazi_workspace = D.new("Ftermyaziworkspace", "term: yazi (workspace)"),

  focus_1 = D.new("Ftermfocus1", "term: focus 1"),
  focus_2 = D.new("Ftermfocus2", "term: focus 2"),
  focus_3 = D.new("Ftermfocus3", "term: focus 3"),
  focus_4 = D.new("Ftermfocus4", "term: focus 4"),
  focus_5 = D.new("Ftermfocus5", "term: focus 5"),
  focus_6 = D.new("Ftermfocus6", "term: focus 6"),
  focus_7 = D.new("Ftermfocus7", "term: focus 7"),
  focus_8 = D.new("Ftermfocus8", "term: focus 8"),
  focus_9 = D.new("Ftermfocus9", "term: focus 9"),
  focus_left = D.new("Ftermfocusleft", "term: focus left", "?"),
  focus_right = D.new("Ftermfocusright", "term: focus right", "?"),
  swap_left = D.new("Ftermswapleft", "term: swap left", "?"),
  swap_right = D.new("Ftermswapright", "term: swap right", "?"),
  split_h = D.new("Ftermsplith", "term: split left"),
  split_j = D.new("Ftermsplitj", "term: split below"),
  split_k = D.new("Ftermsplitk", "term: split above"),
  split_l = D.new("Ftermsplitl", "term: split right"),
}

---@class dot.command.definitions.toggle
M.definitions.toggle = {
  dim = D.new("Ftoggledim", "toggle: dim"),
  expandtab = D.new("Ftoggleexpandtab", "toggle: expandtab"),
  indent = D.new("Ftoggleindent", "toggle: indent"),
  list = D.new("Ftoggle", "toggle: select", "?", dot.var.toggler),
  markdown = D.new("Ftogglemarkdown", "toggle: markdown"),
  markdown_local = D.new("Ftogglemarkdownlocal", "toggle: markdown (local)"),
  maximize = D.new("Ftogglemaximize", "toggle: maximize"),
  number_local = D.new("Ftogglenumberlocal", "toggle: number (local)"),
  relativenumber = D.new("Ftogglerelativenumber", "toggle: relativenumber"),
  relativenumber_local = D.new("Ftogglerelativenumberlocal", "toggle: relativenumber (local)"),
  scroll = D.new("Ftogglescroll", "toggle: scroll"),
  signcolumn_local = D.new("Ftogglesigncolumnlocal", "toggle: signcolumn (local)"),
  theme = D.new("Ftoggletheme", "toggle: theme", "?", dot.var.themes),
  theme_variant = D.new("Ftogglethemevariant", "toggle: theme variant"),
  trailspace = D.new("Ftoggletrailspace", "toggle: trailspace"),
  transparency = D.new("Ftoggletransparency", "toggle: transparency"),
  username = D.new("Ftoggleusername", "toggle: username"),
  virtcolumn = D.new("Ftogglevirtcolumn", "toggle: virtcolumn"),
  wrap_local = D.new("Ftogglewraplocal", "toggle: wrap (local)"),
}

---@class dot.command.definitions.ux
M.definitions.ux = {
  color_picker = D.new("Fuxcolorpicker", "ux: color picker"),
  dismiss_notifications = D.new("Fuxdismissnotifications", "ux: dismiss notifications"),
  reload_theme = D.new("Fuxreloadtheme", "ux: reload theme", "?"),
  resume_last_widget = D.new("Fuxresume", "ux: resume last widget"),
}

---@class dot.command.definitions.view
M.definitions.view = {
  notifications = D.new("Fviewnotifications", "view: notification history"),
}

---@class dot.command.definitions.win
M.definitions.win = {
  close = D.new("Fwinclose", "win: close"),
  close_others = D.new("Fwincloseothers", "win: close others"),

  focus_top = D.new("Fwinfocustop", "win: focus top"),
  focus_right = D.new("Fwinfocusright", "win: focus right"),
  focus_bottom = D.new("Fwinfocusbottom", "win: focus bottom"),
  focus_left = D.new("Fwinfocusleft", "win: focus left"),
  focus_prev = D.new("Fwinfocusprev", "win: focus prev"),
  focus_next = D.new("Fwinfocusnext", "win: focus next"),

  history = D.new("Fwinhistory", "win: history"),
  history_backward = D.new("Fwinhistorybackward", "win: history backward"),
  history_forward = D.new("Fwinhistoryforward", "win: history forward"),

  resize_horizontal_minus = D.new("Fwinresizehorizontalminus", "win: resize horizontal (minus)"),
  resize_horizontal_plus = D.new("Fwinresizehorizontalplus", "win: resize horizontal (plus)"),
  resize_vertical_minus = D.new("Fwinresizeverticalminus", "win: resize vertical (minus)"),
  resize_vertical_plus = D.new("Fwinresizeverticalplus", "win: resize vertical (plus)"),

  split_above = D.new("Fwinsplitabove", "win: split above"),
  split_right = D.new("Fwinsplitright", "win: split right"),
  split_below = D.new("Fwinsplitbelow", "win: split below"),
  split_left = D.new("Fwinsplitleft", "win: split left"),

  focus = D.new("Fwinfocus", "win: focus (with picker)"),
  project = D.new("Fwinproject", "win: project (with picker)"),
  swap = D.new("Fwinswap", "win: swap (with picker)"),

  mark_sourcefile = D.new("Fwinmarksoucefile", "win: mark sourcefile"),
}

return M
