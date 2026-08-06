---@diagnostic disable: undefined-global
--- Test for era.m.lsp module
--- Run with: nvim -l lua/__test__/era/m/lsp/init.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.lsp")

bootstrap.with_stl(t, {
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

t:patch_table(package.loaded, "era.m.lsp.action", {
  code_action = function() end,
})
t:patch_table(package.loaded, "era.m.lsp.diagnostic", {
  setup = function() end,
})
local lsp_event = {
  before_init = function() end,
  dressing = function() end,
  get_capabilities = vim.lsp.protocol.make_client_capabilities,
  on_attach = function() end,
  on_init = function() end,
}
t:patch_table(package.loaded, "era.m.lsp.event", lsp_event)
bootstrap.with_era(t, {
  m = {
    lsp = {
      event = lsp_event,
    },
  },
})

local Lsp = require("era.m.lsp")
local RoslynConfig = dofile("lsp/roslyn_ls.lua")

local function fake_roslyn_client()
  return {
    id = 1,
    offset_encoding = "utf-16",
  }
end

t:test("dressing: enables LSPs for existing and future buffers without re-editing", function()
  local filetypes = {
    [11] = "lua",
    [12] = "python",
    [13] = "rust",
  } ---@type table<integer, string>
  local enabled = {} ---@type table<string, integer>
  local enable_batches = {} ---@type string[][]
  local filetype_callback = nil ---@type fun(args: { match: string })|nil
  local fail_next_enable = false ---@type boolean
  local edits = 0 ---@type integer

  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    if event == "FileType" then
      filetype_callback = opts.callback
    end
    return 1
  end)
  t:patch_table(vim.api, "nvim_list_bufs", function()
    return { 11, 12, 13, 14 }
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return bufnr ~= 14
  end)
  t:patch_table(vim.api, "nvim_buf_is_loaded", function(bufnr)
    return bufnr ~= 13
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
    t.assert_eq("filetype", name, "buffer option")
    return filetypes[opts.buf] or ""
  end)
  t:patch_table(vim.lsp, "enable", function(names)
    if type(names) == "string" then
      names = { names }
    end

    local batch = {} ---@type string[]
    for _, name in ipairs(names) do
      batch[#batch + 1] = name
    end
    enable_batches[#enable_batches + 1] = batch

    if fail_next_enable then
      fail_next_enable = false
      error("injected enable failure")
    end

    for _, name in ipairs(batch) do
      enabled[name] = (enabled[name] or 0) + 1
    end
  end)
  t:patch_table(vim.lsp.buf, "code_action", vim.lsp.buf.code_action)
  t:patch_table(vim.cmd, "edit", function()
    edits = edits + 1
  end)

  Lsp.dressing()

  t.assert_eq(1, enabled.lua_ls, "existing Lua buffer")
  t.assert_eq(1, enabled.basedpyright, "existing Python buffer")
  t.assert_eq(1, enabled.ruff, "existing Python buffer secondary LSP")
  t.assert_nil(enabled.rust_analyzer, "unloaded buffer")
  t.assert_true(filetype_callback ~= nil, "future FileType callback")
  t.assert_eq(2, #enable_batches, "existing buffer batches")
  t.assert_eq(1, #enable_batches[1], "Lua batch size")
  t.assert_eq("lua_ls", enable_batches[1][1], "Lua batch")
  t.assert_eq(2, #enable_batches[2], "Python batch size")
  t.assert_eq("basedpyright", enable_batches[2][1], "Python primary LSP")
  t.assert_eq("ruff", enable_batches[2][2], "Python secondary LSP")

  filetype_callback({ match = "templ" })
  t.assert_eq(1, enabled.html, "direct Templ buffer")
  t.assert_eq(1, enabled.tailwindcss, "direct Templ Tailwind LSP")
  t.assert_eq(3, #enable_batches, "Templ batch")
  t.assert_eq(2, #enable_batches[3], "Templ batch size")
  t.assert_eq("html", enable_batches[3][1], "Templ HTML LSP")
  t.assert_eq("tailwindcss", enable_batches[3][2], "Templ Tailwind LSP")

  filetype_callback({ match = "typescript" })
  t.assert_eq(1, enabled.vtsls, "future TypeScript buffer")
  t.assert_eq(1, enabled.denols, "future Deno buffer")
  t.assert_eq(1, enabled.eslint, "future TypeScript secondary LSP")
  t.assert_eq(1, enabled.tailwindcss, "future TypeScript secondary LSP")
  t.assert_eq(4, #enable_batches, "future buffer batch")
  t.assert_eq(3, #enable_batches[4], "TypeScript batch size")
  t.assert_eq("vtsls", enable_batches[4][1], "TypeScript primary LSP")
  t.assert_eq("denols", enable_batches[4][2], "Deno LSP")
  t.assert_eq("eslint", enable_batches[4][3], "TypeScript secondary LSP")

  filetype_callback({ match = "lua" })
  Lsp.dressing()

  t.assert_eq(1, enabled.lua_ls, "repeated enable")
  t.assert_eq(4, #enable_batches, "repeated enable batches")
  t.assert_eq(0, edits, "buffer re-edit")

  filetype_callback({ match = "eruby" })
  t.assert_eq(1, enabled.emmet_language_server, "direct Eruby buffer")
  t.assert_eq(5, #enable_batches, "Eruby batch")
  t.assert_eq("emmet_language_server", enable_batches[5][1], "Eruby LSP")

  fail_next_enable = true
  local ok = pcall(filetype_callback, { match = "yaml.docker-compose" })

  t.assert_false(ok, "enable failure")
  t.assert_nil(enabled.yamlls, "failed primary LSP")
  t.assert_nil(enabled.docker_compose_language_service, "failed secondary LSP")
  t.assert_eq(6, #enable_batches, "failed batch")
  t.assert_eq(2, #enable_batches[6], "failed batch size")
  t.assert_eq("yamlls", enable_batches[6][1], "failed primary LSP batch")
  t.assert_eq("docker_compose_language_service", enable_batches[6][2], "failed secondary LSP batch")

  filetype_callback({ match = "yaml.docker-compose" })

  t.assert_eq(1, enabled.yamlls, "retried primary LSP")
  t.assert_eq(1, enabled.docker_compose_language_service, "retried secondary LSP")
  t.assert_eq(7, #enable_batches, "retried batch")
  t.assert_eq("yamlls", enable_batches[7][1], "retried primary LSP batch")
  t.assert_eq("docker_compose_language_service", enable_batches[7][2], "retried secondary LSP batch")

  filetype_callback({ match = "cs" })
  t.assert_eq(1, enabled.roslyn_ls, "future C# buffer")
  t.assert_eq(8, #enable_batches, "C# batch")
  t.assert_eq(1, #enable_batches[8], "C# batch size")
  t.assert_eq("roslyn_ls", enable_batches[8][1], "C# primary LSP")
end)

t:test("roslyn completion: rejects edits targeting another buffer", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_name(bufnr, "/tmp/roslyn-invalid-completion.cs")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "fo" })

  local warnings = 0
  t:patch_table(stl.reporter, "warn", function()
    warnings = warnings + 1
  end)
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

  t.assert_eq(1, warnings, "invalid edit warning")
  t.assert_eq("fo", vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1], "unchanged buffer")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("roslyn completion: restores UTF-16 cursor offset after a plain edit", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_name(bufnr, "/tmp/roslyn-offset-completion.cs")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "x" })
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
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("roslyn completion: expands snippet edits instead of inserting placeholders", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_name(bufnr, "/tmp/roslyn-snippet-completion.cs")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "  fo" })

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

  local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  t.assert_true(text:find("for %(int i = 0; i < length; i%+%+%)") ~= nil, "expanded snippet text")
  t.assert_true(text:find("%$[0-9{]") == nil, "no literal placeholders")
  t.assert_true(vim.snippet.active(), "active snippet session")
  vim.snippet.stop()
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
