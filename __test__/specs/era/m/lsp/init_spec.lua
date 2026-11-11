local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_global(t, "stl", {
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
t:patch_table(package.loaded, "era.m.lsp.event", {
  dressing = function() end,
})

local Lsp = require("era.m.lsp")

t:test("dressing: enables LSPs for existing and future buffers without re-editing", function()
  local filetypes = {
    [11] = "lua",
    [12] = "python",
    [13] = "rust",
  } ---@type table<integer, string>
  -- The batches `vim.lsp.enable` received during the current step.
  local batches = {} ---@type string[][]
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
    batches[#batches + 1] = type(names) == "string" and { names } or vim.list_extend({}, names)
    if fail_next_enable then
      fail_next_enable = false
      error("injected enable failure")
    end
  end)
  t:patch_table(vim.lsp.buf, "code_action", vim.lsp.buf.code_action)
  t:patch_table(vim.cmd, "edit", function()
    edits = edits + 1
  end)

  local steps = {} ---@type string[][][]
  -- Ends a step with the batches it enabled.
  ---@return nil
  local function step()
    steps[#steps + 1] = batches
    batches = {}
  end
  -- Runs the FileType callback the latest dressing registered.
  ---@param filetype                    string
  ---@return nil
  local function on_filetype(filetype)
    assert(filetype_callback, "future FileType callback")({ match = filetype })
  end

  Lsp.dressing()
  step()
  on_filetype("templ")
  step()
  on_filetype("typescript")
  step()
  on_filetype("lua")
  Lsp.dressing()
  step()
  on_filetype("eruby")
  step()
  fail_next_enable = true
  local ok = pcall(on_filetype, "yaml.docker-compose")
  step()
  on_filetype("yaml.docker-compose")
  step()
  on_filetype("cs")
  step()

  t.assert_same({
    -- dressing: Lua, then Python with its secondary LSP; the unloaded Rust buffer waits for FileType.
    { { "lua_ls" }, { "basedpyright", "ruff" } },
    -- templ
    { { "html", "tailwindcss" } },
    -- typescript: Tailwind CSS is enabled already.
    { { "vtsls", "tsc", "denols", "eslint", "biome" } },
    -- lua and a repeated dressing enable nothing again.
    {},
    -- eruby
    { { "emmet_language_server" } },
    -- yaml.docker-compose fails and enables nothing, so the next FileType retries the whole batch.
    { { "yamlls", "docker_compose_language_service" } },
    { { "yamlls", "docker_compose_language_service" } },
    -- cs
    { { "roslyn_ls" } },
  }, steps, "the batches each step enables")
  t.assert_false(ok, "enable failure")
  t.assert_eq(0, edits, "buffer re-edit")
end)

t:run()
