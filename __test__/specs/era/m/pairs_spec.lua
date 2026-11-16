require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

--- The delimiter columns of each row of the buffer's document.
---@param bufnr                         integer
---@return integer[][]
local function columns(bufnr)
  local document = assert(era.m.pairs.document(bufnr))
  local rows = {} ---@type integer[][]
  for row = 0, document:line_count() - 1 do
    rows[row + 1] = vim.tbl_map(function(token)
      return token.col
    end, document:tokens(row))
  end
  return rows
end

t:test("an emptied buffer keeps a document of its one empty line", function()
  local bufnr = t:buffer({ "f(x)", "g(y)" }, { filetype = "lua" })
  t.assert_same({ { 1, 3 }, { 1, 3 } }, columns(bufnr))
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  t.assert_eq(1, assert(era.m.pairs.document(bufnr)):line_count())
  vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { "h[z]" })
  t.assert_same({ {}, { 1, 3 } }, columns(bufnr))
end)

t:test("a filetype change rebuilds the document under a new revision", function()
  local bufnr = t:buffer({ "x = 'f(' (" }, { filetype = "c" })
  local c = assert(era.m.pairs.document(bufnr))
  vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
  local lua = assert(era.m.pairs.document(bufnr))
  t.assert_true(lua ~= c)
  t.assert_true(lua:revision() > c:revision())
  -- C reads `'f('` as a character literal attempt and Lua as a string: the documents tokenize differently.
  t.assert_same({ { 4, 7, 9 } }, columns(bufnr))
end)

t:test("a buffer without a pairs language has no document", function()
  t.assert_nil(era.m.pairs.document(t:buffer({ "f(x)" }, { filetype = "help" })))
  t.assert_nil(era.m.pairs.document(t:buffer({ "f(x)" }, { filetype = "" })))
end)

t:run()
