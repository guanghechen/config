local util_path = require("guanghechen.util.path")
local Replacer = require("kyokuya.replace.replacer")
local theme = require("kyokuya.theme")

local nsnr = 0
local highlighter = theme
  .get_highlighter("darken")
  :register("kyokuya_invisible", { fg = "none", bg = "none" })
  :register("kyokuya_replace_cfg_name", { fg = "blue", bg = "none", bold = true })
  :register("kyokuya_replace_cfg_value", { fg = "yellow", bg = "none" })
  :register("kyokuya_replace_cfg_search_pattern", { fg = "diff_delete_hl", bg = "none" })
  :register("kyokuya_replace_cfg_replace_pattern", { fg = "diff_add_hl", bg = "none" })
  :register("kyokuya_replace_filepath", { fg = "blue", bg = "none" })
  :register("kyokuya_replace_text_deleted", { fg = "diff_delete_hl", bg = "none" })
  :register("kyokuya_replace_text_added", { fg = "diff_add_hl", bg = "none" })
highlighter:apply(nsnr)

---@type kyokuya.replace.Replacer
local replacer = Replacer.new({
  nsnr = nsnr,
  winnr = 0,
  reuse = true,
  data = {
    mode = "replace",
    cwd = util_path.cwd(),
    flag_regex = true,
    flag_case_sensitive = true,
    search_pattern = "Hello, (world|世界)!\\n",
    replace_pattern = 'hello - "$1"',
    search_paths = "rust/",
    include_patterns = "*.txt",
    exclude_patterns = ".git/, c.txt",
  },
})

local cur_winnr = vim.api.nvim_get_current_win()
local cur_bufnr = vim.api.nvim_get_current_buf()
replacer:replace()
vim.api.nvim_set_current_win(cur_winnr)
vim.api.nvim_set_current_buf(cur_bufnr)
