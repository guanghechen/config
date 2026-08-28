---@diagnostic disable: undefined-global
--- Test for era.plugin.nvim-treesitter module
--- Run with: nvim -l lua/__test__/era/plugin/nvim-treesitter.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.plugin.nvim-treesitter")

bootstrap.with_stl(t, {
  filetype = {
    NOTEPAD = "notepad",
  },
  nvim = {
    fn = {
      augroup = function()
        return 1
      end,
    },
  },
})
bootstrap.with_dot(t, {
  path = {
    locate_data_filepath = function()
      return "/tmp/treesitter"
    end,
  },
})

local Treesitter = require("era.plugin.nvim-treesitter")

---@param buffers                      table<integer, { valid: boolean, loaded: boolean, filetype: string, indentexpr: string? }>
---@param windows                      table<integer, { valid: boolean, bufnr: integer, foldexpr: string }>
---@param winnrs                       integer[]
---@param start                        fun(bufnr: integer, lang: string)|nil
---@param active_languages             table<integer, string>|nil
---@param parser_available             fun(lang: string): boolean|nil
---@return table<string, fun(event: { buf: integer })>, integer[], integer[], table<integer, table>, table<string, string>
local function setup(buffers, windows, winnrs, start, active_languages, parser_available)
  local callbacks = {} ---@type table<string, fun(event: { buf: integer })>
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
    setup = function() end,
  })
  t:patch_table(vim.api, "nvim_create_user_command", function() end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    events = type(events) == "table" and events or { events }
    for _, event in ipairs(events) do
      callbacks[event] = opts.callback
    end
    return 1
  end)
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
  t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
    if name == "filetype" then
      return buffers[opts.buf].filetype
    end
    if name == "foldexpr" then
      return windows[opts.win].foldexpr
    end
    error("unexpected option read: " .. name)
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function(name, value, opts)
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

  Treesitter.spec.config(nil, Treesitter.spec.opts)
  return callbacks, started, stopped, active, registrations
end

t:test("notepad owns its markdown mapping", function()
  local mappings = {} ---@type table<string, string>
  t:patch_table(vim.treesitter.language, "register", function(lang, filetype)
    mappings[filetype] = lang
  end)
  t:patch_table(package.loaded, "era.m.notepad", nil)

  require("era.m.notepad")

  t.assert_eq("markdown", mappings[stl.filetype.NOTEPAD], "notepad mapping")
end)

t:test("C# filetype uses the c_sharp parser", function()
  local _, _, _, _, registrations = setup({}, {}, {})

  t.assert_eq("c_sharp", registrations.cs, "C# parser mapping")
end)

t:test("existing visible buffer starts on idle exactly once", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local callbacks, started = setup(buffers, windows, { 101 })

  t.assert_eq(0, #started, "startup must only queue visible buffers")
  t.assert_nil(buffers[11].indentexpr, "indent before start")
  t.assert_eq("0", windows[101].foldexpr, "fold before start")

  callbacks.CursorHold({ buf = 11 })
  callbacks.CursorHold({ buf = 11 })

  t.assert_eq(1, #started, "idempotent start")
  t.assert_eq(11, started[1], "started buffer")
  t.assert_eq("v:lua.require'nvim-treesitter'.indentexpr()", buffers[11].indentexpr, "indent after start")
  t.assert_eq("v:lua.vim.treesitter.foldexpr()", windows[101].foldexpr, "fold after start")
end)

t:test("future FileType starts synchronously", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
    [12] = { valid = true, loaded = true, filetype = "lua" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
    [102] = { valid = true, bufnr = 12, foldexpr = "0" },
  }
  local callbacks, started = setup(buffers, windows, { 101 })

  callbacks.FileType({ buf = 12 })

  t.assert_eq(1, #started, "FileType start")
  t.assert_eq(12, started[1], "FileType buffer")
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
  local callbacks, started = setup(buffers, windows, { 101 }, nil, { [11] = "lua" })

  callbacks.CursorHold({ buf = 11 })

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
  local callbacks, started, stopped, active = setup(buffers, windows, { 101 })

  callbacks.CursorHold({ buf = 11 })
  buffers[11].filetype = "rust"
  callbacks.FileType({ buf = 11 })

  t.assert_eq(2, #started, "language starts")
  t.assert_eq(1, #stopped, "old language stop")
  t.assert_eq("rust", active[11].tree:lang(), "active language")
end)

t:test("hidden buffer waits until it enters a window", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
    [12] = { valid = true, loaded = true, filetype = "lua" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local winnrs = { 101 }
  local callbacks, started = setup(buffers, windows, winnrs)

  callbacks.CursorHold({ buf = 12 })
  t.assert_eq(0, #started, "hidden buffer")

  windows[102] = { valid = true, bufnr = 12, foldexpr = "0" }
  winnrs[#winnrs + 1] = 102
  callbacks.BufWinEnter({ buf = 12 })
  callbacks.InsertEnter({ buf = 12 })

  t.assert_eq(1, #started, "visible hidden buffer")
  t.assert_eq(12, started[1], "visible hidden buffer number")
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
  local callbacks, started = setup(buffers, windows, { 101, 102, 103 })

  callbacks.FileType({ buf = 11 })
  callbacks.FileType({ buf = 12 })
  callbacks.FileType({ buf = 13 })
  callbacks.CursorHold({ buf = 11 })
  callbacks.CursorHold({ buf = 12 })
  callbacks.CursorHold({ buf = 13 })

  t.assert_eq(0, #started, "ineligible buffers")
end)

t:test("buffer becoming ineligible drops its pending start", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local callbacks, started = setup(buffers, windows, { 101 })

  buffers[11].filetype = "bigfile"
  callbacks.CursorHold({ buf = 11 })
  buffers[11].filetype = "typescript"
  callbacks.CursorHold({ buf = 11 })

  t.assert_eq(0, #started, "stale pending start")
end)

t:test("start failure does not write options", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local callbacks = setup(buffers, windows, { 101 }, function()
    error("missing parser")
  end)

  local ok = pcall(callbacks.CursorHold, { buf = 11 })

  t.assert_false(ok, "start error propagation")
  t.assert_nil(buffers[11].indentexpr, "indent after failed start")
  t.assert_eq("0", windows[101].foldexpr, "fold after failed start")
end)

t:test("BufUnload permits the same buffer to restart", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local callbacks, started, _, active = setup(buffers, windows, { 101 })

  callbacks.CursorHold({ buf = 11 })
  callbacks.BufUnload({ buf = 11 })
  active[11] = nil
  windows[101].foldexpr = "0"
  buffers[11].indentexpr = nil
  callbacks.BufWinEnter({ buf = 11 })
  callbacks.CursorHold({ buf = 11 })

  t.assert_eq(2, #started, "reloaded buffer start")
end)

t:test("delayed start preserves LSP folding", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "typescript" },
  }
  local windows = {
    [101] = { valid = true, bufnr = 11, foldexpr = "v:lua.vim.lsp.foldexpr()" },
    [102] = { valid = true, bufnr = 11, foldexpr = "0" },
  }
  local callbacks = setup(buffers, windows, { 101, 102 })

  callbacks.CursorHold({ buf = 11 })

  t.assert_eq("v:lua.vim.lsp.foldexpr()", windows[101].foldexpr, "LSP fold")
  t.assert_eq("v:lua.vim.treesitter.foldexpr()", windows[102].foldexpr, "Treesitter fold")
end)

t:run()
