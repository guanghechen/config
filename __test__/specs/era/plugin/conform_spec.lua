---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.plugin.conform" ---@type string

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.plugin.conform")

bootstrap.with_yoz(t, require("yoz"))
bootstrap.with_stl(t, { env = { IS_WIN = false } })
bootstrap.with_era(t, { m = { lsp = { fn = require("era.m.lsp.fn") } } })
bootstrap.with_dot(t, {
  path = {
    normalize = function(path)
      return path
    end,
    locate_config_shared_filepath = function(name)
      return name
    end,
  },
})

vim.opt.runtimepath:prepend(vim.fn.stdpath("data") .. "/lazy/conform.nvim")
local conform = require("conform")
local plugin = require("era.plugin.conform")
conform.setup(plugin.opts)

---@param files                         string[]
---@return string
---@return integer
local function project(files)
  local root = vim.fn.tempname() ---@type string
  vim.fn.mkdir(root .. "/src", "p")
  root = assert(vim.uv.fs_realpath(root))
  t:defer(function()
    vim.fn.delete(root, "rf")
  end)
  for _, name in ipairs(files) do
    vim.fn.mkdir(vim.fs.dirname(root .. "/" .. name), "p")
    vim.fn.writefile({ "{}" }, root .. "/" .. name)
  end
  vim.fn.mkdir(root .. "/node_modules/.bin", "p")
  vim.fn.writefile({ "#!/bin/sh", "exit 0" }, root .. "/node_modules/.bin/prettier")
  vim.uv.fs_chmod(root .. "/node_modules/.bin/prettier", 493)

  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_name(bufnr, root .. "/src/main.ts")
  vim.api.nvim_set_option_value("filetype", "typescript", { buf = bufnr })
  return root, bufnr
end

---@param root                          string
---@return nil
local function install_fixture_binary(root)
  vim.fn.writefile({ "#!/bin/sh", "exit 0" }, root .. "/node_modules/.bin/biome")
  vim.uv.fs_chmod(root .. "/node_modules/.bin/biome", 493)
end

t:test("configured projects select only Biome for supported filetypes", function()
  for _, name in ipairs({ "biome.json", "biome.jsonc" }) do
    local root, bufnr = project({ name })
    install_fixture_binary(root)
    for _, ft in ipairs({
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "json",
      "jsonc",
      "css",
      "graphql",
    }) do
      vim.api.nvim_set_option_value("filetype", ft, { buf = bufnr })
      local formatters, lsp = conform.list_formatters_to_run(bufnr)
      t.assert_eq(1, #formatters, ft .. " formatter count")
      t.assert_eq("biome", formatters[1].name, ft .. " formatter")
      t.assert_eq(root .. "/node_modules/.bin/biome", formatters[1].command, "project binary")
      t.assert_false(lsp, "no additional LSP formatting")
    end
  end
end)

t:test("an installed Biome without configuration leaves Prettier selected", function()
  local root, bufnr = project({})
  install_fixture_binary(root)
  local formatters = conform.list_formatters_to_run(bufnr)
  t.assert_eq(1, #formatters, "formatter count")
  t.assert_eq("prettier", formatters[1].name, "Prettier fallback")
end)

t:test("missing Biome executable falls back to Prettier", function()
  local _, bufnr = project({ "biome.json" })
  local executable = vim.fn.executable
  t:patch_table(vim.fn, "executable", function(command)
    if command == "biome" then
      return 0
    end
    return executable(command)
  end)
  local formatters = conform.list_formatters_to_run(bufnr)
  t.assert_eq(1, #formatters, "formatter count")
  t.assert_eq("prettier", formatters[1].name, "Prettier fallback")
end)

t:test("formatter runs from the nearest Biome configuration directory", function()
  local root, bufnr = project({ "biome.json", "src/biome.jsonc" })
  install_fixture_binary(root)
  local formatters = conform.list_formatters_to_run(bufnr)
  t.assert_eq(root .. "/src", formatters[1].cwd, "nested Biome workspace")
end)

t:test("unsupported filetypes retain their existing formatter chain", function()
  local root, bufnr = project({ "biome.json" })
  install_fixture_binary(root)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  local formatters = conform.list_formatters_to_run(bufnr)
  t.assert_eq(2, #formatters, "Markdown formatter count")
  t.assert_eq("prettier", formatters[1].name, "Markdown formatter")
  t.assert_eq("injected", formatters[2].name, "embedded formatter")
end)

t:test("HTML and Svelte keep full-file formatting with and without Biome", function()
  for _, files in ipairs({ {}, { "biome.json" } }) do
    local root, bufnr = project(files)
    install_fixture_binary(root)
    for _, ft in ipairs({ "html", "svelte" }) do
      vim.api.nvim_set_option_value("filetype", ft, { buf = bufnr })
      local formatters = conform.list_formatters_to_run(bufnr)
      t.assert_eq(1, #formatters, ft .. " formatter count")
      t.assert_eq("prettier", formatters[1].name, ft .. " formatter")
    end
  end
end)

t:test("Astro and Vue keep the existing fallback instead of requiring new parsers", function()
  for _, files in ipairs({ {}, { "biome.json" } }) do
    local root, bufnr = project(files)
    install_fixture_binary(root)
    for _, ft in ipairs({ "astro", "vue" }) do
      vim.api.nvim_set_option_value("filetype", ft, { buf = bufnr })
      local formatters = conform.list_formatters_to_run(bufnr)
      t.assert_eq(1, #formatters, ft .. " formatter count")
      t.assert_eq("trim_whitespace", formatters[1].name, ft .. " fallback")
    end
  end
end)

t:test("package-local Biome takes precedence over the ancestor installation", function()
  local root, bufnr = project({ "biome.json" })
  install_fixture_binary(root)
  vim.fn.mkdir(root .. "/src/node_modules/.bin", "p")
  install_fixture_binary(root .. "/src")
  local formatters = conform.list_formatters_to_run(bufnr)
  t.assert_eq(root .. "/src/node_modules/.bin/biome", formatters[1].command, "package binary")
  t.assert_eq(root, formatters[1].cwd, "inherited configuration")
end)

t:test("Biome's disabled response selects Prettier using an empty per-file probe", function()
  local root, bufnr = project({ "biome.jsonc" })
  install_fixture_binary(root)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "export const value =" })
  local calls = 0
  t:patch_table(vim, "system", function(command, opts)
    calls = calls + 1
    t.assert_eq(root .. "/node_modules/.bin/biome", command[1], "project binary")
    t.assert_eq("format", command[2], "probe command")
    t.assert_eq("--stdin-file-path", command[3], "target filename flag")
    t.assert_eq(vim.api.nvim_buf_get_name(bufnr), command[4], "target file for overrides")
    t.assert_eq(root, opts.cwd, "configuration directory")
    t.assert_eq("", opts.stdin, "buffer contents are not parsed by the probe")
    t.assert_true(opts.timeout > 0, "bounded probe")
    return {
      wait = function()
        return {
          code = 1,
          stderr = "The content was not formatted because the formatter is currently disabled.\n",
        }
      end,
    }
  end)

  local formatters = conform.list_formatters_to_run(bufnr)
  t.assert_eq(1, calls, "one probe per selection")
  t.assert_eq(1, #formatters, "formatter count")
  t.assert_eq("prettier", formatters[1].name, "disabled formatter fallback")
end)

t:test("Biome configuration and execution failures do not silently select Prettier", function()
  local root, bufnr = project({ "biome.json" })
  install_fixture_binary(root)
  for _, result in ipairs({
    { code = 1, stderr = "Failed to deserialize the configuration" },
    { code = 124, stderr = "" },
    { code = 1 },
  }) do
    local restore = t:patch_table(vim, "system", function()
      return {
        wait = function()
          return result
        end,
      }
    end)
    local formatters = conform.list_formatters_to_run(bufnr)
    t.assert_eq("biome", formatters[1].name, "original formatter retains error reporting")
    restore()
  end
end)

t:test("Biome availability is re-evaluated after configuration changes", function()
  local root, bufnr = project({ "biome.json" })
  install_fixture_binary(root)
  local enabled = false
  t:patch_table(vim, "system", function()
    return {
      wait = function()
        return enabled and { code = 0, stderr = "" }
          or { code = 1, stderr = "The content was not formatted because the formatter is currently disabled.\n" }
      end,
    }
  end)
  t.assert_eq("prettier", conform.list_formatters_to_run(bufnr)[1].name, "initially disabled")
  enabled = true
  t.assert_eq("biome", conform.list_formatters_to_run(bufnr)[1].name, "enabled after configuration change")
end)

t:test("projects without Biome configuration do not launch an availability probe", function()
  local root, bufnr = project({})
  install_fixture_binary(root)
  t:patch_table(vim, "system", function()
    error("unexpected Biome probe")
  end)
  t.assert_eq("prettier", conform.list_formatters_to_run(bufnr)[1].name, "legacy project formatter")
end)

t:run()
