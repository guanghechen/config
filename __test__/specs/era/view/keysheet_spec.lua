require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Keysheet = require("era.view.keysheet")

t:test("a buffer keysheet names keys as mapped and drops scopes, which-key prefixes and no-ops", function()
  local bufnr = t:buffer()
  ---@param modes                       string|string[]
  ---@param lhs                         string
  ---@param desc                        string
  ---@return nil
  local function map(modes, lhs, desc)
    vim.keymap.set(modes, lhs, function() end, { buf = bufnr, desc = desc })
  end
  map({ "n", "x" }, "oa", "picker#result: add to ai")
  map("n", "R", "Git Files: refresh")
  map("n", "[i", "Treeview parent")
  map("n", "t7", "era.fn.find_files: era.fn.find_files: toggle exclude")
  map("n", "p1", "diffview(commits): Layout 1: commits top")
  map("n", "g", "wk-trigger")
  map("n", "<Tab>", "searcher#result: noop")
  map("n", "<C-j>", "picker#finder: focus next item")
  map("n", "<C-i>", "picker#finder: history backward")

  local entries = {} ---@type string[]
  for _, keymap in ipairs(Keysheet.for_buffer({ bufnr = bufnr, title = "Git Files" })._sections[1].keymaps) do
    entries[#entries + 1] = keymap.key .. " " .. table.concat(keymap.modes, ",") .. " " .. keymap.desc
  end
  t.assert_same({
    "<C-I> n history backward",
    "<C-J> n focus next item",
    "R n refresh",
    "[i n parent",
    "oa n,x add to ai",
    "p1 n Layout 1: commits top",
    "t7 n toggle exclude",
  }, entries)
end)

t:test("a keysheet opens above the floating window it is asked from", function()
  t:window(t:buffer(), { relative = "editor", row = 0, col = 0, width = 20, height = 3, zindex = 51 }, true)
  local keymaps = { { modes = { "n" }, key = "q", desc = "close", callback = "" } } ---@type stl.t.IKeymap[]
  local sheet = Keysheet.new({ sections = { { title = "Current pane", keymaps = keymaps } } })
  t:defer(function()
    sheet:dispose()
  end)
  sheet:open()
  t.assert_true(vim.api.nvim_win_get_config(assert(sheet._winnr)).zindex > 51, "above a picker window")
end)

t:test("a keysheet opened from Insert mode takes its keys in Normal mode", function()
  local ui = require("__test__.support.ui").open(t, { width = 80, height = 24, runtime = "ark" })
  ui:lua([[
    vim.keymap.set("i", "<F5>", function()
      require("era.view.keysheet").new({ sections = {} }):open()
    end)
  ]])
  ui:rpc("nvim_input", "i<F5>")
  ui:wait_lua("return vim.bo.filetype == 'board' and vim.api.nvim_get_mode().mode == 'n'", 5000, "Normal mode sheet")
  ui:rpc("nvim_input", "q")
  ui:wait_lua("return vim.bo.filetype ~= 'board'", 5000, "q closes the sheet")
end)

t:test("a buffer keysheet lists the global mappings the buffer leaves in effect after its own, scopes kept", function()
  local bufnr = t:buffer()
  local globals = { "zxa", "zxb", "zxc", "zxd", "zxe", "zxf" } ---@type string[]
  for _, lhs in ipairs(globals) do
    vim.keymap.set("n", lhs, function() end, { desc = "probe: global " .. lhs })
  end
  t:defer(function()
    for _, lhs in ipairs(globals) do
      pcall(vim.keymap.del, "n", lhs)
    end
  end)
  ---@param lhs                         string
  ---@param desc                        string
  ---@param nowait                      ?boolean
  ---@return nil
  local function map(lhs, desc, nowait)
    vim.keymap.set("n", lhs, function() end, { buf = bufnr, desc = desc, nowait = nowait })
  end
  map("zxb", "probe: own zxb")
  map("zxc", "noop")
  map("zxd", "probe: waits", false)
  map("zx", "wk-trigger", true)

  ---Each global entry under a key starting with `prefix`, as "group key desc".
  ---@param sheet                     era.view.Keysheet
  ---@param prefix                    string
  ---@return string[]
  local function globals_under(sheet, prefix)
    local found = {} ---@type string[]
    for _, group in ipairs(sheet._more[1].groups) do
      for _, keymap in ipairs(group.keymaps) do
        if vim.startswith(keymap.key, prefix) then
          found[#found + 1] = group.title .. " " .. keymap.key .. " " .. keymap.desc
        end
      end
    end
    return found
  end
  local sheet = Keysheet.for_buffer({ bufnr = bufnr })
  t.assert_same(
    {
      "probe zxa global zxa",
      "probe zxe global zxe",
      "probe zxf global zxf",
    },
    globals_under(sheet, "zx"),
    "a key the buffer maps itself, even to a no-op, keeps the global one from taking effect"
  )
  t.assert_same({ "Current pane", "Global" }, { sheet._sections[1].title, sheet._more[1].title })

  map("zxe", "probe: own zxe")
  vim.keymap.set("n", "zxf", function() end, { buf = bufnr, desc = "probe: own zxf", nowait = true })
  vim.keymap.set({ "n", "x" }, "z", function() end, { buf = bufnr, desc = "probe: nowait prefix", nowait = true })
  t.assert_same(
    {},
    globals_under(Keysheet.for_buffer({ bufnr = bufnr }), "z"),
    "a nowait mapping of the start of the keys keeps every global one under it from effect"
  )
end)

t:test("a buffer keysheet leaves out its own mappings not in effect, which still keep the global ones out", function()
  local bufnr = t:buffer()
  vim.keymap.set("n", "zya", function() end, { desc = "probe: global zya" })
  t:defer(function()
    pcall(vim.keymap.del, "n", "zya")
  end)
  vim.keymap.set("n", "zya", function() end, { buf = bufnr, desc = "probe: falls back" })
  vim.keymap.set("n", "zyb", function() end, { buf = bufnr, desc = "probe: own zyb" })

  local sheet = Keysheet.for_buffer({
    bufnr = bufnr,
    in_effect = function(mapping)
      return mapping.lhs ~= "zya"
    end,
  })
  local keys = {} ---@type string[]
  for _, keymap in ipairs(sheet._sections[1].keymaps) do
    keys[#keys + 1] = keymap.key
  end
  for _, group in ipairs(sheet._more[1].groups) do
    for _, keymap in ipairs(group.keymaps) do
      if vim.startswith(keymap.key, "zy") then
        keys[#keys + 1] = group.title .. " " .. keymap.key
      end
    end
  end
  t.assert_same({ "zyb" }, keys)
end)

t:test("a keysheet shows each section under its title, skips an empty one and truncates long descriptions", function()
  local long = string.rep("long ", 20) ---@type string
  local sheet = Keysheet.new({
    sections = {
      { title = "Current pane", keymaps = { { modes = { "n" }, key = "a", desc = "first", callback = "" } } },
      { title = "Empty", keymaps = {} },
      { title = "Global", keymaps = { { modes = { "n" }, key = "b", desc = long, callback = "" } }, compact = true },
    },
  })
  local lines = sheet:__render__(120, 40)
  local text = table.concat(lines, "\n")
  t.assert_true(text:find("  Current pane\n  a  n  first", 1, true) ~= nil, text)
  t.assert_nil(text:find("Empty", 1, true), "an empty section has no title")
  local global = assert(text:match("  Global\n  b  n  ([^\n]*)"), text)
  t.assert_eq(48, vim.api.nvim_strwidth(vim.trim(global)), "the description fits in 48 cells")
  t.assert_true(vim.endswith(vim.trim(global), "…"), global)
end)

t:test("the global section collapses a numbered run of three or more; the buffer's own keys stay as mapped", function()
  local bufnr = t:buffer()
  local globals = {} ---@type string[]
  ---@param lhs                         string
  ---@param desc                        string
  ---@return nil
  local function global(lhs, desc)
    vim.keymap.set("n", lhs, function() end, { desc = desc })
    globals[#globals + 1] = lhs
  end
  t:defer(function()
    for _, lhs in ipairs(globals) do
      pcall(vim.keymap.del, "n", lhs)
    end
  end)
  for index = 1, 4 do
    global("zy" .. index, "probe: focus " .. index)
    vim.keymap.set("n", "zw" .. index, function() end, { buf = bufnr, desc = "probe: own " .. index })
  end
  global("zq1", "probe: tab 1")
  global("zq2", "probe: tab 2")

  local sheet = Keysheet.for_buffer({ bufnr = bufnr })
  local entries = {} ---@type string[]
  for _, group in ipairs(sheet._more[1].groups) do
    for _, keymap in ipairs(group.title == "probe" and group.keymaps or {}) do
      entries[#entries + 1] = keymap.key .. " " .. keymap.desc
    end
  end
  t.assert_same({ "zq1 tab 1", "zq2 tab 2", "zy1…4 focus 1…4" }, entries, "a run of two stays as it is")
  local own = {} ---@type string[]
  for _, keymap in ipairs(sheet._sections[1].keymaps) do
    own[#own + 1] = keymap.key
  end
  t.assert_same({ "zw1", "zw2", "zw3", "zw4" }, own)
end)

t:test("groups flow down the columns, a title never ending one and a blank never starting one", function()
  ---@param prefix                    string
  ---@return stl.t.IKeymap[]
  local function items(prefix)
    local keymaps = {} ---@type stl.t.IKeymap[]
    for index = 1, 3 do
      keymaps[index] = { modes = { "n" }, key = prefix .. index, desc = prefix .. " item", callback = "" }
    end
    return keymaps
  end
  local sheet = Keysheet.new({
    sections = {
      { title = "G", groups = { { title = "A", keymaps = items("a") }, { title = "B", keymaps = items("b") } } },
    },
  })
  t.assert_same({
    "",
    "  G",
    "  A                B",
    "  a1  n  a item    b1  n  b item",
    "  a2  n  a item    b2  n  b item",
    "  a3  n  a item    b3  n  b item",
    "",
  }, sheet:__render__(34, 40))
end)

t:test("a compact section taller than the sheet truncates its descriptions to take more columns", function()
  local keymaps = {} ---@type stl.t.IKeymap[]
  for index = 1, 10 do
    keymaps[index] = { modes = { "n" }, key = "k" .. (index - 1), desc = string.rep("d", 40), callback = "" }
  end
  local section = { title = "S", keymaps = keymaps, compact = true } ---@type era.view.keysheet.ISection
  t.assert_eq(13, #Keysheet.new({ sections = { section } }):__render__(80, 40), "one column of whole descriptions")
  local lines = Keysheet.new({ sections = { section } }):__render__(80, 7)
  t.assert_eq(8, #lines, "two columns")
  t.assert_true(lines[3]:find("…", 1, true) ~= nil, lines[3])

  section.compact = nil
  lines = Keysheet.new({ sections = { section } }):__render__(80, 7)
  t.assert_eq(13, #lines, "a section that is not compact keeps its descriptions whole")
  t.assert_nil(table.concat(lines):find("…", 1, true))
end)

t:test("a group title keeps its first item under it when the groups would fit in one row", function()
  ---@param prefix                    string
  ---@return stl.t.IKeymap[]
  local function items(prefix)
    return {
      { modes = { "n" }, key = prefix .. "1", desc = prefix, callback = "" },
      { modes = { "n" }, key = prefix .. "2", desc = prefix, callback = "" },
    }
  end
  local sheet = Keysheet.new({
    sections = {
      { title = "G", groups = { { title = "A", keymaps = items("a") }, { title = "B", keymaps = items("b") } } },
    },
  })
  t.assert_same({
    "",
    "  G",
    "  A           a2  n  a    B           b2  n  b",
    "  a1  n  a                b1  n  b",
    "",
  }, sheet:__render__(120, 40))
end)

t:test("a group that cannot follow a blank in a column starts the next one", function()
  ---@param prefix                    string
  ---@return era.view.keysheet.ISection
  local function group(prefix)
    return {
      title = prefix:upper(),
      keymaps = { { modes = { "n" }, key = prefix .. "1", desc = prefix .. " item", callback = "" } },
    }
  end
  local sheet = Keysheet.new({ sections = { { title = "G", groups = { group("a"), group("b"), group("c") } } } })
  t.assert_same({
    "",
    "  G",
    "  A                C",
    "  a1  n  a item    c1  n  c item",
    "",
    "  B",
    "  b1  n  b item",
    "",
  }, sheet:__render__(40, 40))
end)

t:test("a buffer keysheet shows the current pane, and g? in it adds the global keys and takes them away", function()
  local bufnr = t:buffer({}, { current = true })
  vim.keymap.set("n", "zxa", function() end, { buf = bufnr, desc = "probe: own" })
  local sheet = Keysheet.for_buffer({ bufnr = bufnr })
  t:defer(function()
    sheet:dispose()
  end)
  sheet:open()
  local winnr = assert(sheet._winnr)
  ---@return string
  local function text()
    return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winnr), 0, -1, false), "\n")
  end
  ---@return string
  local function footer()
    return vim.api.nvim_win_get_config(winnr).footer[1][1]
  end
  local toggle = assert(vim.fn.maparg("g?", "n", false, true).callback, "g? in the sheet")

  t.assert_true(text():find("Current pane", 1, true) ~= nil)
  t.assert_nil(text():find("Global", 1, true), "the current pane alone")
  t.assert_eq(" g? all keys ", footer())
  toggle()
  t.assert_true(text():find("\n  Global\n", 1, true) ~= nil, "the global keys after the pane's")
  t.assert_eq(" g? current pane ", footer())
  toggle()
  t.assert_nil(text():find("Global", 1, true), "back to the current pane")
end)

t:run()
