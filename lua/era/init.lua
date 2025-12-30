---@class era.fn.__mods
local __fn__mods = {
  add_locations_to_ai = "era.fn.add_locations_to_ai",
  find_buffers = "era.fn.find-buffers",
  find_diagnostics = "era.fn.find-diagnostics",
  find_explorer = "era.fn.find-explorer",
  find_files = "era.fn.find-files",
  find_git = "era.fn.find-git",
  find_highlights = "era.fn.find-highlights",
  find_keymaps = "era.fn.find-keymaps",
  find_lsp_symbols = "era.fn.find-lsp-symbols",
  find_notifications = "era.fn.find-notifications",
  find_pinned_files = "era.fn.find-pinned-files",
  find_vim_options = "era.fn.find-vim-options",
  insert_splitline = "era.fn.insert-splitline",
  mock_miniicons = "era.fn.mock_miniicons",
  mock_web_devicons = "era.fn.mock_web_devicons",
  paste_image = "era.fn.paste_image",
  paste_image_as_base64 = "era.fn.paste_image_as_base64",
  pick_win = "era.fn.pick_win",
  refresh_all = "era.fn.refresh_all",
  rename = "era.fn.rename",
  resume_last_widget = "era.fn.resume_last_widget",
  run_code = "era.fn.run_code",
  run_code_as_neovim_command = "era.fn.run_code_as_neovim_command",
  search_in_buffer = "era.fn.search-in-buffer",
  search_in_files = "era.fn.search-in-files",
  select_copy_filepath = "era.fn.select_copy_filepath",
  select_copy_filepaths = "era.fn.select_copy_filepaths",
  select_encoding = "era.fn.select_encoding",
}

---@class era.fn
---@field public __mods                 era.fn.__mods
---@field public add_locations_to_ai    fun(locations: dot.t.ILocation[]): nil
---@field public find_buffers           fun(scope: dot.e.FindBufferScope|nil): nil
---@field public find_diagnostics       fun(): nil
---@field public find_explorer          fun(specified_filepath: string|nil): nil
---@field public find_files             fun(rootpath: string|"cwd"|"directory"|"workspace"|nil, reset_input: boolean|nil): nil
---@field public find_git               fun(): nil
---@field public find_highlights        fun(): nil
---@field public find_keymaps           fun(): nil
---@field public find_lsp_symbols       fun(): nil
---@field public find_notifications     fun(): nil
---@field public find_pinned_files      fun(): nil
---@field public find_vim_options       fun(): nil
---@field public insert_splitline       fun(): nil
---@field public mock_miniicons         fun(): nil
---@field public mock_web_devicons      fun(): nil
---@field public paste_image            fun(): nil
---@field public paste_image_as_base64  fun(): string|nil
---@field public pick_win               era.fn.pick_win
---@field public refresh_all            fun(): nil
---@field public rename                 era.fn.rename
---@field public resume_last_widget     fun(): nil
---@field public run_code               fun(force: boolean): nil
---@field public run_code_as_neovim_command fun(): nil
---@field public search_in_buffer       fun(): nil
---@field public search_in_files        fun(rootpath: string|"cwd"|"directory"|"workspace"|"file"|nil, reset_input: boolean|nil): nil
---@field public select_copy_filepath   fun(params: era.fn.select_copy_filepath.IParams): integer
---@field public select_copy_filepaths  fun(params: era.fn.select_copy_filepaths.IParams): integer
---@field public select_encoding        fun(params: era.fn.select_encoding.IParams): era.m.picker.ListComposer
local fn = setmetatable({
  __mods = __fn__mods,
}, {
  __index = function(t, k)
    local m = __fn__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era.m.__mods
local __m__mods = {
  ai = "era.m.ai",
  clipboard = "era.m.clipboard",
  colorpicker = "era.m.colorpicker",
  commentstring = "era.m.commentstring",
  copy = "era.m.copy",
  dim = "era.m.dim",
  explorer = "era.m.explorer",
  foldtext = "era.m.foldtext",
  git = "era.m.git",
  illuminate = "era.m.illuminate",
  im = "era.m.im",
  image = "era.m.image",
  input = "era.m.input",
  inspect = "era.m.inspect",
  lsp = "era.m.lsp",
  maximize = "era.m.maximize",
  notepad = "era.m.notepad",
  notifier = "era.m.notifier",
  nvimbar = "era.m.nvimbar",
  picker = "era.m.picker",
  plugin = "era.m.plugin",
  python_venv = "era.m.python_venv",
  scroll = "era.m.scroll",
  searcher = "era.m.searcher",
  select = "era.m.select",
  statuscolumn = "era.m.statuscolumn",
  statusline = "era.m.statusline",
  tabline = "era.m.tabline",
  term = "era.m.term",
  trailspace = "era.m.trailspace",
  ui_attach = "era.m.ui_attach",
  virtcolumn = "era.m.virtcolumn",
  winline = "era.m.winline",
  winpicker = "era.m.winpicker",
  winsep = "era.m.winsep",
}

---@class era.m
---@field public __mods                 era.m.__mods
---@field public ai                     era.m.ai
---@field public clipboard              era.m.clipboard
---@field public colorpicker            era.m.colorpicker
---@field public commentstring          era.m.commentstring
---@field public copy                   era.m.copy
---@field public dim                    era.m.dim
---@field public explorer               era.m.explorer
---@field public foldtext               era.m.foldtext
---@field public git                    era.m.git
---@field public illuminate             era.m.illuminate
---@field public im                     era.m.im
---@field public image                  era.m.image
---@field public input                  era.m.input
---@field public inspect                era.m.inspect
---@field public lsp                    era.m.lsp
---@field public maximize               era.m.maximize
---@field public notepad                era.m.notepad
---@field public notifier               era.m.notifier
---@field public nvimbar                era.m.nvimbar
---@field public picker                 era.m.picker
---@field public plugin                 era.m.plugin
---@field public python_venv            era.m.python_venv
---@field public scroll                 era.m.scroll
---@field public searcher               era.m.searcher
---@field public select                 era.m.select
---@field public statuscolumn           era.m.statuscolumn
---@field public statusline             era.m.statusline
---@field public tabline                era.m.tabline
---@field public term                   era.m.term
---@field public trailspace             era.m.trailspace
---@field public ui_attach              era.m.ui_attach
---@field public virtcolumn             era.m.virtcolumn
---@field public winline                era.m.winline
---@field public winpicker              era.m.winpicker
---@field public winsep                 era.m.winsep
local m = setmetatable({
  __mods = __m__mods,
}, {
  __index = function(t, k)
    local mod = __m__mods[k] ---@type string|nil
    if mod == nil then
      return rawget(t, k)
    end
    return require(mod)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era.view.__mods
local __view__mods = {
  Act = "era.view.act",
  Fileinfo = "era.view.fileinfo",
  Keysheet = "era.view.keysheet",
  Plainfile = "era.view.plainfile",
  Printer = "era.view.printer",
  Setting = "era.view.setting",
  Textarea = "era.view.textarea",
  Tree = "era.view.tree",
}

---@class era.view
---@field public __mods                 era.view.__mods
---@field public Act                    era.view.Act
---@field public Fileinfo               era.view.Fileinfo
---@field public Keysheet               era.view.Keysheet
---@field public Plainfile              era.view.Plainfile
---@field public Printer                era.view.Printer
---@field public Setting                era.view.Setting
---@field public Textarea               era.view.Textarea
---@field public Tree                   era.view.Tree
local view = setmetatable({
  __mods = __view__mods,
}, {
  __index = function(t, k)
    local mod = __view__mods[k] ---@type string|nil
    if mod == nil then
      return rawget(t, k)
    end
    return require(mod)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era.widget.__mods
local __widget__mods = {
  explorer = "era.widget.explorer",
}

---@class era.widget
---@field public __mods                 era.widget.__mods
---@field public explorer               era.widget.explorer
local widget = setmetatable({
  __mods = __widget__mods,
}, {
  __index = function(t, k)
    local mod = __widget__mods[k] ---@type string|nil
    if mod == nil then
      return rawget(t, k)
    end
    return require(mod)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era
---@field public fn                     era.fn
---@field public m                      era.m
---@field public view                   era.view
---@field public widget                 era.widget
local M = {
  fn = fn,
  m = m,
  view = view,
  widget = widget,
}

return M
