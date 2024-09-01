---@diagnostic disable: unused-function, unused-local
local function match()
  ---@type string[]
  local items = fc.oxi.find({
    workspace = fc.path.workspace(),
    cwd = fc.path.cwd(),
    flag_case_sensitive = false,
    flag_gitignore = true,
    flag_regex = false,
    search_pattern = "",
    search_paths = "",
    exclude_patterns = ".git/**",
  })

  local matches = {} ---@type fml.types.ui.select.IMatchedItem[]
  local input = "observable" ---@type string
  local N1 = #input ---@type integer
  for lnum, text in ipairs(items) do
    local l = 1 ---@type integer
    local r = N1 ---@type integer
    local score = 0 ---@type integer
    local pieces = {} ---@type fml.types.IMatchPoint[]
    local N2 = #text ---@type integer
    while r <= N2 do
      if string.sub(text, l, r) == input then
        table.insert(pieces, { l = l, r = r })
        score = score + 10
        l = r + 1
        r = r + N1
      else
        l = l + 1
        r = r + 1
      end
    end
    if #pieces > 0 then
      table.insert(matches, { lnum = lnum, score = score, pieces = pieces })
    end
  end
  fml.debug.log({ matches = matches })
end

local function strwidth()
  local filepath_1 = "rust/中文/tests/fixtures/a.txt"
  local filepath_2 = "rust/中文/tests/fixtures/aa.rs"

  local filename_1 = fc.path.basename(filepath_1) ---@type string
  local filename_2 = fc.path.basename(filepath_2) ---@type string

  local icon_1 = fml.util.calc_fileicon(filename_1) ---@type string
  local icon_2 = fml.util.calc_fileicon(filename_1) ---@type string
  local icon_1_len = string.len(icon_1) ---@type integer
  local icon_2_len = string.len(icon_2) ---@type integer

  local text_1 = icon_1 .. " " .. filepath_1 ---@type string
  local text_2 = icon_2 .. " " .. filepath_2 ---@type string

  fml.debug.log({
    text_1 = text_1,
    text_2 = text_2,
    text_1_len = string.len(text_1),
    text_2_len = string.len(text_2),
    text_1_width = vim.fn.strwidth(text_1),
    text_2_width = vim.fn.strwidth(text_2),
  })

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { text_1, text_2 })
  vim.api.nvim_buf_add_highlight(bufnr, 0, "f_us_main_match", 0, icon_1_len, icon_1_len + 12)
  vim.api.nvim_buf_add_highlight(bufnr, 0, "f_us_main_match", 1, icon_2_len, icon_2_len + 12)
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    anchor = "NW",
    height = 4,
    width = 80,
    row = math.floor((vim.o.lines - 4) / 2),
    col = math.floor((vim.o.columns - 80) / 2),
    focusable = true,
    title = "",
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    style = "minimal",
  })
  vim.keymap.set("n", "q", "<cmd>q<cr>", { buffer = bufnr, nowait = true })
end

fml.debug.log(string.sub("hello", 1, 2))
