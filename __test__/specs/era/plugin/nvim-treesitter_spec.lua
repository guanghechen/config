local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

-- The installed parsers' directory; its Lua injections, like nvim-treesitter's, inject luadoc.
local install_dir = t:tempdir() ---@type string
vim.fn.mkdir(install_dir .. "/queries/lua", "p")
vim.fn.writefile(
  { '(comment content: (_) @injection.content (#set! injection.language "luadoc"))' },
  install_dir .. "/queries/lua/injections.scm"
)

bootstrap.with_global(t, "stl", {
  nvim = {
    fn = {
      augroup = function()
        return 1
      end,
    },
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    locate_config_filepath = function(filename)
      return filename
    end,
    locate_data_filepath = function()
      return install_dir
    end,
  },
})

local Treesitter = require("era.plugin.nvim-treesitter")

t:test("treesitter does not eagerly own textobjects", function()
  t.assert_nil(Treesitter.spec.dependencies, "dependencies")
end)

---@param query                         vim.treesitter.Query
---@return table<string, true>
local function injected_languages(query)
  local languages = {} ---@type table<string, true>
  for _, pattern in pairs(query.info.patterns) do
    for _, step in ipairs(pattern) do
      if step[1] == "set!" and step[2] == "injection.language" then
        languages[step[3]] = true
      end
    end
  end
  return languages
end

t:test("Lua injections leave doc comments to LuaLS and keep the other languages", function()
  local languages = injected_languages(assert(vim.treesitter.query.get("lua", "injections")))
  t.assert_nil(languages.luadoc, "luadoc")
  t.assert_true(languages.vim and languages.c and languages.luap and true or false, "vim, c and luap")

  -- The query is set explicitly, so a runtimepath change keeps it.
  vim.opt.runtimepath:append(t:tempdir())
  t.assert_nil(
    injected_languages(assert(vim.treesitter.query.get("lua", "injections"))).luadoc,
    "luadoc after a change"
  )
end)

local loading = false ---@type boolean True while the plugin config runs.

---@param buffers                      table<integer, { valid: boolean, loaded: boolean, filetype: string, indentexpr: string? }>
---@param windows                      table<integer, { valid: boolean, bufnr: integer, foldexpr: string }>
---@param winnrs                       integer[]
---@param start                        fun(bufnr: integer, lang: string)|nil
---@param active_languages             table<integer, string>|nil
---@param parser_available             fun(lang: string): boolean|nil
---@return table<string, fun(event: { buf: integer })>, integer[], integer[], table<integer, table>, table<string, string>
local function setup(buffers, windows, winnrs, start, active_languages, parser_available)
  local started = {} ---@type integer[]
  local stopped = {} ---@type integer[]
  local active = {} ---@type table<integer, table>
  local registrations = {} ---@type table<string, string>

  ---@param lang                        string
  ---@return table
  local function highlighter(lang)
    return {
      tree = {
        lang = function()
          return lang
        end,
      },
    }
  end

  for bufnr, lang in pairs(active_languages or {}) do
    active[bufnr] = highlighter(lang)
  end

  t:patch_table(package.loaded, "nvim-treesitter", {
    -- As nvim-treesitter does, whatever the runtimepath holds already.
    setup = function(opts)
      vim.o.runtimepath = opts.install_dir .. "," .. vim.o.runtimepath
    end,
  })
  t:patch_table(vim.api, "nvim_create_user_command", function() end)
  local callbacks = bootstrap.with_autocmds(t)
  t:patch_table(vim.api, "nvim_list_wins", function()
    return winnrs
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return windows[winnr] ~= nil and windows[winnr].valid
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function(winnr)
    return windows[winnr].bufnr
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return buffers[bufnr] ~= nil and buffers[bufnr].valid
  end)
  t:patch_table(vim.api, "nvim_buf_is_loaded", function(bufnr)
    return buffers[bufnr] ~= nil and buffers[bufnr].loaded
  end)
  -- The runtimepath is real: loading the plugin puts the installed parsers on it.
  local get_option, set_option = vim.api.nvim_get_option_value, vim.api.nvim_set_option_value
  t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
    if name == "filetype" then
      return buffers[opts.buf].filetype
    end
    if name == "foldexpr" then
      return windows[opts.win].foldexpr
    end
    if name == "runtimepath" then
      return get_option(name, opts)
    end
    error("unexpected option read: " .. name)
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function(name, value, opts)
    if name == "runtimepath" then
      return set_option(name, value, opts)
    end
    if name == "indentexpr" then
      buffers[opts.buf].indentexpr = value
      return
    end
    if name == "foldexpr" then
      windows[opts.win].foldexpr = value
      return
    end
    error("unexpected option write: " .. name)
  end)
  t:patch_table(vim.treesitter.language, "register", function(lang, filetype)
    registrations[filetype] = lang
  end)
  t:patch_table(vim.treesitter.language, "add", parser_available or function()
    return true
  end)
  t:patch_table(vim.treesitter.highlighter, "active", active)
  -- Like the memoized `query.get`, it has a cache for a runtimepath change to clear.
  t:patch_table(
    vim.treesitter.query,
    "get",
    setmetatable({ clear = function() end }, {
      __call = function(_, _, name)
        t.assert_eq("folds", name, "fold availability query")
        return {}
      end,
    })
  )
  t:patch_table(vim.treesitter, "start", function(bufnr, lang)
    started[#started + 1] = bufnr
    if start then
      start(bufnr, lang)
    end
    active[bufnr] = highlighter(lang)
  end)
  t:patch_table(vim.treesitter, "stop", function(bufnr)
    stopped[#stopped + 1] = bufnr
    active[bufnr] = nil
  end)
  local schedule = bootstrap.with_schedule(t)

  loading = true
  ---@diagnostic disable-next-line: param-type-mismatch
  Treesitter.spec.config(nil, Treesitter.spec.opts)
  loading = false
  -- Neovim runs scheduled callbacks on a later tick, after the plugin loader has returned.
  schedule.drain()
  return callbacks, started, stopped, active, registrations
end

-- First of the cases that load the plugin, which changes the runtimepath.
t:test("the installed parsers are on the runtimepath once from startup on", function()
  ---@return integer
  local function entries()
    return #vim.tbl_filter(function(path)
      return path == install_dir
    end, vim.opt.runtimepath:get())
  end

  -- This file requires the spec as the plugin list does at startup, long before the plugin loads.
  t.assert_eq(1, entries(), "before the plugin loads")
  ---@diagnostic disable-next-line: missing-parameter
  setup({}, {}, {})
  t.assert_eq(1, entries(), "once the plugin has loaded")
end)

t:test("C# filetype uses the c_sharp parser", function()
  ---@diagnostic disable-next-line: missing-parameter
  local _, _, _, _, registrations = setup({}, {}, {})

  t.assert_eq("c_sharp", registrations.cs, "C# parser mapping")
end)

t:test("buffers already in windows start once the plugin has loaded", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
    [12] = { valid = true, loaded = true, filetype = "rust" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
    [102] = { valid = true, bufnr = 12, foldexpr = "0" },
  }
  local during_load = {} ---@type boolean[]
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks, started = setup(buffers, windows, { 101, 102 }, function()
    during_load[#during_load + 1] = loading
  end)

  t.assert_same({ 11, 12 }, started, "every visible buffer starts, not only the current one")
  t.assert_same({ false, false }, during_load, "no start runs inside the plugin load")
  t.assert_eq("v:lua.require'nvim-treesitter'.indentexpr()", buffers[11].indentexpr, "indent after start")
  t.assert_eq("v:lua.vim.treesitter.foldexpr()", windows[101].foldexpr, "fold after start")
  t.assert_eq("v:lua.vim.treesitter.foldexpr()", windows[102].foldexpr, "fold in the other window")

  callbacks.BufWinEnter({ buf = 11 })

  t.assert_eq(2, #started, "entering a window again keeps the running parser")
end)

t:test("future FileType starts synchronously", function()
  local buffers = {
    [12] = { valid = true, loaded = true, filetype = "lua" },
  }
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks, started = setup(buffers, {}, {})

  callbacks.FileType({ buf = 12 })

  t.assert_eq(1, #started, "FileType start")
  t.assert_eq(12, started[1], "FileType buffer")
end)

t:test("JSONC and JSX filetypes start their parsers", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "jsonc" },
    [12] = { valid = true, loaded = true, filetype = "javascriptreact" },
  }
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks, started, _, _, registrations = setup(buffers, {}, {})

  callbacks.FileType({ buf = 11 })
  callbacks.FileType({ buf = 12 })

  t.assert_same({ 11, 12 }, started, "started buffers")
  t.assert_eq("json", registrations.jsonc, "JSONC parser mapping")
end)

t:test("missing parser skips FileType activation", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local callbacks, started = setup(buffers, windows, { 101 }, nil, nil, function()
    return false
  end)

  local ok = pcall(callbacks.FileType, { buf = 11 })

  t.assert_true(ok, "missing parser must not fail FileType")
  t.assert_eq(0, #started, "missing parser start")
  t.assert_nil(buffers[11].indentexpr, "indent without parser")
  t.assert_eq("0", windows[101].foldexpr, "fold without parser")
end)

t:test("existing matching highlighter is reused", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "lua" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks, started = setup(buffers, windows, { 101 }, nil, { [11] = "lua" })

  callbacks.BufWinEnter({ buf = 11 })

  t.assert_eq(0, #started, "native highlighter start")
  t.assert_eq("v:lua.require'nvim-treesitter'.indentexpr()", buffers[11].indentexpr, "indent")
  t.assert_eq("v:lua.vim.treesitter.foldexpr()", windows[101].foldexpr, "fold")
end)

t:test("FileType restarts a mismatched parser", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks, started, stopped, active = setup(buffers, windows, { 101 })

  buffers[11].filetype = "rust"
  callbacks.FileType({ buf = 11 })

  t.assert_eq(2, #started, "language starts")
  t.assert_eq(1, #stopped, "old language stop")
  t.assert_eq("rust", active[11].tree:lang(), "active language")
end)

t:test("a hidden buffer starts when it enters a window", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
    [12] = { valid = true, loaded = true, filetype = "lua" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local winnrs = { 101 }
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks, started = setup(buffers, windows, winnrs)

  t.assert_same({ 11 }, started, "only the visible buffer starts with the plugin")

  windows[102] = { valid = true, bufnr = 12, foldexpr = "0" }
  winnrs[#winnrs + 1] = 102
  callbacks.BufWinEnter({ buf = 12 })

  t.assert_same({ 11, 12 }, started, "the hidden buffer starts on entering a window")
  t.assert_eq("v:lua.vim.treesitter.foldexpr()", windows[102].foldexpr, "fold in its window")
end)

t:test("ineligible buffers never start", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "bigfile" },
    [12] = { valid = false, loaded = true, filetype = "typescript" },
    [13] = { valid = true, loaded = false, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
    [102] = { valid = true, bufnr = 12, foldexpr = "0" },
    [103] = { valid = true, bufnr = 13, foldexpr = "0" },
  }
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks, started = setup(buffers, windows, { 101, 102, 103 })

  callbacks.FileType({ buf = 11 })
  callbacks.FileType({ buf = 12 })
  callbacks.FileType({ buf = 13 })
  callbacks.BufWinEnter({ buf = 11 })
  callbacks.BufWinEnter({ buf = 12 })
  callbacks.BufWinEnter({ buf = 13 })

  t.assert_eq(0, #started, "ineligible buffers")
end)

t:test("a failed start is raised after the plugin has loaded and writes no options", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local during_load = nil ---@type boolean|nil
  ---@diagnostic disable-next-line: missing-parameter
  local ok, err = pcall(setup, buffers, windows, { 101 }, function()
    during_load = loading
    error("missing parser")
  end)

  t.assert_false(ok, "start error propagation")
  t.assert_true(tostring(err):find("missing parser", 1, true) ~= nil, "the start error itself: " .. tostring(err))
  t.assert_false(during_load, "the plugin load has finished, so the start cannot fail it")
  t.assert_nil(buffers[11].indentexpr, "indent after failed start")
  t.assert_eq("0", windows[101].foldexpr, "fold after failed start")
end)

t:test("parser activation preserves native LSP folding", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "v:lua.vim.lsp.foldexpr()" },
    [102] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  ---@diagnostic disable-next-line: missing-parameter
  setup(buffers, windows, { 101, 102 })

  t.assert_eq("v:lua.vim.lsp.foldexpr()", windows[101].foldexpr, "LSP retains ownership")
  t.assert_eq("v:lua.vim.treesitter.foldexpr()", windows[102].foldexpr, "Treesitter fold")
end)

t:test("a parser without a folds query preserves the unconfigured expression", function()
  local buffers = { [11] = { valid = true, loaded = true, filetype = "typescript" } }
  local windows = {} ---@type table<integer, { valid: boolean, bufnr: integer, foldexpr: string }>
  local winnrs = {} ---@type integer[]
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks = setup(buffers, windows, winnrs)
  t:patch_table(vim.treesitter.query, "get", function()
    return nil
  end)
  windows[101] = { valid = true, bufnr = 11, foldexpr = "0" }
  winnrs[1] = 101
  callbacks.BufWinEnter({ buf = 11 })
  t.assert_eq("0", windows[101].foldexpr, "no unusable Tree-sitter expression installed")
end)

t:test("repeated configuration does not rewrite the Tree-sitter expression", function()
  local buffers = { [11] = { valid = true, loaded = true, filetype = "typescript" } }
  local windows = { [101] = { valid = true, bufnr = 11, foldexpr = "v:lua.vim.treesitter.foldexpr()" } }
  ---@diagnostic disable-next-line: missing-parameter
  local callbacks = setup(buffers, windows, { 101 })
  local writes = 0 ---@type integer
  local set_option = vim.api.nvim_set_option_value
  t:patch_table(vim.api, "nvim_set_option_value", function(name, ...)
    if name == "foldexpr" then
      writes = writes + 1
    end
    return set_option(name, ...)
  end)
  callbacks.BufWinEnter({ buf = 11 })
  t.assert_eq(0, writes, "no redundant foldexpr writes")
end)

t:run()
