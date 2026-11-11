local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_global(t, "stl", {
  reporter = {
    debug = function() end,
    error = function() end,
    info = function() end,
    warn = function() end,
  },
  nvim = {
    fn = {
      augroup = function()
        return 1
      end,
    },
  },
})
bootstrap.with_global(t, "era", {
  m = {
    lsp = {
      event = {
        get_capabilities = vim.lsp.protocol.make_client_capabilities,
        on_attach = function() end,
      },
    },
  },
})

local RoslynConfig = dofile("lsp/roslyn_ls.lua")

local function fake_roslyn_client()
  return {
    id = 1,
    offset_encoding = "utf-16",
  }
end

t:test("roslyn completion: rejects edits targeting another buffer", function()
  local bufnr = t:buffer({ "fo" }, { name = "/tmp/roslyn-invalid-completion.cs", current = true })

  local reports = bootstrap.with_reporter(t)
  t:patch_table(vim.lsp, "get_client_by_id", function()
    return fake_roslyn_client()
  end)

  RoslynConfig.commands["roslyn.client.completionComplexEdit"]({
    arguments = {
      { uri = vim.uri_from_fname("/tmp/another-buffer.cs") },
      {
        range = {
          start = { line = 0, character = 0 },
          ["end"] = { line = 0, character = 2 },
        },
        newText = "for",
      },
      false,
      -1,
    },
  }, { client_id = 1, bufnr = bufnr })

  t.assert_eq(1, #reports.warn, "invalid edit warning")
  t.assert_eq("fo", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1], "unchanged buffer")
end)

t:test("roslyn completion: restores UTF-16 cursor offset after a plain edit", function()
  local bufnr = t:buffer({ "x" }, { name = "/tmp/roslyn-offset-completion.cs", current = true })
  vim.api.nvim_set_option_value("fileformat", "dos", { buf = bufnr })

  t:patch_table(vim.lsp, "get_client_by_id", function()
    return fake_roslyn_client()
  end)

  RoslynConfig.commands["roslyn.client.completionComplexEdit"]({
    arguments = {
      { uri = vim.uri_from_bufnr(bufnr) },
      {
        range = {
          start = { line = 0, character = 0 },
          ["end"] = { line = 0, character = 1 },
        },
        newText = "😀x\r\ntail",
      },
      false,
      7,
    },
  }, { client_id = 1, bufnr = bufnr })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  t.assert_eq("😀x", lines[1], "first edited line")
  t.assert_eq("tail", lines[2], "second edited line")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(0)[1], "cursor line")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(0)[2], "cursor byte column")
end)

t:test("roslyn completion: expands snippet edits instead of inserting placeholders", function()
  local bufnr = t:buffer({ "  fo" }, { name = "/tmp/roslyn-snippet-completion.cs", current = true })

  t:patch_table(vim.lsp, "get_client_by_id", function()
    return fake_roslyn_client()
  end)

  RoslynConfig.commands["roslyn.client.completionComplexEdit"]({
    arguments = {
      { uri = vim.uri_from_bufnr(bufnr) },
      {
        range = {
          start = { line = 0, character = 2 },
          ["end"] = { line = 0, character = 4 },
        },
        newText = "for (${1:int i = 0}; ${2:i < length}; ${3:i++}) {\n\t$0\n}",
      },
      true,
      -1,
    },
  }, { client_id = 1, bufnr = bufnr })
  t:defer(function()
    vim.snippet.stop()
  end)

  local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  t.assert_true(text:find("for %(int i = 0; i < length; i%+%+%)") ~= nil, "expanded snippet text")
  t.assert_true(text:find("%$[0-9{]") == nil, "no literal placeholders")
  t.assert_true(vim.snippet.active(), "active snippet session")
end)

t:run()
