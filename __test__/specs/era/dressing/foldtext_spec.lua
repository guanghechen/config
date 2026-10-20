-- cspell:ignore foldtextresult multibyte

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local module_name = "era.dressing.foldtext" ---@type string

bootstrap.with_runtime(t, {
  stl = {
    icon = {
      symbols = {
        sep_left = "<",
        sep_right = ">",
      },
    },
  },
})

t:patch_table(package.loaded, module_name, nil)

local Foldtext = require(module_name)

t:test("dressing initializes every existing window only once", function()
  local calls = {} ---@type table[]
  local list_wins_calls = 0 ---@type integer
  t:patch_table(vim.api, "nvim_list_wins", function()
    list_wins_calls = list_wins_calls + 1
    return { 11, 22 }
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function(option, value, opts)
    calls[#calls + 1] = { option = option, value = value, opts = opts }
  end)

  Foldtext.dressing()
  Foldtext.dressing()

  local callback = "v:lua.era.dressing.foldtext.foldtext()" ---@type string
  t.assert_eq(1, list_wins_calls, "window enumeration")
  t.assert_eq(3, #calls, "foldtext writes")
  t.assert_eq("foldtext", calls[1].option, "global option")
  t.assert_eq(callback, calls[1].value, "global callback")
  t.assert_eq("global", calls[1].opts.scope, "global scope")
  t.assert_eq(11, calls[2].opts.win, "first window")
  t.assert_eq(22, calls[3].opts.win, "second window")
end)

---@param lines                         string[]
---@param prepare                       fun(bufnr: integer): nil
---@return [string, string][] chunks
local function fold_chunks(lines, prepare)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local previous_foldmethod = vim.api.nvim_get_option_value("foldmethod", { win = winnr }) ---@type string
  local previous_foldtext = vim.api.nvim_get_option_value("foldtext", { win = winnr }) ---@type string
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_set_option_value("foldtext", previous_foldtext, { win = winnr })
    vim.api.nvim_set_option_value("foldmethod", previous_foldmethod, { win = winnr })
    if vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_win_set_buf(winnr, previous_bufnr)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local chunks = nil ---@type [string, string][]|nil

  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr })
  vim.cmd("1," .. #lines .. "fold")
  prepare(bufnr)
  t:patch_global("__test_foldtext", function()
    chunks = Foldtext.foldtext()
    return chunks
  end)
  vim.api.nvim_set_option_value("foldtext", "v:lua.__test_foldtext()", { win = winnr })
  vim.fn.foldtextresult(1)
  return assert(chunks, "foldtext chunks")
end

t:test("foldtext preserves byte columns and separates uncaptured text", function()
  local queries = 0 ---@type integer
  -- One tree whose query captures the first byte twice and the multibyte text once.
  local captures = {
    { id = 1, range = { 0, 0, 0, 1 }, metadata = { priority = 150 } },
    { id = 2, range = { 0, 0, 0, 1 }, metadata = { priority = 50 } },
    { id = 3, range = { 0, 2, 0, 5 }, metadata = { [3] = { priority = 120 } } },
  }
  local query = {
    captures = { "High", "Low", "Last" },
    iter_captures = function(_, _, _, start_row, end_row)
      queries = queries + 1
      t.assert_eq(0, start_row, "capture row")
      t.assert_eq(1, end_row, "single row")
      local index = 0 ---@type integer
      return function()
        index = index + 1
        local capture = captures[index]
        if capture ~= nil then
          local range = capture.range
          return capture.id,
            {
              range = function()
                return range[1], range[2], range[3], range[4]
              end,
            },
            capture.metadata
        end
      end
    end,
  }
  local tstree = {
    root = function()
      return {
        range = function()
          return 0, 0, 2, 5
        end,
      }
    end,
  }

  local chunks = fold_chunks({ "a\téc", "two", "three" }, function(bufnr)
    vim.api.nvim_set_option_value("tabstop", 4, { buf = bufnr })
    t:patch_table(vim.treesitter.highlighter.active, bufnr, {
      tree = {
        for_each_tree = function(_, callback)
          callback(tstree, {
            lang = function()
              return "lua"
            end,
          })
        end,
      },
    })
    t:patch_table(vim.treesitter.query, "get", function(lang, name)
      t.assert_eq("lua", lang, "query language")
      t.assert_eq("highlights", name, "query name")
      return query
    end)
  end)

  t.assert_eq(7, #chunks, "chunk count")
  t.assert_eq("a", chunks[1][1], "first text")
  t.assert_eq("@High.lua", chunks[1][2], "first highlight")
  t.assert_eq("   ", chunks[2][1], "expanded tab")
  t.assert_nil(chunks[2][2], "uncaptured highlight")
  t.assert_eq("éc", chunks[3][1], "last text")
  t.assert_eq("@Last.lua", chunks[3][2], "last highlight")
  t.assert_eq(1, queries, "one query pass for the row")
end)

t:test("foldtext highlights match the captures at every position", function()
  local line = 'local function greet(name) return ("hi %s"):format(name) .. 42 -- done' ---@type string
  local chunks = fold_chunks({ line, "  return nil", "end" }, function(bufnr)
    vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
    vim.treesitter.start(bufnr, "lua")
    vim.treesitter.get_parser(bufnr):parse(true)
  end)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  -- The highest priority capture at each position, the later one on a tie.
  local expected = {} ---@type string[]
  for col = 0, #line - 1 do
    local selected, selected_priority = nil, -math.huge ---@type table|nil, number
    for _, capture in ipairs(vim.treesitter.get_captures_at_pos(bufnr, 0, col)) do
      local metadata = capture.metadata or {} ---@type table
      local priority = tonumber(metadata.priority or (metadata[capture.id] or {}).priority)
        or vim.hl.priorities.treesitter
      if priority >= selected_priority then
        selected, selected_priority = capture, priority
      end
    end
    expected[#expected + 1] = selected and ("@" .. selected.capture .. "." .. selected.lang) or "-"
  end
  local actual = {} ---@type string[]
  for index = 1, #chunks - 4 do
    for _ = 1, #chunks[index][1] do
      actual[#actual + 1] = chunks[index][2] or "-"
    end
  end

  t.assert_true(vim.list_contains(expected, "@keyword.function.lua"), "captured line")
  t.assert_eq(table.concat(expected, " "), table.concat(actual, " "), "highlight per byte")
end)
t:run()
