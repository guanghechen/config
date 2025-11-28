local __module_name__ = "fml.dressing.virtcolumn" ---@type string

local NS = vim.api.nvim_create_namespace("virtcolumn")
local VIRT_CHAR = "╎"
local COLUMNS = { 100, 120 }
local HLGROUPS = { "h_virtcolumn_1", "h_virtcolumn_2" }
local PRIORITY = 10

---@param bufnr                         integer
---@param topline                       integer
---@param botline                       integer
---@return nil
local function render(bufnr, topline, botline)
  local rep = string.rep(" ", vim.bo[bufnr].tabstop or 8)
  local lines = vim.api.nvim_buf_get_lines(bufnr, topline - 1, botline, false)

  local marks = vim.tbl_filter(
    function(v)
      return v[4].virt_text_pos == "inline"
    end,
    vim.api.nvim_buf_get_extmarks(bufnr, -1, { topline - 1, 0 }, { botline - 1, 0 }, {
      details = true,
      type = "virt_text",
    })
  )

  local lines_offset = {}
  for _, mark in ipairs(marks) do
    local row = mark[2]
    local line_idx = row - topline + 2
    local line = lines[line_idx]
    if line then
      line = line:gsub("\t", rep)
      local offset = lines_offset[row] or 0
      local col = mark[3] + offset
      local text = table.concat(
        vim.tbl_map(function(v)
          return v[1]
        end, mark[4].virt_text),
        ""
      )
      line = line:sub(1, col) .. text .. line:sub(col + 1)
      lines[line_idx] = line
      lines_offset[row] = offset + #text
    end
  end

  local leftcol = vim.fn.winsaveview().leftcol or 0

  for idx, line in ipairs(lines) do
    local lnum = topline - 1 + idx - 1
    line = line:gsub("\t", rep)

    vim.api.nvim_buf_clear_namespace(bufnr, NS, lnum, lnum + 1)

    for i, col in ipairs(COLUMNS) do
      local char_at_col = vim.fn.strpart(line, col - 1, 1)
      if #line < col or char_at_col == " " then
        vim.api.nvim_buf_set_extmark(bufnr, NS, lnum, 0, {
          virt_text = { { VIRT_CHAR, HLGROUPS[i] } },
          hl_mode = "combine",
          virt_text_win_col = col - 1 - leftcol,
          priority = PRIORITY,
        })
      end
    end
  end
end

---@return nil
local function refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  if not eve.buf.is_sourcefile(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
    return
  end

  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  if info == nil then
    return
  end

  local topline = info.topline
  local botline = info.botline
  local height = info.height or 0
  local extend = math.floor(height * 0.4)

  local offset = math.max(0, topline - extend)
  local endline = botline + extend

  render(bufnr, offset + 1, endline)
end

---@type std.collection.Scheduler
local scheduler = std.Scheduler.new({
  name = __module_name__,
  mode = "debounce",
  delay = 20,
  timeout = 0,
  silent = std.fn.falsy,
  value = std.Observable.from_value(true),
  task = function()
    local enabled = eve.context.flight.dressing_virtcolumn:snapshot()
    if not enabled then
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
      end
      return
    end

    refresh()
  end,
})

std.fn.observe({ eve.context.flight.dressing_virtcolumn }, function()
  scheduler:schedule({})
end, true)

vim.api.nvim_create_autocmd({
  "WinScrolled",
  "WinResized",
  "TextChanged",
  "TextChangedI",
  "WinEnter",
  "BufWinEnter",
  "BufRead",
  "InsertLeave",
  "InsertEnter",
  "FileType",
  "CursorHold",
}, {
  group = eve.nvim.augroup("virtcolumn_refresh"),
  callback = function()
    scheduler:schedule({})
  end,
})
