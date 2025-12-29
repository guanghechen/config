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
---@field public select_encoding        fun(params: era.fn.select_encoding.IParams): era.picker.ListComposer
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

---@class era.__mods
local __mods = {
  ai = "era.ai",
  clipboard = "era.clipboard",
  colorpicker = "era.colorpicker",
  commentstring = "era.commentstring",
  explorer = "era.explorer",
  foldtext = "era.foldtext",
  git = "era.git",
  illuminate = "era.illuminate",
  im = "era.im",
  image = "era.image",
  lsp = "era.lsp",
  nvimbar = "era.nvimbar",
  picker = "era.picker",
  plugin = "era.plugin",
  scroll = "era.scroll",
  searcher = "era.searcher",
  statuscolumn = "era.statuscolumn",
  statusline = "era.statusline",
  term = "era.term",
  trailspace = "era.trailspace",
  view = "era.view",
  winpicker = "era.winpicker",
}

---@class era
---@field public __mods                 era.__mods
---@field public ai                     era.ai
---@field public clipboard              era.clipboard
---@field public colorpicker            era.colorpicker
---@field public commentstring          era.commentstring
---@field public explorer               era.explorer
---@field public fn                     era.fn
---@field public foldtext               era.foldtext
---@field public git                    era.git
---@field public illuminate             era.illuminate
---@field public im                     era.im
---@field public image                  era.image
---@field public lsp                    era.lsp
---@field public nvimbar                era.nvimbar
---@field public picker                 era.picker
---@field public plugin                 era.plugin
---@field public scroll                 era.scroll
---@field public searcher               era.searcher
---@field public statuscolumn           era.statuscolumn
---@field public statusline             era.statusline
---@field public term                   era.term
---@field public trailspace             era.trailspace
---@field public view                   era.view
---@field public winpicker              era.winpicker
local M = setmetatable({
  __mods = __mods,
  fn = fn,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
