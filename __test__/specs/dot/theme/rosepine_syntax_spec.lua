---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.dot.theme.rosepine_syntax_spec" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("dot.theme.rosepine syntax")

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
t:patch_global("dot", require("dot"))

local lines = {
  "local M = {}",
  "--- Build a greeting.",
  "---@param name string",
  "function M.greet(name)",
  "  local count = 1",
  "  if name ~= nil and count > 0 then",
  '    return string.format("hello %s", name)',
  "  end",
  "end",
  'local result = M.greet("world")',
  "return M",
}

---@return integer bufnr
---@return integer winnr
local function open_sample()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  local winnr = vim.api.nvim_open_win(bufnr, true, { split = "below", height = #lines })
  t:defer(function()
    vim.api.nvim_win_close(winnr, true)
  end)
  for name, value in pairs({
    number = false,
    relativenumber = false,
    cursorline = false,
    signcolumn = "no",
    foldcolumn = "0",
    wrap = false,
    winbar = "",
  }) do
    vim.api.nvim_set_option_value(name, value, { win = winnr })
  end
  vim.api.nvim_win_set_cursor(winnr, { #lines, 0 })
  vim.treesitter.start(bufnr, "lua")
  t:defer(function()
    vim.treesitter.stop(bufnr)
  end)
  vim.treesitter.get_parser(bufnr, "lua"):parse()
  vim.api.nvim__redraw({ valid = false, flush = true })
  vim.api.nvim__inspect_cell(1, 0, 0)
  return bufnr, winnr
end

---@param row                           integer
---@param token                         string
---@return integer
local function token_col(row, token)
  return assert(lines[row]:find(token, 1, true)) - 1
end

---@param winnr                         integer
---@param row                           integer
---@param token                         string
---@return table
local function token_cell(winnr, row, token)
  local pos = vim.api.nvim_win_get_position(winnr)
  local cell = vim.api.nvim__inspect_cell(1, pos[1] + row - 1, pos[2] + token_col(row, token))
  t.assert_eq(token:sub(1, 1), cell[1], "visible token " .. token)
  return cell[2]
end

t:test("Lua keywords adapt to transparency and restore their official opaque colors", function()
  local bufnr, winnr = open_sample()
  local keywords = {
    { row = 1, token = "local", capture = "keyword", color = "pine" },
    { row = 4, token = "function", capture = "keyword.function", color = "pine" },
    { row = 6, token = "if", capture = "keyword.conditional", color = "pine" },
    { row = 6, token = "and", capture = "keyword.operator", color = "subtle" },
    { row = 7, token = "return", capture = "keyword.return", color = "pine" },
    { row = 9, token = "end", capture = "keyword.function", color = "pine" },
  }
  for _, point in ipairs(keywords) do
    local captures = vim.treesitter.get_captures_at_pos(bufnr, point.row - 1, token_col(point.row, point.token))
    t.assert_true(
      vim.iter(captures):any(function(capture)
        return capture.capture == point.capture
      end),
      point.token .. " actual Lua capture"
    )
  end
  for _, variant in ipairs({ "main", "moon", "dawn" }) do
    local c = require("dot.theme.scheme.rosepine-" .. variant).palette.rosepine
    dot.context.theme.apply_theme({ theme = "vsc-dark-modern", transparency = false })
    for _, transparency in ipairs({ false, true, false }) do
      dot.context.theme.apply_theme({ theme = "rosepine-" .. variant, transparency = transparency })
      vim.api.nvim__redraw({ valid = false, flush = true })
      for _, point in ipairs(keywords) do
        local attr = token_cell(winnr, point.row, point.token)
        local color = transparency and point.color == "pine" and "iris" or point.color
        t.assert_eq(tonumber(c[color]:sub(2), 16), attr.foreground, variant .. ": " .. point.token)
        t.assert_false(attr.bold or false, point.token .. " default keyword weight")
      end
    end
  end
end)

t:test("LSP follows transparent keyword colors while preserving official semantic roles", function()
  local bufnr, winnr = open_sample()
  local nsnr = vim.api.nvim_create_namespace("")
  t:defer(function()
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  end)
  local tokens = {
    { row = 1, token = "local", kind = "keyword", color = "pine", bold = false },
    { row = 1, token = "M", kind = "namespace", color = "pine" },
    { row = 1, token = "=", kind = "operator", color = "subtle" },
    { row = 4, token = "greet", kind = "function", modifier = "declaration", color = "rose", bold = false },
    { row = 4, token = "name", kind = "variable", modifier = "readonly", color = "iris", italic = true },
    {
      row = 5,
      token = "count",
      kind = "variable",
      modifier = "deprecated",
      color = "text",
      italic = true,
      strikethrough = true,
    },
    { row = 5, token = "1", kind = "number", color = "gold" },
    { row = 7, token = "string", kind = "variable", color = "text", bold = true },
    { row = 7, token = "name", kind = "parameter", color = "iris", italic = true },
    { row = 2, token = "Build", kind = "comment", color = "subtle", italic = true },
    { row = 10, token = "greet", kind = "function", color = "rose", bold = false },
    { row = 10, token = "world", kind = "string", color = "gold" },
  }
  for _, point in ipairs(tokens) do
    local groups = { "@lsp.type." .. point.kind .. ".lua" }
    if point.modifier then
      groups[2] = "@lsp.mod." .. point.modifier .. ".lua"
      groups[3] = "@lsp.typemod." .. point.kind .. "." .. point.modifier .. ".lua"
    end
    for index, group in ipairs(groups) do
      local col = token_col(point.row, point.token)
      -- Match Neovim's semantic-token layers at priorities 125, 126 and 127.
      vim.api.nvim_buf_set_extmark(bufnr, nsnr, point.row - 1, col, {
        end_row = point.row - 1,
        end_col = col + #point.token,
        hl_group = group,
        priority = 124 + index,
      })
    end
  end
  for _, variant in ipairs({ "main", "moon", "dawn" }) do
    local c = require("dot.theme.scheme.rosepine-" .. variant).palette.rosepine
    dot.context.theme.apply_theme({ theme = "vsc-dark-modern", transparency = false })
    for _, transparency in ipairs({ false, true, false }) do
      dot.context.theme.apply_theme({ theme = "rosepine-" .. variant, transparency = transparency })
      vim.api.nvim__redraw({ valid = false, flush = true })
      for _, point in ipairs(tokens) do
        local attr = token_cell(winnr, point.row, point.token)
        local color = transparency and point.kind == "keyword" and point.color == "pine" and "iris" or point.color
        t.assert_eq(tonumber(c[color]:sub(2), 16), attr.foreground, variant .. ": " .. point.token)
        for _, name in ipairs({ "bold", "italic", "strikethrough" }) do
          if point[name] ~= nil then
            t.assert_eq(point[name], attr[name] or false, point.token .. ": " .. name)
          end
        end
      end
    end
  end
end)

t:run()
