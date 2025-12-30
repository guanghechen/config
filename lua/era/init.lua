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
  paste_image = "era.fn.paste_image",
  paste_image_as_base64 = "era.fn.paste_image_as_base64",
  pick_win = "era.fn.pick_win",
  rename = "era.fn.rename",
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
---@field public paste_image            fun(): nil
---@field public paste_image_as_base64  fun(): string|nil
---@field public pick_win               era.fn.pick_win
---@field public rename                 era.fn.rename
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
  dim = "era.m.dim",
  explorer = "era.m.explorer",
  foldtext = "era.m.foldtext",
  git = "era.m.git",
  illuminate = "era.m.illuminate",
  im = "era.m.im",
  image = "era.m.image",
  input = "era.m.input",
  lsp = "era.m.lsp",
  notifier = "era.m.notifier",
  nvimbar = "era.m.nvimbar",
  picker = "era.m.picker",
  plugin = "era.m.plugin",
  python_venv = "era.m.python_venv",
  scroll = "era.m.scroll",
  searcher = "era.m.searcher",
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
---@field public dim                    era.m.dim
---@field public explorer               era.m.explorer
---@field public foldtext               era.m.foldtext
---@field public git                    era.m.git
---@field public illuminate             era.m.illuminate
---@field public im                     era.m.im
---@field public image                  era.m.image
---@field public input                  era.m.input
---@field public lsp                    era.m.lsp
---@field public notifier               era.m.notifier
---@field public nvimbar                era.m.nvimbar
---@field public picker                 era.m.picker
---@field public plugin                 era.m.plugin
---@field public python_venv            era.m.python_venv
---@field public scroll                 era.m.scroll
---@field public searcher               era.m.searcher
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
  Select = "era.view.select",
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
---@field public Select                 era.view.Select
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

---@class era
---@field public fn                     era.fn
---@field public m                      era.m
---@field public view                   era.view
local M = {
  fn = fn,
  m = m,
  view = view,
}

return M
