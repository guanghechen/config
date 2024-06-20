local util_path = require("guanghechen.util.path")
local Replacer = require("kyokuya.replace.replacer")
local theme = require("kyokuya.theme")

local nsnr = Replacer.nsnr ---@type integer
local highlighter = theme
  .get_highlighter("darken")
  :register("kyokuya_invisible", { fg = "none", bg = "none" })
  :register("kyokuya_replace_cfg_name", { fg = "blue", bg = "none", bold = true })
  :register("kyokuya_replace_cfg_value", { fg = "yellow", bg = "none" })
  :register("kyokuya_replace_cfg_search_pattern", { fg = "diff_delete_hl", bg = "none" })
  :register("kyokuya_replace_cfg_replace_pattern", { fg = "diff_add_hl", bg = "none" })
highlighter:apply(nsnr)

---@type kyokuya.types.IReplacerState
local options = {
  mode = "replace",
  cwd = util_path.cwd(),
  flag_regex = true,
  flag_case_sensitive = true,
  search_pattern = 'require\\("(guanghechen\\.util\\.(os|clipboard))"\\)',
  replace_pattern = 'import "$1"',
  search_paths = { "lua/" },
  include_patterns = { "*.lua" },
  exclude_patterns = { "" },
}

local replacer = Replacer.new({ reuse = true })

local cur_winnr = vim.api.nvim_get_current_win()
local cur_bufnr = vim.api.nvim_get_current_buf()
replacer:replace({ winnr = 0, state = options })
vim.api.nvim_set_current_win(cur_winnr)
vim.api.nvim_set_current_buf(cur_bufnr)

local function check_replace()
  local nvim_tools = require("nvim_tools")
  local JSON = require("guanghechen.util.json")
  local options_stringified = JSON.stringify(options)
  local result_str = nvim_tools.replace(options_stringified)
  local result = JSON.parse(result_str)
  vim.notify("result" .. vim.inspect(result))
end

local function test_highlight()
  local replace_nsnr = Replacer.nsnr ---@type integer
  local replace_bufnr = replacer:get_bufnr() ---@type integer|nil

  local function print_highlight_groups()
    local keys = { "field_search_pattern_key", "field_search_pattern_val" }
    local hl_list = {}
    for _, key in ipairs(keys) do
      local hl = vim.api.nvim_get_hl(replace_nsnr, { name = key })
      hl_list[key] = hl
    end
    vim.notify("hl_list: " .. vim.inspect(hl_list))
  end

  if replace_bufnr ~= nil then
    vim.notify("test_highlight: " .. vim.inspect({
      replace_nsnr = replace_nsnr,
      replace_bufnr = replace_bufnr,
    }))

    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_invisible", 1, 0, 6)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_invisible", 2, 0, 5)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_invisible", 3, 0, 9)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_invisible", 4, 0, 0)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_invisible", 5, 0, 5)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_invisible", 6, 0, 5)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_name", 1, 6, 14)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_name", 2, 5, 14)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_name", 3, 9, 14)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_name", 4, 0, 14)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_name", 5, 5, 14)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_name", 6, 5, 14)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_value", 1, 14, -1)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_value", 2, 14, -1)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_value", 3, 14, -1)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_value", 4, 14, -1)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_value", 5, 14, -1)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_value", 6, 14, -1)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_search_pattern", 1, 14, -1)
    vim.api.nvim_buf_add_highlight(replace_bufnr, nsnr, "kyokuya_replace_cfg_replace_pattern", 2, 14, -1)
    print_highlight_groups()
  end
end

test_highlight()
